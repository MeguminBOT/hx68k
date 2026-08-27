#!/usr/bin/env bash
# builds the C under rom/src into rom/out/<profile>/rom.bin, from the sample's own directory.
#   ./rom.sh                 release
#   ./rom.sh debug           DWARF-bearing, in rom/out/debug
#   DWARF=5 ./rom.sh debug   the same at -gdwarf-5
# MD_TOOLS names the m68k toolchain's bin directory and MD_LIBGCC its libgcc; both default to the
# ones SGDK ships, which is the only part of it a build still reaches for. MD_BOOT names a boot
# file other than sdk/boot/sega.s, and EXTRA_FLAGS and EXTRA_LIBS reach the compiler and the link.
set -e

SDK="$(cd "$(dirname "$0")" && pwd)"
TOOLS="${MD_TOOLS:-$SDK/../vendor/SGDK/bin}"

CC="$TOOLS/gcc"
NM="$TOOLS/nm"
OBJCOPY="$TOOLS/objcopy"
LIBGCC="${MD_LIBGCC:-$TOOLS/../lib/libgcc.a}"
BOOT="${MD_BOOT:-$SDK/boot/sega.s}"

PROFILE=release
if [ "$1" = "debug" ]; then PROFILE=debug; shift; fi

# the boot's vector table incbins out/rom_header.bin by that name, so the compiler runs from rom/
cd rom
OUT="out/$PROFILE"
rm -rf "$OUT"
mkdir -p "$OUT"

COMMON="-m68000 -fdiagnostics-color=always -Wall -Wextra -Wno-shift-negative-value -Wno-main"
COMMON="$COMMON -Wno-unused-parameter -fno-builtin -ffunction-sections -fdata-sections"
COMMON="$COMMON -fms-extensions -B$TOOLS -Isrc -Iinc $EXTRA_FLAGS"

if [ "$PROFILE" = "debug" ]; then
	CFLAGS="$COMMON -O1 -DDEBUG=1 -ggdb -gdwarf-${DWARF:-4} -fno-inline"
	LTO=""
else
	CFLAGS="$COMMON -O3 -fuse-linker-plugin -fno-web -fno-gcse -fno-tree-loop-ivcanon"
	CFLAGS="$CFLAGS -fomit-frame-pointer -flto -flto=auto -ffat-lto-objects"
	LTO="-flto -flto=auto -ffat-lto-objects"
fi

AFLAGS="-x assembler-with-cpp -Wa,--register-prefix-optional,--bitwise-or $CFLAGS"

"$CC" $CFLAGS -c src/rom_header.c -o "$OUT/rom_header.o"
"$OBJCOPY" -O binary "$OUT/rom_header.o" out/rom_header.bin

cp "$BOOT" "$OUT/sega.s"
"$CC" $AFLAGS -c "$OUT/sega.s" -o "$OUT/sega.o"

OBJECTS=""
for SOURCE in $(find src -name "*.c" | sort); do
	case "$SOURCE" in src/rom_header.c) continue ;; esac
	OBJECT="$OUT/${SOURCE#src/}"
	OBJECT="${OBJECT%.c}.o"
	mkdir -p "$(dirname "$OBJECT")"
	"$CC" $CFLAGS -c "$SOURCE" -o "$OBJECT"
	OBJECTS="$OBJECTS $OBJECT"
done

"$CC" -m68000 -B"$TOOLS" -n -T "$SDK/md.ld" -nostdlib "$OUT/sega.o" $OBJECTS $EXTRA_LIBS \
	"$LIBGCC" -o "$OUT/rom.out" -Wl,--gc-sections $LTO

"$NM" -n -l "$OUT/rom.out" > "$OUT/symbol.txt"
"$OBJCOPY" -O binary "$OUT/rom.out" "$OUT/rom.bin"
haxelib run hx68k pad "$OUT/rom.bin" -sizealign 131072 -checksum
cp "$OUT/rom.bin" out/rom.bin
ls -la out/rom.bin

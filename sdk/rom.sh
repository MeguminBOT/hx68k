#!/usr/bin/env bash
# builds a ROM: haxe -> C -> export/md/rom/<name>/bin/<profile>/rom.bin, run from the directory
# holding build.hxml.
#   ./rom.sh                 release
#   ./rom.sh debug           DWARF-bearing, under bin/debug
#   DWARF=5 ./rom.sh debug   the same at -gdwarf-5
# Where everything goes is read out of build.hxml's own '-D md-output=<dir>/src' line, so that line
# is the only place the export path is written down.
# A build that needs more than the defaults puts it in rom.env beside build.hxml, which is sourced
# before anything else: MD_TOOLS names the m68k toolchain's bin directory and MD_LIBGCC its libgcc,
# both defaulting to the ones SGDK ships, which is the only part of it a build still reaches for;
# MD_BOOT names a boot file other than sdk/boot/sega.s and MD_HEADER_AT where that file incbins
# the ROM header from; MD_CSRC lists directories of hand-written C
# to compile beside the generated C, defaulting to 'c' and '../common/c' where they exist; and
# EXTRA_FLAGS and EXTRA_LIBS reach the compiler and the link.
set -e

SDK="$(cd "$(dirname "$0")" && pwd)"
if [ -f rom.env ]; then . ./rom.env; fi

TOOLS="${MD_TOOLS:-$SDK/../vendor/SGDK/bin}"

CC="$TOOLS/gcc"
NM="$TOOLS/nm"
OBJCOPY="$TOOLS/objcopy"
LIBGCC="${MD_LIBGCC:-$TOOLS/../lib/libgcc.a}"
BOOT="${MD_BOOT:-$SDK/boot/sega.s}"
HEADER="${MD_HEADER_AT:-obj/rom_header.bin}"

PROFILE=release
if [ "$1" = "debug" ]; then PROFILE=debug; shift; fi

GENERATED="$(sed -n 's/^[[:space:]]*-D md-output=//p' build.hxml | head -1)"
if [ -z "$GENERATED" ]; then
	echo "build.hxml does not say -D md-output=<dir>, so there is nowhere to put the C" >&2
	exit 1
fi

CFILES=""
for EXTRA in ${MD_CSRC-c ../common/c}; do
	if [ -d "$EXTRA" ]; then CFILES="$CFILES $(cd "$EXTRA" && pwd)"; fi
done

echo "[1/2] haxe -> c"
haxe build.hxml

echo "[2/2] c -> rom"
EXPORT="$(cd "$(dirname "$GENERATED")" && pwd)"
SRC="$(basename "$GENERATED")"
cd "$EXPORT"

BIN="bin/$PROFILE"
OBJ="obj/$PROFILE"
rm -rf "$BIN" "$OBJ"
mkdir -p "$BIN" "$OBJ"

COMMON="-m68000 -fdiagnostics-color=always -Wall -Wextra -Wno-shift-negative-value -Wno-main"
COMMON="$COMMON -Wno-unused-parameter -fno-builtin -ffunction-sections -fdata-sections"
COMMON="$COMMON -fms-extensions -B$TOOLS -I$SRC"
for EXTRA in $CFILES; do COMMON="$COMMON -I$EXTRA"; done
COMMON="$COMMON $EXTRA_FLAGS"

if [ "$PROFILE" = "debug" ]; then
	CFLAGS="$COMMON -O1 -DDEBUG=1 -ggdb -gdwarf-${DWARF:-4} -fno-inline"
	LTO=""
else
	CFLAGS="$COMMON -O3 -fuse-linker-plugin -fno-web -fno-gcse -fno-tree-loop-ivcanon"
	CFLAGS="$CFLAGS -fomit-frame-pointer -flto -flto=auto -ffat-lto-objects"
	LTO="-flto -flto=auto -ffat-lto-objects"
fi

AFLAGS="-x assembler-with-cpp -Wa,--register-prefix-optional,--bitwise-or $CFLAGS"

# the boot's vector table incbins the header by a path of its own, which is why the compiler runs
# from the export directory rather than from the sources
"$CC" $CFLAGS -c "$SRC/rom_header.c" -o "$OBJ/rom_header.o"
mkdir -p "$(dirname "$HEADER")"
"$OBJCOPY" -O binary "$OBJ/rom_header.o" "$HEADER"

cp "$BOOT" "$OBJ/sega.s"
"$CC" $AFLAGS -c "$OBJ/sega.s" -o "$OBJ/sega.o"

OBJECTS=""
for SOURCE in $(find "$SRC" -name "*.c" | sort); do
	case "$SOURCE" in "$SRC/rom_header.c") continue ;; esac
	OBJECT="$OBJ/${SOURCE#$SRC/}"
	OBJECT="${OBJECT%.c}.o"
	mkdir -p "$(dirname "$OBJECT")"
	"$CC" $CFLAGS -c "$SOURCE" -o "$OBJECT"
	OBJECTS="$OBJECTS $OBJECT"
done

for EXTRA in $CFILES; do
	for SOURCE in $(find "$EXTRA" -name "*.c" | sort); do
		OBJECT="$OBJ/$(basename "${SOURCE%.c}").o"
		"$CC" $CFLAGS -c "$SOURCE" -o "$OBJECT"
		OBJECTS="$OBJECTS $OBJECT"
	done
done

"$CC" -m68000 -B"$TOOLS" -n -T "$SDK/md.ld" -nostdlib "$OBJ/sega.o" $OBJECTS $EXTRA_LIBS \
	"$LIBGCC" -o "$BIN/rom.out" -Wl,--gc-sections $LTO

"$NM" -n -l "$BIN/rom.out" > "$BIN/symbol.txt"
"$OBJCOPY" -O binary "$BIN/rom.out" "$BIN/rom.bin"
haxelib run hx68k pad "$BIN/rom.bin" -sizealign 131072 -checksum
cp "$BIN/rom.bin" bin/rom.bin
ls -la "$EXPORT/bin/rom.bin"

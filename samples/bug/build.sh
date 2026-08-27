#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
GDK_POSIX="$(cd "$HERE/../../vendor/SGDK" && pwd)"
ROOT_POSIX="$(cd "$HERE/../.." && pwd)"
export GDK="$(cygpath -m "$GDK_POSIX" 2>/dev/null || echo "$GDK_POSIX")"
export PATH="$GDK_POSIX/bin:$PATH"
BOOT="$(cygpath -m "$ROOT_POSIX/sdk" 2>/dev/null || echo "$ROOT_POSIX/sdk")"
# the ROM is padded and checksummed by hx68k itself, so the link needs no JVM
SIZEBND="haxelib run hx68k pad"
cd "$HERE"
echo "[1/2] haxe -> c"
haxe build.hxml
cd rom
echo "[2/2] c -> rom"
# makefile.gen hangs sega.o off out/rom_header.bin and not off sega.s, so our boot file
# would never be reassembled after an edit. Drop the object and let make rebuild it.
rm -f out/release/sega.o out/debug/sega.o
# the debug profile pins the DWARF version the map tool reads and keeps every line addressable.
# DWARF=5 in the environment builds the same ROM with version 5 units instead, which is the other
# half of what the reader has to understand.
if [ "$1" = "debug" ]; then
	shift
	rm -rf out/debug
	make.exe -f "$GDK/makefile.gen" debug SIZEBND="$SIZEBND" RESCOMP=false CONVSYM=true SRC_LIB="$BOOT" EXTRA_FLAGS="-gdwarf-${DWARF:-4} -fno-inline" "$@"
else
	make.exe -f "$GDK/makefile.gen" SIZEBND="$SIZEBND" RESCOMP=false SRC_LIB="$BOOT" "$@"
fi
ls -la out/rom.bin

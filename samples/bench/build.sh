#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
GDK_POSIX="$(cd "$HERE/../../vendor/SGDK" && pwd)"
export GDK="$(cygpath -m "$GDK_POSIX" 2>/dev/null || echo "$GDK_POSIX")"
export PATH="$GDK_POSIX/bin:$PATH"
# the ROM is padded and checksummed by hx68k itself, so the link needs no JVM
SIZEBND="haxelib run hx68k pad"
cd "$HERE"
echo "[1/2] haxe -> c"
haxe build.hxml
cd rom
echo "[2/2] c -> rom"
# the debug profile pins the DWARF version the map tool reads and keeps every line addressable
if [ "$1" = "debug" ]; then
	shift
	make.exe -f "$GDK/makefile.gen" debug SIZEBND="$SIZEBND" RESCOMP=false CONVSYM=true EXTRA_FLAGS="-gdwarf-4 -fno-inline" "$@"
else
	make.exe -f "$GDK/makefile.gen" SIZEBND="$SIZEBND" RESCOMP=false "$@"
fi
ls -la out/rom.bin

#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
GDK_POSIX="$(cd "$HERE/../../vendor/SGDK" && pwd)"
export GDK="$(cygpath -m "$GDK_POSIX" 2>/dev/null || echo "$GDK_POSIX")"
export PATH="$GDK_POSIX/bin:$PATH"
cd "$HERE"
echo "[1/2] haxe -> c"
haxe build.hxml
cd rom
echo "[2/2] c -> rom"
# the debug profile pins the DWARF version the map tool reads and keeps every line addressable
if [ "$1" = "debug" ]; then
	shift
	make.exe -f "$GDK/makefile.gen" debug EXTRA_FLAGS="-gdwarf-4 -fno-inline" "$@"
else
	make.exe -f "$GDK/makefile.gen" "$@"
fi
ls -la out/rom.bin

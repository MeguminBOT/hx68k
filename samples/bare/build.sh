#!/usr/bin/env bash
# a ROM whose link carries no SGDK symbol: SRC_LIB points make at sdk/boot/sega.s instead of SGDK's
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
GDK_POSIX="$(cd "$HERE/../../vendor/SGDK" && pwd)"
ROOT_POSIX="$(cd "$HERE/../.." && pwd)"
export GDK="$(cygpath -m "$GDK_POSIX" 2>/dev/null || echo "$GDK_POSIX")"
export PATH="$GDK_POSIX/bin:$PATH"
BOOT="$(cygpath -m "$ROOT_POSIX/sdk" 2>/dev/null || echo "$ROOT_POSIX/sdk")"
SIZEBND="haxelib run hx68k pad"
cd "$HERE"
echo "[1/2] haxe -> c"
haxe build.hxml
cd rom
echo "[2/2] c -> rom"
make.exe -f "$GDK/makefile.gen" SIZEBND="$SIZEBND" SRC_LIB="$BOOT" "$@"
ls -la out/rom.bin

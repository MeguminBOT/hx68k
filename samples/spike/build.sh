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
make.exe -f "$GDK/makefile.gen" "$@"
ls -la out/rom.bin

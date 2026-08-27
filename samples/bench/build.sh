#!/usr/bin/env bash
# haxe -> C -> rom/out/release/rom.bin. The one sample that links SGDK as well as md.*, so it
# takes SGDK's headers, its library and its boot, which is what -D md-sgdk in build.hxml says.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
GDK_POSIX="$(cd "$ROOT/vendor/SGDK" && pwd)"
GDK="$(cygpath -m "$GDK_POSIX" 2>/dev/null || echo "$GDK_POSIX")"
export EXTRA_FLAGS="-DSGDK_GCC -isystem $GDK/inc -isystem $GDK/out/release"
export EXTRA_LIBS="$GDK_POSIX/lib/libmd.a"
export MD_BOOT="$GDK_POSIX/src/boot/sega.s"
cd "$HERE"
echo "[1/2] haxe -> c"
haxe build.hxml
echo "[2/2] c -> rom"
"$ROOT/sdk/rom.sh" "$@"

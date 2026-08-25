#!/usr/bin/env bash
#
# Builds the emulator's window and says where it put it.
#
#   ./emulator/build.sh          the build run-window.sh runs
#   ./emulator/build.sh debug    the same carrying debug information, for a stack trace on a crash
#
# This is a plain hxcpp build like every other check in this directory. What it needs beyond a
# Haxe install is SDL3 and miniaudio in vendor/, which vendor/fetch.sh puts there.
#
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

SDL3="$(cd "$HERE/../vendor" && pwd)/SDL3"
MINIAUDIO="$(cd "$HERE/../vendor" && pwd)/miniaudio"

if [ ! -f "$SDL3/lib/SDL3.lib" ] || [ ! -f "$MINIAUDIO/miniaudio.h" ]; then
	echo "SDL3 or miniaudio is missing from vendor/. Run ./vendor/fetch.sh first." >&2
	exit 1
fi

# hxcpp's build tool is a Windows binary and cannot read a POSIX path, which is the same reason the
# sample builds hand it GDK through cygpath
winpath() { (cd "$1" && pwd -W 2>/dev/null || pwd); }

BUILT="bin/window/Console.exe"
SHIPPED="bin/window/hx68k.exe"

FLAGS=""
if [ "${1:-}" = "debug" ]; then
	FLAGS="-debug"
fi

# Windows holds a running executable open, so a link over one fails. The build then looks like it
# worked and hands back the binary from last time, which is a very good way to spend an afternoon
# fixing something that was already fixed.
taskkill //F //IM hx68k.exe > /dev/null 2>&1 || true
rm -f "$BUILT" "$SHIPPED"

haxe window.hxml $FLAGS \
	-D SDL3PATH="$(winpath "$SDL3")" \
	-D MINIAUDIOPATH="$(winpath "$MINIAUDIO")" \
	-D NATIVEPATH="$(winpath "$HERE/native")"

if [ ! -f "$BUILT" ]; then
	echo "the link produced nothing: something still had the binary open"
	exit 1
fi

# hxcpp names a binary after its main class, and the window is called hx68k everywhere else
cp "$BUILT" "$SHIPPED"
cp "$SDL3/lib/SDL3.dll" bin/window/

echo ""
echo "  $HERE/$SHIPPED"
echo "  $(du -h "$SHIPPED" | cut -f1), built $(date '+%H:%M:%S')"
echo ""
echo "  ./emulator/run-window.sh <rom.bin>   builds it again and runs it"

#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

# the ROM is resolved against where this was called from, before moving to where it is built
ROM=""
if [ -n "${1:-}" ]; then
	ROM="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
fi

cd "$HERE"

BUILT="bin/window/windows/bin/hx68k.exe"

# Windows holds a running executable open, so a link over one fails and lime does not call that an
# error. The build then looks like it worked and hands back the binary from last time, which is a
# very good way to spend an afternoon fixing something that was already fixed.
taskkill //F //IM hx68k.exe > /dev/null 2>&1 || true
rm -f "$BUILT"

haxelib run lime build windows -release

if [ ! -f "$BUILT" ]; then
	echo "the link produced nothing: something still had $BUILT open"
	exit 1
fi

if [ -z "$ROM" ]; then
	exec "./$BUILT"
fi

exec "./$BUILT" "$ROM"

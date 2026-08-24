#!/usr/bin/env bash
#
# Builds the emulator's window and runs it, on a ROM where one is named.
#
#   ./emulator/run-window.sh                 opens with nothing loaded
#   ./emulator/run-window.sh <rom.bin>       and with that ROM in it
#
# arrows, z x c, return, space, escape
#
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

# the ROM is resolved against where this was called from, before moving to where it is built
ROM=""
if [ -n "${1:-}" ]; then
	ROM="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
fi

"$HERE/build.sh" > /dev/null

cd "$HERE"
BUILT="bin/window/windows/bin/hx68k.exe"

if [ -z "$ROM" ]; then
	exec "./$BUILT"
fi

exec "./$BUILT" "$ROM"

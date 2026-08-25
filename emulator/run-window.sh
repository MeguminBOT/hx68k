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

# the ROM is resolved against where this was called from, before moving to the repository root
ROM=""
if [ -n "${1:-}" ]; then
	ROM="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
fi

cd "$(cd "$(dirname "$0")" && pwd)/.."

if [ -z "$ROM" ]; then
	exec haxelib run hx68k run
fi

exec haxelib run hx68k run "$ROM"

#!/usr/bin/env bash
#
# Builds the emulator's window.
#
#   ./emulator/build.sh          the build run-window.sh runs
#   ./emulator/build.sh debug    the same, carrying debug information
#
# A wrapper, so the SDL3 and miniaudio paths live in one place rather than two. What it calls needs
# no bash and works the same on any platform:
#
#   haxelib run hx68k build              the window
#   haxelib run hx68k build sst z80      those targets
#   haxelib run hx68k build --all        every target
#   haxelib run hx68k list               every target and where it is put
#
set -e
cd "$(cd "$(dirname "$0")" && pwd)/.."

if [ "${1:-}" = "debug" ]; then
	exec haxelib run hx68k build --debug
fi

exec haxelib run hx68k build

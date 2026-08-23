#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

ROM="${1:-}"
if [ -z "$ROM" ]; then
	echo "usage: ./run-window.sh <rom.bin>"
	exit 2
fi

haxelib run lime build windows -release
exec ./bin/window/windows/bin/hx68k.exe "$(cd "$(dirname "$ROM")" && pwd)/$(basename "$ROM")"

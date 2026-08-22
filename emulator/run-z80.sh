#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
if [ ! -d "../vendor/SingleStepTests-z80/v1bin" ]; then
	echo "z80 fixtures not converted; skipping z80 conformance."
	echo "run: cd emulator && haxe z80convert.hxml && neko bin/z80convert.n"
	exit 0
fi
haxe z80.hxml
neko bin/z80.n "$@"

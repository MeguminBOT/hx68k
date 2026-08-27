#!/usr/bin/env bash
# haxe -> C -> rom/out/release/rom.bin. Pass debug for the DWARF-bearing profile.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$HERE"
echo "[1/2] haxe -> c"
haxe build.hxml
echo "[2/2] c -> rom"
"$ROOT/sdk/rom.sh" "$@"

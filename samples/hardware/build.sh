#!/usr/bin/env bash
# haxe -> C -> rom/out/release/rom.bin. Pass debug for the DWARF-bearing profile.
set -e
cd "$(dirname "$0")"
exec ../../sdk/rom.sh "$@"

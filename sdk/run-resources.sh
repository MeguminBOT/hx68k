#!/usr/bin/env bash
# the resource pipeline against rescomp:
#   ./sdk/run-resources.sh [repository-root]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${1:-$HERE/..}" && pwd)"
cd "$HERE"
haxe check.hxml
exec ../export/md/tests/obj/check/Check "$ROOT"

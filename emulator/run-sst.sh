#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
if [ ! -d "../vendor/SingleStepTests-m68000/v1" ]; then
	echo "SingleStepTests suite missing; skipping 68000 conformance."
	exit 0
fi
./gate.sh sst "$@"

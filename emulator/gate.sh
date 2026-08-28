#!/usr/bin/env bash
#
# Every program the gate runs, in one binary rather than twenty neko builds.
#
#   ./emulator/gate.sh <program> [arguments]
#   ./emulator/gate.sh sst MOVE.w -f
#
# Building is incremental, so the first call pays for it and the rest do not.
#
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "${GATE_BUILT:-}" != "1" ]; then
	(cd "$HERE" && haxe gate.hxml) > /dev/null
fi

BIN="$HERE/../export/md/tests/obj/gate/Gate.exe"
[ -x "$BIN" ] || BIN="$HERE/../export/md/tests/obj/gate/Gate"
"$BIN" "$@"

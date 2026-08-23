#!/usr/bin/env bash
#
# The FM chip against Nuked OPN2. Generates the fixtures, renders both chips over every one of them,
# and reports how many came out bit identical, by group.
#
#   ./emulator/run-opn.sh                     the whole suite, counted by group
#   ./emulator/run-opn.sh main-algorithm-0    one fixture, printing where the two part company
#
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BUILD="$ROOT/tests/opn2/.build"
SCRIPTS="$BUILD/scripts"
SOUNDS="$BUILD/sounds"
SAMPLES="${SAMPLES:-4000}"

if [ ! -f "$ROOT/vendor/Nuked-OPN2/ym3438.c" ]; then
	echo "Nuked-OPN2 is not vendored; skipping the FM comparison."
	exit 0
fi

"$ROOT/tests/opn2/build.sh" > /dev/null

# the check is built to C rather than to neko: the same numbers, and fifty times faster, which is
# what makes a suite of this size something the gate can run
(cd "$HERE" && haxe fixtures.hxml && haxe opn.hxml) > /dev/null

neko "$HERE/bin/fixtures.n" "$SCRIPTS" > /dev/null
mkdir -p "$SOUNDS"

# only what changed is rendered again, since the reference for a fixture depends on nothing else.
# the oracle is a Windows binary and cannot read a POSIX path, so the job list carries the other kind
JOBS="$BUILD/jobs.txt"
: > "$JOBS"
for script in "$SCRIPTS"/*.txt; do
	name="$(basename "$script" .txt)"
	if [ ! -f "$SOUNDS/$name.pcm" ] || [ "$script" -nt "$SOUNDS/$name.pcm" ]; then
		echo "$(cygpath -m "$script") $(cygpath -m "$SOUNDS/$name.pcm")" >> "$JOBS"
	fi
done

if [ -s "$JOBS" ]; then
	"$BUILD/opn2.exe" "$SAMPLES" "$(cygpath -m "$JOBS")"
fi

if [ -n "$1" ]; then
	"$HERE/bin/opn/OpnCheck.exe" "$SCRIPTS/$1.txt" "$SOUNDS/$1.pcm"
else
	"$HERE/bin/opn/OpnCheck.exe" "$SCRIPTS" "$SOUNDS"
fi

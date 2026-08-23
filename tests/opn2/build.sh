#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.build"

if [ ! -f "$ROOT/vendor/Nuked-OPN2/ym3438.c" ]; then
	echo "Nuked-OPN2 is not vendored; the FM reference cannot be built."
	exit 1
fi

# copied rather than built in place, which is how every vendored source is treated here
mkdir -p "$OUT"
cp "$ROOT/vendor/Nuked-OPN2/ym3438.c" "$ROOT/vendor/Nuked-OPN2/ym3438.h" "$OUT/"
cp "$HERE/opn2.c" "$OUT/"

gcc -O2 -o "$OUT/opn2" "$OUT/opn2.c" "$OUT/ym3438.c" -I"$OUT"

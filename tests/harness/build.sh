#!/usr/bin/env bash
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
MUSASHI_SRC="$HERE/../../vendor/Musashi"
BUILD="$HERE/.build"
CC="${CC:-gcc}"

if [ ! -d "$MUSASHI_SRC" ]; then
	echo "vendor/Musashi is missing. Clone it first." >&2
	exit 1
fi

# Musashi is vendored read-only. Work on a copy so the reference stays pristine,
# and turn the instruction hook on so the harness can watch the PC.
if [ ! -f "$BUILD/musashi/m68kops.c" ] || [ "$MUSASHI_SRC/m68k_in.c" -nt "$BUILD/musashi/m68kops.c" ]; then
	echo "[musashi] generating opcode tables"
	rm -rf "$BUILD/musashi"
	mkdir -p "$BUILD/musashi"
	cp -r "$MUSASHI_SRC"/*.c "$MUSASHI_SRC"/*.h "$MUSASHI_SRC/softfloat" "$BUILD/musashi/"

	sed -i 's/^#define M68K_INSTRUCTION_HOOK .*$/#define M68K_INSTRUCTION_HOOK       M68K_OPT_ON/' \
		"$BUILD/musashi/m68kconf.h"
	grep -q "M68K_INSTRUCTION_HOOK       M68K_OPT_ON" "$BUILD/musashi/m68kconf.h" || {
		echo "failed to patch m68kconf.h" >&2
		exit 1
	}

	"$CC" -O2 -o "$BUILD/m68kmake" "$BUILD/musashi/m68kmake.c"
	(cd "$BUILD/musashi" && "$BUILD/m68kmake")
fi

echo "[harness] compiling"
mkdir -p "$BUILD"
"$CC" -O2 -std=c99 -Wall -Wextra -Wno-unused-parameter \
	-I"$HERE" -I"$BUILD/musashi" \
	-o "$BUILD/mdtest" \
	"$HERE/md.c" "$HERE/symbols.c" "$HERE/runner.c" \
	"$BUILD/musashi/m68kcpu.c" "$BUILD/musashi/m68kops.c" \
	"$BUILD/musashi/m68kdasm.c" "$BUILD/musashi/softfloat/softfloat.c" \
	-lm

echo "[harness] built $BUILD/mdtest"

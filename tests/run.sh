#!/usr/bin/env bash
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LOG="$HERE/.build.log"

mkdir -p "$HERE"

build() {
	local name="$1"
	local script="$2"
	printf "building %-14s" "$name"
	if "$script" > "$LOG" 2>&1; then
		echo "ok"
	else
		echo "FAILED"
		cat "$LOG"
		exit 1
	fi
}

codegen() {
	local name="$1"
	local file="$2"
	local pattern="$3"
	printf "codegen %-14s" "$name"
	if grep -qE "$pattern" "$file"; then
		echo "ok"
	else
		echo "FAILED"
		echo "  $file has no match for: $pattern"
		exit 1
	fi
}

absent() {
	local name="$1"
	local pattern="$2"
	printf "codegen %-14s" "$name"
	if grep -rqE "$pattern" "$ROOT"/samples/*/rom/src/*.c; then
		echo "FAILED"
		grep -rnE "$pattern" "$ROOT"/samples/*/rom/src/*.c | head -3
		exit 1
	fi
	echo "ok"
}

build "spike rom"   "$ROOT/samples/spike/build.sh"
build "conformance" "$ROOT/samples/conformance/build.sh"
build "harness"     "$HERE/harness/build.sh"

CONF="$ROOT/samples/conformance/rom/src/Main.c"

codegen "jump table"  "$CONF" 'switch\(\(\(.*\)\.tag\)\)'
codegen "tagged union" "$ROOT/samples/conformance/rom/src/hx.h" 'union \{'
codegen "pool storage" "$ROOT/samples/spike/rom/src/Entity.c" 'static Entity Entity__slots\[64\]'
codegen "rom table"   "$CONF" 'const s32 Main_digitsOfPi\[8\] = \{'

# a ROM address has no RAM mirror prefix, so the table really is in the cartridge
printf "codegen %-14s" "rom placement"
if awk '$3 == "Main_digitsOfPi" && strtonum("0x" $1) < 0x400000 { found = 1 } END { exit !found }' 	"$ROOT/samples/conformance/rom/out/release/symbol.txt"; then
	echo "ok"
else
	echo "FAILED"
	grep -w Main_digitsOfPi "$ROOT/samples/conformance/rom/out/release/symbol.txt" || true
	exit 1
fi
absent  "no heap"     '(malloc|calloc|realloc|free)\('

echo ""
"$HERE/harness/.build/mdtest" "$ROOT" "$@"

# 68000 core conformance is a tracked progress metric, not yet a gate:
# coverage is partial, so a low overall number is expected and honest.
echo ""
echo "--- 68000 cycle-accuracy conformance (SingleStepTests) ---"
"$ROOT/emulator/run-sst.sh" 2>&1 | tail -12

#!/usr/bin/env bash
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LOG="$HERE/.build.log"

mkdir -p "$HERE"

build() {
	local name="$1"
	local script="$2"
	shift 2
	printf "building %-16s" "$name"
	if "$script" "$@" > "$LOG" 2>&1; then
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
	printf "codegen %-16s" "$name"
	if grep -qE "$pattern" "$file"; then
		echo "ok"
	else
		echo "FAILED"
		echo "  $file has no match for: $pattern"
		exit 1
	fi
}

missing() {
	local name="$1"
	local file="$2"
	local pattern="$3"
	printf "codegen %-16s" "$name"
	if grep -qE "$pattern" "$file"; then
		echo "FAILED"
		echo "  $file should have no match for: $pattern"
		exit 1
	fi
	echo "ok"
}

absent() {
	local name="$1"
	local pattern="$2"
	printf "codegen %-16s" "$name"
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
HDR="$ROOT/samples/conformance/rom/src/hx.h"

codegen "jump table"  "$CONF" 'switch\(\(\(.*\)\.tag\)\)'
codegen "tagged union" "$HDR" 'union \{'
codegen "pool storage" "$ROOT/samples/spike/rom/src/Entity.c" 'static Entity Entity__slots\[64\]'
codegen "rom table"   "$CONF" 'const s32 Main_digitsOfPi\[8\] = \{'
codegen "vtable call" "$CONF" '[a-z]->__vt\)->area\('
codegen "final direct" "$CONF" 'Tile_area\('
codegen "bounds guard" "$CONF" 'hx_bounds\('
codegen "flat layout"  "$HDR" 'const void\* __vt;'
missing "no idle slot" "$HDR" '\(\*tag\)'
codegen "fat pointer"  "$HDR" 'const Sized__vt\* vt;'
codegen "interface call" "$CONF" '\.vt->span\('
codegen "interface table" "$ROOT/samples/conformance/rom/src/hx_interfaces.c" 'const Sized__vt Square__Sized'
missing "no debug cost" "$ROOT/samples/spike/rom/src/Main.c" 'hx_bounds\('
missing "no vtable cost" "$ROOT/samples/spike/rom/src/hx.h" '__vt'

# a ROM address has no RAM mirror prefix, so the table really is in the cartridge
printf "codegen %-16s" "rom placement"
if awk '$3 == "Main_digitsOfPi" && strtonum("0x" $1) < 0x400000 { found = 1 } END { exit !found }' 	"$ROOT/samples/conformance/rom/out/release/symbol.txt"; then
	echo "ok"
else
	echo "FAILED"
	grep -w Main_digitsOfPi "$ROOT/samples/conformance/rom/out/release/symbol.txt" || true
	exit 1
fi
absent  "no heap"     '\b(malloc|calloc|realloc|free)\('

echo ""
"$HERE/harness/.build/mdtest" "$ROOT" "$@"

echo ""
echo "--- source map (Haxe line to 68000 address) ---"

# the debug profile keeps DWARF and stops inlining, and writes over out/rom.bin as it goes,
# so it runs once the release ROM has been through the harness
build "debug rom" "$ROOT/samples/conformance/build.sh" debug

printf "building %-16s" "map tool"
if (cd "$ROOT/emulator" && haxe map.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi

MAP="$ROOT/emulator/bin/map.n"
DEBUG_ROM="$ROOT/samples/conformance/rom/out/debug/rom.out"
GENERATED="$ROOT/samples/conformance/rom/src"

printf "map %-20s" "named site"
SITE="$(neko "$MAP" "$DEBUG_ROM" "$GENERATED" Main_virtualDispatch)"
case "$SITE" in
	*"hx/Main.hx:"*"Main.virtualDispatch"*) echo "ok" ;;
	*) echo "FAILED"; echo "  $SITE"; exit 1 ;;
esac
echo "  $SITE"

printf "map %-20s" "static symbols"
STATICS="$(neko "$MAP" "$DEBUG_ROM" "$GENERATED" --statics | grep -w "Main.digitsOfPi")"
case "$STATICS" in
	*"s32[8]"*"hx/Main.hx:"*) echo "ok" ;;
	*) echo "FAILED"; echo "  $STATICS"; exit 1 ;;
esac
echo "  $STATICS"

neko "$MAP" "$DEBUG_ROM" "$GENERATED"

# 68000 core conformance is a tracked progress metric, not yet a gate:
# coverage is partial, so a low overall number is expected and honest.
echo ""
echo "--- 68000 cycle-accuracy conformance (SingleStepTests) ---"
"$ROOT/emulator/run-sst.sh" 2>&1 | tail -12

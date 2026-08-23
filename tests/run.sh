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
build "hardware rom" "$ROOT/samples/hardware/build.sh"
build "art rom"     "$ROOT/samples/art/build.sh"
build "events rom"  "$ROOT/samples/events/build.sh"
build "sdk rom"     "$ROOT/samples/sdk/build.sh"
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
codegen "rom fold"     "$CONF" 'tempLeft = 4;'
codegen "noinline"     "$CONF" '__attribute__\(\(noinline\)\)'
codegen "section"      "$CONF" '__attribute__\(\(section\(".data"\)\)\)'
codegen "handler table" "$ROOT/samples/events/rom/src/Main.c" 's32 \(\*Main_handlers\[4\]\)\(s32\);'
codegen "lifted lambda" "$ROOT/samples/events/rom/src/Main.c" 'Main_lambda0'
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
echo "--- the same ROMs on hx68k-emu, against what Musashi saw ---"
printf "building %-16s" "machine"
if (cd "$ROOT/emulator" && haxe rom.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi
neko "$ROOT/emulator/bin/rom.n" "$HERE/.observables.txt" "$ROOT"

echo ""
echo "--- the VDP renderer against the hardware documentation ---"
printf "building %-16s" "renderer"
if (cd "$ROOT/emulator" && haxe render.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi
neko "$ROOT/emulator/bin/render.n" "$ROOT"

echo ""
echo "--- the sound driver, on the only emulator here with a Z80 ---"
build "sound rom" "$ROOT/samples/sound/build.sh"
printf "building %-16s" "sound check"
if (cd "$ROOT/emulator" && haxe sound.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi
neko "$ROOT/emulator/bin/sound.n" "$ROOT"

echo ""
echo "--- generated code against the C written beside it, in 68000 cycles ---"
build "bench rom" "$ROOT/samples/bench/build.sh"
printf "building %-16s" "bench tool"
if (cd "$ROOT/emulator" && haxe bench.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi
neko "$ROOT/emulator/bin/bench.n" 	"$ROOT/samples/bench/rom/out/release/rom.bin" 	"$ROOT/samples/bench/rom/out/release/rom.out" 	array:c array:haxe wide:haxe wide:c objects:haxe objects:c

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
echo "--- a planted bug, found by stepping Haxe ---"
build "bug rom" "$ROOT/samples/bug/build.sh" debug

printf "building %-16s" "debugger"
if (cd "$ROOT/emulator" && haxe debug.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi

# the line the bug sits on comes from the sample itself, so moving it moves the expectation
WANT="$(grep -n "planted bug" "$ROOT/samples/bug/hx/Main.hx" | cut -d: -f1)"
SESSION="$(neko "$ROOT/emulator/bin/debug.n" \
	"$ROOT/samples/bug/rom/out/debug/rom.bin" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" \
	--break Main.accumulate --watch Main.total --expect 1,5,14,30)"

echo "$SESSION" | sed 's/^/  /'

printf "debug %-18s" "named the line"
case "$SESSION" in
	*"found: Main.hx:$WANT "*) echo "ok" ;;
	*) echo "FAILED"; echo "  expected the bug on Main.hx:$WANT"; exit 1 ;;
esac

echo ""
echo "--- a trace in Haxe, checked against the core that ran it ---"
# the tool exits nonzero when the trace does not account for itself, and set -e would take
# the script out before the check below could say why
if TRACE="$(neko "$ROOT/emulator/bin/debug.n" \
	"$ROOT/samples/bug/rom/out/debug/rom.bin" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" \
	--break Main.accumulate --trace 20000)"; then
	TRACED=0
else
	TRACED=$?
fi

echo "$TRACE" | head -4 | sed 's/^/  /'
echo "  ..."
echo "$TRACE" | tail -1 | sed 's/^/  /'

# every instruction either falls through by its own length or says it moves the pc, which holds
# the disassembler to the core that just ran the same bytes
printf "trace %-18s" "accounted for"
if [ "$TRACED" -eq 0 ]; then
	echo "ok"
else
	echo "FAILED"
	echo "$TRACE" | tail -8
	exit 1
fi

printf "trace %-18s" "named the Haxe"
if [ "$(echo "$TRACE" | grep -c "Main.hx:.*Main.accumulate")" -gt 0 ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  no line of the trace named Main.accumulate in Main.hx"
	exit 1
fi

echo ""
echo "--- where a frame went, in Haxe function names ---"
if PROFILE="$(neko "$ROOT/emulator/bin/debug.n" \
	"$ROOT/samples/conformance/rom/out/debug/rom.bin" \
	"$ROOT/samples/conformance/rom/out/debug/rom.out" \
	"$ROOT/samples/conformance/rom/src" \
	--break Main.main --profile 3)"; then
	PROFILED=0
else
	PROFILED=$?
fi

echo "$PROFILE" | sed 's/^/  /'

# the profile adds up to the frame only if every cycle the machine spent landed against a name
printf "profile %-16s" "adds up"
if [ "$PROFILED" -eq 0 ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  the attributed cycles did not add up to the frame"
	exit 1
fi

printf "profile %-16s" "named the Haxe"
case "$(echo "$PROFILE" | sed -n '4p')" in
	*"  Main."*) echo "ok" ;;
	*) echo "FAILED"; echo "  the heaviest name was not a Haxe function"; exit 1 ;;
esac

echo ""
echo "--- the VDP read back in the terms the documentation uses ---"
printf "building %-16s" "viewers"
if (cd "$ROOT/emulator" && haxe view.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi
neko "$ROOT/emulator/bin/view.n"

# the art ROM carries a sprite the sample declares the size of, so the view is checked against
# the Haxe that asked for it rather than against a number written here
if VIEW="$(neko "$ROOT/emulator/bin/debug.n" \
	"$ROOT/samples/art/rom/out/release/rom.bin" \
	"$ROOT/samples/art/rom/out/release/rom.out" \
	"$ROOT/samples/art/rom/src" \
	--view --settle 40)"; then
	VIEWED=0
else
	VIEWED=$?
fi

echo ""
echo "$VIEW" | sed 's/^/  /'

printf "view %-21s" "the ROM ran"
if [ "$VIEWED" -eq 0 ]; then
	echo "ok"
else
	echo "FAILED"
	exit 1
fi

WANT_SPRITE="$(sed -n 's/.*@:sprite("gfx\/diamond.png", \([0-9]*\), \([0-9]*\)).*/\1x\2/p' \
	"$ROOT/samples/art/hx/Art.hx")"

printf "view %-21s" "the declared sprite"
case "$VIEW" in
	*"$WANT_SPRITE cells"*) echo "ok" ;;
	*) echo "FAILED"; echo "  no sprite of $WANT_SPRITE cells, which is what Art.hx asked for"; exit 1 ;;
esac

printf "view %-21s" "the image landed"
if echo "$VIEW" | sed -n '/plane A/,$p' | grep -qE '01[0-9A-F]'; then
	echo "ok"
else
	echo "FAILED"
	echo "  plane A holds none of the tiles the image was built into"
	exit 1
fi

echo ""
echo "--- where the beam was when the code touched the VDP ---"
if RASTER="$(neko "$ROOT/emulator/bin/debug.n" \
	"$ROOT/samples/art/rom/out/release/rom.bin" \
	"$ROOT/samples/art/rom/out/release/rom.out" \
	"$ROOT/samples/art/rom/src" \
	--raster 60 --settle 0)"; then
	RASTERED=0
else
	RASTERED=$?
fi

echo "$RASTER" | sed -n '1,2p' | sed 's/^/  /'
echo "$RASTER" | sed -n '/who touched it/,$p' | sed 's/^/  /'

# every write is placed against the beam, and every one is attributed to a symbol
printf "raster %-19s" "every write placed"
if [ "$RASTERED" -eq 0 ]; then
	echo "ok"
else
	echo "FAILED"
	echo "$RASTER" | tail -4
	exit 1
fi

printf "raster %-19s" "named the waiter"
case "$RASTER" in
	*VDP_waitVBlank*) echo "ok" ;;
	*) echo "FAILED"; echo "  nothing was attributed to the routine that polls the VDP"; exit 1 ;;
esac

# a commercial ROM is the widest test there is, and the one thing here that cannot be committed
GAME="$ROOT/_realRomTest/sth2.md"
if [ -f "$GAME" ]; then
	echo ""
	echo "--- a commercial ROM, booted on hx68k-emu ---"
	printf "building %-16s" "game check"
	if (cd "$ROOT/emulator" && haxe game.hxml) > "$LOG" 2>&1; then
		echo "ok"
	else
		echo "FAILED"
		cat "$LOG"
		exit 1
	fi
	neko "$ROOT/emulator/bin/game.n" "$GAME" 120 --digest E902E100
fi

echo ""
echo "--- 68000 cycle-accuracy conformance (SingleStepTests) ---"
"$ROOT/emulator/run-sst.sh" 2>&1 | tail -12

echo ""
echo "--- z80 cycle-accuracy conformance (SingleStepTests) ---"
"$ROOT/emulator/run-z80.sh" 2>&1 | tail -9

echo ""
echo "--- the disassembler against the same 68000 fixtures ---"
"$ROOT/emulator/run-disassembly.sh" --ci

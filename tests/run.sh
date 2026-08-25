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

# the ROMs are padded and checksummed by hx68k rather than by sizebnd.jar. Where a JVM is here,
# hold the two to the same bytes on the unpadded output the linker actually produced.
printf "codegen %-16s" "rom padding"
SIZEBND_JAR="$ROOT/vendor/SGDK/bin/sizebnd.jar"
RAW="$HERE/.pad"
if command -v java > /dev/null 2>&1 && [ -f "$SIZEBND_JAR" ]; then
	rm -rf "$RAW"
	mkdir -p "$RAW"
	"$ROOT/vendor/SGDK/bin/objcopy" -O binary "$ROOT/samples/spike/rom/out/release/rom.out" "$RAW/theirs.bin"
	cp "$RAW/theirs.bin" "$RAW/ours.bin"
	java -jar "$SIZEBND_JAR" "$RAW/theirs.bin" -sizealign 131072 -checksum > "$LOG" 2>&1
	haxelib run hx68k pad "$RAW/ours.bin" -sizealign 131072 -checksum > "$LOG" 2>&1
	if cmp -s "$RAW/theirs.bin" "$RAW/ours.bin"; then
		echo "ok"
	else
		echo "FAILED"
		echo "  hx68k pad and sizebnd.jar disagree on the spike ROM"
		exit 1
	fi
	rm -rf "$RAW"
else
	echo "skipped, no JVM to compare against"
fi

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

# the line the bug sits on is found by the wrong arithmetic itself, so moving it moves the
# expectation and nothing has to be kept in step by hand
WANT="$(grep -n "total = total + i + i;" "$ROOT/samples/bug/hx/Main.hx" | cut -d: -f1)"
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
echo "--- what DWARF says a function's parameters and locals are ---"
LOCALS="$(neko "$MAP" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" --locals Main_accumulate)"
echo "$LOCALS" | sed 's/^/  /'

# the names come from the sample, so renaming what it declares moves the expectation with it
BUG_SAMPLE="$ROOT/samples/bug/hx/Main.hx"
WANT_PARAMETER="$(sed -n 's/.*function accumulate(\([a-zA-Z_][a-zA-Z0-9_]*\):.*/\1/p' "$BUG_SAMPLE")"
WANT_LOCAL="$(sed -n 's/.*var \([a-zA-Z_][a-zA-Z0-9_]*\) = 1;.*/\1/p' "$BUG_SAMPLE")"

printf "locals %-17s" "the parameter"
case "$LOCALS" in
	*"  $WANT_PARAMETER "*parameter*) echo "ok" ;;
	*) echo "FAILED"; echo "  no parameter named $WANT_PARAMETER, which is what the sample declares"; exit 1 ;;
esac

printf "locals %-17s" "the local"
case "$LOCALS" in
	*"  $WANT_LOCAL "*local*) echo "ok" ;;
	*) echo "FAILED"; echo "  no local named $WANT_LOCAL, which is what the sample declares"; exit 1 ;;
esac

# every frame base gcc writes here is the call frame address, which is what a CFI reader resolves
printf "locals %-17s" "the frame base"
case "$LOCALS" in
	*"frame base the call frame address"*) echo "ok" ;;
	*) echo "FAILED"; echo "  the frame base was not the call frame address"; exit 1 ;;
esac

# reading it needs the frame rule out of .debug_frame, so the value proves that chain end to end
WANT_ARGUMENT="$(sed -n 's/.*accumulate(\([0-9]*\));.*/\1/p' "$BUG_SAMPLE")"
PARAMETER="$(neko "$ROOT/emulator/bin/debug.n" \
	"$ROOT/samples/bug/rom/out/debug/rom.bin" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" \
	--break Main.accumulate --read "$WANT_PARAMETER" | tail -1)"
echo "  $PARAMETER"

printf "locals %-17s" "read at a frame"
if [ "${PARAMETER##*= }" = "$WANT_ARGUMENT" ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  wanted $WANT_ARGUMENT, which is what the sample passes to accumulate"
	exit 1
fi

# i lives in a location list, in a register for the stretch of the loop and nowhere before it, so
# reading it needs the list resolved at the address the program has actually reached
read_local() {
	neko "$ROOT/emulator/bin/debug.n" \
		"$ROOT/samples/bug/rom/out/debug/rom.bin" \
		"$ROOT/samples/bug/rom/out/debug/rom.out" \
		"$ROOT/samples/bug/rom/src" \
		--break "Main.hx:$WANT" --read "$WANT_LOCAL" --hits "$1" | tail -1
}

PASS=1
while [ "$PASS" -le "$WANT_ARGUMENT" ]; do
	LINE="$(read_local "$PASS")"
	echo "  pass $PASS: $LINE"
	printf "locals %-17s" "the loop, pass $PASS"
	if [ "${LINE##*= }" = "$PASS" ]; then
		echo "ok"
	else
		echo "FAILED"
		echo "  the loop variable should be $PASS on its pass $PASS"
		exit 1
	fi
	PASS=$((PASS + 1))
done

# the loop runs as many times as the argument says and no more
printf "locals %-17s" "and stops there"
case "$(read_local "$PASS")" in
	*"not $PASS"*) echo "ok" ;;
	*) echo "FAILED"; echo "  the line was reached a $PASS th time"; exit 1 ;;
esac

echo ""
echo "--- who called whom, read off the stack ---"

backtrace() {
	neko "$ROOT/emulator/bin/debug.n" \
		"$ROOT/samples/conformance/rom/out/debug/rom.bin" \
		"$ROOT/samples/conformance/rom/out/debug/rom.out" \
		"$ROOT/samples/conformance/rom/src" \
		--break Main.fib --stack --hits "$1"
}

STACK="$(backtrace 6)"
echo "$STACK" | sed 's/^/  /'

# fib recurses down its first branch before its second, so the sixth call stands six deep, and
# three frames of SGDK getting there sit under it
printf "stack %-18s" "one frame a call"
DEEP="$(echo "$STACK" | grep -cE '^  [0-9A-F]{6}  Main\.fib')"
if [ "$DEEP" -eq 6 ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  six calls deep should show six frames of Main.fib, not $DEEP"
	exit 1
fi

printf "stack %-18s" "down to the entry"
case "$(echo "$STACK" | grep -c "_start_entry")" in
	1) echo "ok" ;;
	*) echo "FAILED"; echo "  the walk did not reach SGDK's entry exactly once"; exit 1 ;;
esac

# three more calls have to be three more frames, which no number written here decides
# the frame rule and the scan reach the caller by nothing in common, so agreeing is a real check
printf "stack %-18s" "agrees with DWARF"
case "$STACK" in
	*"which the scan also found"*) echo "ok" ;;
	*) echo "FAILED"; echo "  the frame rule and the stack scan disagree on the return address"; exit 1 ;;
esac

printf "stack %-18s" "grows with calls"
SHALLOW="$(backtrace 3 | grep -oE '^[0-9]+ frames' | cut -d" " -f1)"
DEEPER="$(echo "$STACK" | grep -oE '^[0-9]+ frames' | cut -d" " -f1)"
if [ "$((DEEPER - SHALLOW))" -eq 3 ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  three more calls gave $SHALLOW then $DEEPER frames"
	exit 1
fi

echo ""
echo "--- Haxe statics read at the width they were declared with ---"

read_static() {
	neko "$ROOT/emulator/bin/debug.n" \
		"$ROOT/samples/conformance/rom/out/debug/rom.bin" \
		"$ROOT/samples/conformance/rom/out/debug/rom.out" \
		"$ROOT/samples/conformance/rom/src" \
		--break Main.interfaceCall --read "$1" | tail -1
}

SAMPLE="$ROOT/samples/conformance/hx/Main.hx"

# the values come from the sample, so changing what it declares moves the expectation with it
WANT_PI="$(sed -n 's/.*@:romData(\[\([0-9]*\),.*/\1/p' "$SAMPLE")"
WANT_PLACED="$(sed -n 's/.*static var placed:Int = \([0-9]*\);.*/\1/p' "$SAMPLE")"

for WATCH in Main.digitsOfPi:"$WANT_PI" Main.placed:"$WANT_PLACED"; do
	NAME="${WATCH%%:*}"
	WANT="${WATCH##*:}"
	LINE="$(read_static "$NAME")"
	echo "  $LINE"
	printf "watch %-18s" "${NAME#Main.}"
	if [ "${LINE##*= }" = "$WANT" ]; then
		echo "ok"
	else
		echo "FAILED"
		echo "  wanted $WANT, which is what the sample declares"
		exit 1
	fi
done

# a byte-wide static read as a long smears the bytes after it into the answer, so the test that
# matters is that it fits in a byte at all; it holds the minus sign formatting wrote into it
BUFFER="$(read_static Main.buffer)"
echo "  $BUFFER"
printf "watch %-18s" "buffer, one byte"
BYTE="${BUFFER##*= }"
if [ "$BYTE" -ge 0 ] && [ "$BYTE" -le 255 ] && [ "$BYTE" -eq 45 ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  wanted 45, the minus sign, in a single byte"
	exit 1
fi

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
echo "--- the frontend layout model, held to the 1280x720 floor ---"
printf "building %-16s" "layout"
if (cd "$ROOT/emulator" && haxe layout.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi
neko "$ROOT/emulator/bin/layout.n"

echo ""
echo "--- the focus stack and the text field, with no window under them ---"
printf "building %-16s" "widgets"
if (cd "$ROOT/emulator" && haxe widget.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi
neko "$ROOT/emulator/bin/widget.n"

echo ""
echo "--- the settings file, and the arrangement it has to bring back ---"
printf "building %-16s" "settings"
if (cd "$ROOT/emulator" && haxe settings.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi
neko "$ROOT/emulator/bin/settings.n" "$HERE/.settings"
rm -rf "$HERE/.settings"

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

printf "view %-19s" "the ROM ran"
if [ "$VIEWED" -eq 0 ]; then
	echo "ok"
else
	echo "FAILED"
	exit 1
fi

WANT_SPRITE="$(sed -n 's/.*@:sprite("gfx\/diamond.png", \([0-9]*\), \([0-9]*\)).*/\1x\2/p' \
	"$ROOT/samples/art/hx/Art.hx")"

printf "view %-19s" "declared sprite"
case "$VIEW" in
	*"$WANT_SPRITE cells"*) echo "ok" ;;
	*) echo "FAILED"; echo "  no sprite of $WANT_SPRITE cells, which is what Art.hx asked for"; exit 1 ;;
esac

printf "view %-19s" "image landed"
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
printf "raster %-17s" "writes placed"
if [ "$RASTERED" -eq 0 ]; then
	echo "ok"
else
	echo "FAILED"
	echo "$RASTER" | tail -4
	exit 1
fi

printf "raster %-17s" "named the waiter"
case "$RASTER" in
	*VDP_waitVBlank*) echo "ok" ;;
	*) echo "FAILED"; echo "  nothing was attributed to the routine that polls the VDP"; exit 1 ;;
esac

echo ""
echo "--- a state a machine can be put back into ---"
printf "building %-16s" "savestates"
if (cd "$ROOT/emulator" && haxe state.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi
neko "$ROOT/emulator/bin/state.n" "$ROOT"

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

	# the title screen is the narrowest thing this ROM does. Its attract mode reaches a two-player
	# Emerald Hill about 1,200 frames in, which is the only place here that draws interlaced planes
	# and interlaced sprites, and the only one that draws a level at all. Four minutes on neko, and
	# it is the widest check in this file.
	echo ""
	neko "$ROOT/emulator/bin/game.n" "$GAME" 1300 --digest E8E80E0E
fi

echo ""
echo "--- the window, which the rest of this never compiles ---"
# the gated builds are neko and reach nothing under hx68k.host, so without this the interface is
# the one part nothing here would notice breaking. Building the window takes a minute and wants
# SDL3 fetched; type checking it takes a couple of seconds and catches the same breakage.
printf "host %-19s" "type checks"
if (cd "$ROOT/emulator" && haxe -cp src -cpp "$HERE/.hostcheck" --no-output \
		hx68k.host.Console hx68k.host.Detached) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
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

# the FM chip is a tracked progress metric, not yet a gate: the registers it does not implement at
# all are listed in docs/YM2612-NOTES.md, and until they are there the number cannot reach the top.
echo ""
echo "--- the FM chip against Nuked OPN2 ---"
"$ROOT/emulator/run-opn.sh" 2>&1 | tail -20

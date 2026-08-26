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
build "pal rom" "$ROOT/samples/pal/build.sh"

# the backend writes rom_header.c itself, which is how -D md-pal reaches the cartridge header:
# SGDK's makefile only copies its own template when the file is not already there
codegen "pal region" "$ROOT/samples/pal/rom/src/rom_header.c" '"E {15}"'
codegen "ntsc region" "$ROOT/samples/spike/rom/src/rom_header.c" '"JUE {13}"' 
build "art rom"     "$ROOT/samples/art/build.sh"
build "events rom"  "$ROOT/samples/events/build.sh"
build "sdk rom"     "$ROOT/samples/sdk/build.sh"
build "harness"     "$HERE/harness/build.sh"

# every check and tool below used to be its own neko build and its own neko run. One hxcpp binary
# holds all of them, chosen by its first argument, built with the three defines the window is built
# with. Measured on the eight cores this is pinned to, that took the whole gate from 940 seconds to
# 61, while adding the 240p walk, the PSG and four more frames of the commercial ROM to it.
printf "building %-16s" "gate"
if (cd "$ROOT/emulator" && haxe gate.hxml) > "$LOG" 2>&1; then
	echo "ok"
else
	echo "FAILED"
	cat "$LOG"
	exit 1
fi

GATE="$ROOT/emulator/bin/gate/Gate.exe"
[ -x "$GATE" ] || GATE="$ROOT/emulator/bin/gate/Gate"
export GATE_BUILT=1

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
"$GATE" rom "$HERE/.observables.txt" "$ROOT"

echo ""
echo "--- the VDP renderer against the hardware documentation ---"
"$GATE" render "$ROOT"

echo ""
echo "--- the sound driver, on the only emulator here with a Z80 ---"
build "sound rom" "$ROOT/samples/sound/build.sh"
"$GATE" sound "$ROOT"

echo ""
echo "--- generated code against the C written beside it, in 68000 cycles ---"
build "bench rom" "$ROOT/samples/bench/build.sh"
"$GATE" bench 	"$ROOT/samples/bench/rom/out/release/rom.bin" 	"$ROOT/samples/bench/rom/out/release/rom.out" 	array:c array:haxe wide:haxe wide:c objects:haxe objects:c palette:haxe palette:c cell:haxe cell:c fill:haxe fill:c patterns:haxe patterns:c sprite:haxe sprite:c transfer:haxe transfer:c

echo ""
echo "--- source map (Haxe line to 68000 address) ---"

# the debug profile keeps DWARF and stops inlining, and writes over out/rom.bin as it goes,
# so it runs once the release ROM has been through the harness
build "debug rom" "$ROOT/samples/conformance/build.sh" debug

DEBUG_ROM="$ROOT/samples/conformance/rom/out/debug/rom.out"
GENERATED="$ROOT/samples/conformance/rom/src"

printf "map %-20s" "named site"
SITE="$("$GATE" map "$DEBUG_ROM" "$GENERATED" Main_virtualDispatch)"
case "$SITE" in
	*"hx/Main.hx:"*"Main.virtualDispatch"*) echo "ok" ;;
	*) echo "FAILED"; echo "  $SITE"; exit 1 ;;
esac
echo "  $SITE"

printf "map %-20s" "static symbols"
STATICS="$("$GATE" map "$DEBUG_ROM" "$GENERATED" --statics | grep -w "Main.digitsOfPi")"
case "$STATICS" in
	*"s32[8]"*"hx/Main.hx:"*) echo "ok" ;;
	*) echo "FAILED"; echo "  $STATICS"; exit 1 ;;
esac
echo "  $STATICS"

"$GATE" map "$DEBUG_ROM" "$GENERATED"

# 68000 core conformance is a tracked progress metric, not yet a gate:
# coverage is partial, so a low overall number is expected and honest.
echo ""
echo "--- a planted bug, found by stepping Haxe ---"
build "bug rom" "$ROOT/samples/bug/build.sh" debug

# nothing reachable from debug.hxml may import a display library, and this neko build is what says
# so: the gate binary links the window's own pure parts and cannot make the same claim
printf "building %-16s" "no display"
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
SESSION="$("$GATE" debug \
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
LOCALS="$("$GATE" map \
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
PARAMETER="$("$GATE" debug \
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
# One run covers every pass, and the pass after the last, which is where it has to say it never
# got there.
STOP=$((WANT_ARGUMENT + 1))

PASSES="$("$GATE" debug \
	"$ROOT/samples/bug/rom/out/debug/rom.bin" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" \
	--break "Main.hx:$WANT" --read "$WANT_LOCAL" --hits "$(seq -s, 1 "$STOP")" || true)"

PASS=1
while [ "$PASS" -le "$WANT_ARGUMENT" ]; do
	LINE="$(echo "$PASSES" | grep "^$WANT_LOCAL " | sed -n "${PASS}p")"
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
case "$PASSES" in
	*"not $STOP"*) echo "ok" ;;
	*) echo "FAILED"; echo "  the line was reached a $STOP th time"; exit 1 ;;
esac

# the samples are DWARF 4 and the SGDK units linked beside them are DWARF 5, so this is the only
# place a version 5 unit header and .debug_loclists are read. VDP_waitVBlank is on the path of
# every sample that waits for a frame and SGDK calls it with TRUE, which is what forceNext holds.
# vcnt is kept in a location list rather than at a frame offset, and what it holds is the vertical
# counter the machine reports for itself, so the two have to say the same line.
# the samples are DWARF 4 and the SGDK units linked beside them are DWARF 5, so this is the only
# place a version 5 unit header and .debug_loclists are read at all. VDP_waitVBlank is on the path
# of every sample that waits for a frame and SGDK calls it with TRUE, which is what forceNext
# holds. Its vcnt and blank are kept in location lists rather than at frame offsets, and what they
# read is held to what gdb reads for the same variables at the same address, since gdb brings its
# own DWARF reader and reaches the machine only through the stub.
echo ""
echo "--- the same, out of the DWARF 5 the library beside it was built with ---"

LIBRARY="$("$GATE" map "$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" --locals VDP_waitVBlank)"
echo "$LIBRARY" | sed 's/^/  /'

printf "dwarf5 %-19s" "reads the unit"
case "$LIBRARY" in
	*forceNext*parameter*) echo "ok" ;;
	*) echo "FAILED"; echo "  no parameter came out of a version 5 unit"; exit 1 ;;
esac

printf "dwarf5 %-19s" "finds a list"
case "$LIBRARY" in
	*"in a location list at"*) echo "ok" ;;
	*) echo "FAILED"; echo "  no local of it was held in a location list"; exit 1 ;;
esac

FORCED="$("$GATE" debug \
	"$ROOT/samples/bug/rom/out/debug/rom.bin" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" --break VDP_waitVBlank --read forceNext | tail -1)"
echo "  $FORCED"

printf "dwarf5 %-19s" "reads a parameter"
if [ "${FORCED##*= }" = "1" ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  SGDK waits for the next frame, so forceNext should read 1"
	exit 1
fi

# the entry comes out of the symbol table, so relinking moves the sweep with it, and the first
# address where the list resolves is where gdb is pointed rather than an offset written down here
ENTRY="$("$ROOT/vendor/SGDK/bin/nm.exe" "$ROOT/samples/bug/rom/out/debug/rom.out" \
	| sed -n 's/^0*\([0-9a-fA-F][0-9a-fA-F]*\) [Tt] VDP_waitVBlank$/\1/p')"

if [ -z "$ENTRY" ]; then
	echo "FAILED"
	echo "  the symbol table has no VDP_waitVBlank"
	exit 1
fi

LIVE_AT=""
for STRIDE in 16 32 48 54 64 80 96 112 128; do
	WHERE="$(printf '0x%X' $(( 0x$ENTRY + STRIDE )))"
	SEEN="$("$GATE" debug \
		"$ROOT/samples/bug/rom/out/debug/rom.bin" \
		"$ROOT/samples/bug/rom/out/debug/rom.out" \
		"$ROOT/samples/bug/rom/src" --break "$WHERE" --read vcnt,blank 2>/dev/null || true)"
	OURS_VCNT="$(echo "$SEEN" | sed -n 's/^vcnt .*= \([0-9][0-9]*\)$/\1/p')"
	OURS_BLANK="$(echo "$SEEN" | sed -n 's/^blank .*= \([0-9][0-9]*\)$/\1/p')"
	if [ -z "$OURS_VCNT" ]; then continue; fi
	LIVE_AT="$WHERE"
	break
done

printf "dwarf5 %-19s" "a list resolves"
if [ -n "$LIVE_AT" ]; then
	echo "ok"
	echo "  at $LIVE_AT the lists read vcnt $OURS_VCNT and blank $OURS_BLANK"
else
	echo "FAILED"
	echo "  nothing in VDP_waitVBlank resolved through .debug_loclists"
	exit 1
fi

GDB_WORK="$HERE/.gdb"
rm -rf "$GDB_WORK"
mkdir -p "$GDB_WORK"

"$GATE" debug \
	"$ROOT/samples/bug/rom/out/debug/rom.bin" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" --settle 0 --gdb 2159 > "$GDB_WORK/library.txt" 2>&1 &
STUB=$!

WAITED=0
while [ "$WAITED" -lt 300 ]; do
	if grep -q "waiting for a connection" "$GDB_WORK/library.txt" 2>/dev/null; then break; fi
	sleep 0.1
	WAITED=$((WAITED + 1))
done

GDB_PORT="$(sed -n 's/.*127\.0\.0\.1:\([0-9]*\),.*/\1/p' "$GDB_WORK/library.txt")"
{
	echo "set confirm off"
	echo "set pagination off"
	echo "target remote 127.0.0.1:${GDB_PORT:-2159}"
	echo "break *$LIVE_AT"
	echo "continue"
	echo "print vcnt"
	echo "print blank"
	echo "detach"
} > "$GDB_WORK/library.gdb"

THEIRS="$(timeout 120 "$ROOT/vendor/SGDK/bin/gdb.exe" -q -batch -x "$GDB_WORK/library.gdb" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" 2>&1 \
	| grep -v "host encoding" | grep -v "please file a bug report")"
wait "$STUB" 2>/dev/null || kill "$STUB" 2>/dev/null || true

GDB_VCNT="$(echo "$THEIRS" | sed -n 's/^\$1 = \([0-9][0-9]*\).*/\1/p')"
GDB_BLANK="$(echo "$THEIRS" | sed -n 's/^\$2 = \([0-9][0-9]*\).*/\1/p')"
echo "  gdb reads vcnt ${GDB_VCNT:-nothing} and blank ${GDB_BLANK:-nothing} at the same address"

printf "dwarf5 %-19s" "gdb reads the same"
if [ -n "$GDB_VCNT" ] && [ "$GDB_VCNT" = "$OURS_VCNT" ] && [ "$GDB_BLANK" = "$OURS_BLANK" ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  gdb read $GDB_VCNT and $GDB_BLANK where this read $OURS_VCNT and $OURS_BLANK"
	exit 1
fi

# enabled is kept as an expression rather than a place: gcc writes it as a register masked with
# 0x40 and left on the stack, which gdb evaluates and this does not. What this must not do is
# take the first operation for a place and read memory that has nothing to do with it.
COMPUTED="$("$GATE" debug \
	"$ROOT/samples/bug/rom/out/debug/rom.bin" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" --break "$LIVE_AT" --read enabled 2>/dev/null || true)"
echo "  $(echo "$COMPUTED" | tail -1)"

printf "dwarf5 %-19s" "and an expression"
case "$COMPUTED" in
	*"= "[0-9]*) echo "FAILED"
		echo "  an expression this cannot evaluate came back as a number anyway"
		exit 1 ;;
	*) echo "ok" ;;
esac

echo ""
echo "--- the gdb remote serial protocol, spoken to itself ---"
"$GATE" gdb

# and then spoken to the real thing. SGDK ships m68k-elf-gdb, so the same sample is debugged again
# with gdb driving it: gdb reads DWARF out of rom.out on its own and reaches the machine only
# through the stub, so every value it prints came back over the protocol. The line it stops on is
# the generated C that steps the loop variable, found by the name the sample declares, and the
# values it reads there have to be the ones the debugger above already read a different way.
echo ""
echo "--- the same machine, debugged by gdb itself ---"

GDB_WORK="$HERE/.gdb"
GDB_LINE="$(grep -n "^	*$WANT_LOCAL++;" "$ROOT/samples/bug/rom/src/Main.c" | cut -d: -f1)"

rm -rf "$GDB_WORK"
mkdir -p "$GDB_WORK"

"$GATE" debug \
	"$ROOT/samples/bug/rom/out/debug/rom.bin" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" \
	"$ROOT/samples/bug/rom/src" --settle 0 --gdb 2159 > "$GDB_WORK/stub.txt" 2>&1 &
STUB=$!

WAITED=0
while [ "$WAITED" -lt 300 ]; do
	if grep -q "waiting for a connection" "$GDB_WORK/stub.txt" 2>/dev/null; then break; fi
	sleep 0.1
	WAITED=$((WAITED + 1))
done

GDB_PORT="$(sed -n 's/.*127\.0\.0\.1:\([0-9]*\),.*/\1/p' "$GDB_WORK/stub.txt")"
if [ -z "$GDB_PORT" ]; then
	echo "FAILED"
	echo "  the stub never said which port it took"
	cat "$GDB_WORK/stub.txt"
	kill "$STUB" 2>/dev/null || true
	exit 1
fi

{
	echo "set confirm off"
	echo "set pagination off"
	echo "target remote 127.0.0.1:$GDB_PORT"
	echo "break Main_accumulate"
	echo "continue"
	echo "print $WANT_PARAMETER"
	echo "break Main.c:$GDB_LINE"
	PASS=1
	while [ "$PASS" -le "$WANT_ARGUMENT" ]; do
		echo "continue"
		echo "print $WANT_LOCAL"
		PASS=$((PASS + 1))
	done
	echo "bt"
	echo "detach"
} > "$GDB_WORK/session.gdb"

# a stub that never stops leaves gdb waiting for a stop reply that is not coming, so the session
# is held to two minutes and one that runs out of them fails on what it did not print
SEEN="$(timeout 120 "$ROOT/vendor/SGDK/bin/gdb.exe" -q -batch -x "$GDB_WORK/session.gdb" \
	"$ROOT/samples/bug/rom/out/debug/rom.out" 2>&1 \
	| grep -v "host encoding" | grep -v "please file a bug report")"
wait "$STUB" 2>/dev/null || kill "$STUB" 2>/dev/null || true

echo "$SEEN" | sed 's/^/  /'

printf "gdb %-22s" "reached the function"
case "$SEEN" in
	*"Main_accumulate ($WANT_PARAMETER=$WANT_ARGUMENT)"*) echo "ok" ;;
	*) echo "FAILED"
	   echo "  gdb never stopped in Main_accumulate with $WANT_PARAMETER = $WANT_ARGUMENT"
	   exit 1 ;;
esac

printf "gdb %-22s" "read the parameter"
GDB_READ="$(echo "$SEEN" | grep '^\$1 = ' | sed 's/^\$1 = //')"
if [ "$GDB_READ" = "$WANT_ARGUMENT" ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  gdb read $WANT_PARAMETER as ${GDB_READ:-nothing}, not $WANT_ARGUMENT"
	exit 1
fi

PASS=1
while [ "$PASS" -le "$WANT_ARGUMENT" ]; do
	printf "gdb %-22s" "the loop, pass $PASS"
	GDB_READ="$(echo "$SEEN" | grep "^\\\$$((PASS + 1)) = " | sed "s/^\\\$$((PASS + 1)) = //")"
	if [ "$GDB_READ" = "$PASS" ]; then
		echo "ok"
	else
		echo "FAILED"
		echo "  gdb read $WANT_LOCAL as ${GDB_READ:-nothing} on pass $PASS"
		exit 1
	fi
	PASS=$((PASS + 1))
done

printf "gdb %-22s" "walked the stack"
case "$SEEN" in
	*"#0  Main_accumulate"*"Main_main"*) echo "ok" ;;
	*) echo "FAILED"; echo "  gdb did not put Main_main under Main_accumulate"; exit 1 ;;
esac

printf "gdb %-22s" "and let go"
case "$(cat "$GDB_WORK/stub.txt")" in
	*"closed after 1 session"*) echo "ok" ;;
	*) echo "FAILED"; cat "$GDB_WORK/stub.txt"; exit 1 ;;
esac

echo ""
echo "--- who called whom, read off the stack ---"

backtrace() {
	"$GATE" debug \
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

SAMPLE="$ROOT/samples/conformance/hx/Main.hx"

# all three come off one run, which reaches the breakpoint once instead of three times
STATICS_READ="$("$GATE" debug \
	"$ROOT/samples/conformance/rom/out/debug/rom.bin" \
	"$ROOT/samples/conformance/rom/out/debug/rom.out" \
	"$ROOT/samples/conformance/rom/src" \
	--break Main.interfaceCall --read Main.digitsOfPi,Main.placed,Main.buffer)"

read_static() {
	echo "$STATICS_READ" | grep "^$1 " | tail -1
}

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
if TRACE="$("$GATE" debug \
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
if PROFILE="$("$GATE" debug \
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
"$GATE" layout

echo ""
echo "--- the SN76489, driven through its one port with nothing else in the machine ---"
"$GATE" psg

echo ""
echo "--- the VDP's access slots and its write FIFO, with no ROM under them ---"
"$GATE" slot

# every one of the fifteen suites passes, so this is a gate rather than a tracked metric now
echo ""
echo "--- the VDP against Nemesis' port access ROM ---"
"$GATE" fifo "$ROOT"

# every one of its nine tests passes in both widths, so this is a gate rather than a metric now
# two 68000 ROMs that check themselves. The illegal opcode one paints the screen green when every
# encoding it tries takes the illegal instruction vector and red when one does not, which is how
# that was established: sending them to vector 11 instead turns it red. The BCD one prints an error
# count for ABCD, SBCD and NBCD in both value and flags, and every one of the six reads zero. Both
# are held to the frame they drew, so either number changing is a failure.
echo ""
echo "--- two self-checking 68000 ROMs ---"
"$GATE" game "$ROOT/vendor/M68000Tests/illegal.bin" 600 --digest 600:9C000000
"$GATE" game "$ROOT/vendor/M68000Tests/bcd.bin" 900 --digest 900:B9DDED13

echo ""
echo "--- Nemesis' sprite masking and overflow ROM, in both widths ---"
"$GATE" sprite "$ROOT"

echo ""
echo "--- the 240p Test Suite's patterns, walked through its own menus ---"
"$GATE" pattern "$ROOT"

echo ""
echo "--- the focus stack and the text field, with no window under them ---"
"$GATE" widget

echo ""
echo "--- the settings file, and the arrangement it has to bring back ---"
"$GATE" settings "$HERE/.settings"
rm -rf "$HERE/.settings"

echo ""
echo "--- the VDP read back in the terms the documentation uses ---"
"$GATE" view

# the art ROM carries a sprite the sample declares the size of, so the view is checked against
# the Haxe that asked for it rather than against a number written here
if VIEW="$("$GATE" debug \
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
if RASTER="$("$GATE" debug \
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

# every external access slot a line offers is one the VDP can spend on the outside world, and a
# line that spends more than it has is the model creating bandwidth the hardware does not have.
# The art ROM clears VRAM with a fill at boot, which saturates every blanked line it runs across,
# so this is where that would show.
echo ""
echo "--- what a frame's VDP access slots went on ---"
SPEND="$("$GATE" debug "$ROOT/samples/art/rom/out/release/rom.bin" --settle 12 --slots 1)"
echo "$SPEND"

printf "slots %-18s" "none overspent"
case "$SPEND" in
	*"no line spent more slots than it had"*) echo "ok" ;;
	*) echo "FAILED"; echo "  a line spent slots the hardware does not have"; exit 1 ;;
esac

USED="$(echo "$SPEND" | sed -n 's/.*was the busiest, spending \([0-9]*\) of its \([0-9]*\) slots/\1/p')"
OPEN="$(echo "$SPEND" | sed -n 's/.*was the busiest, spending \([0-9]*\) of its \([0-9]*\) slots/\2/p')"

printf "slots %-18s" "a fill saturates"
if [ -n "$USED" ] && [ "$USED" = "$OPEN" ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  the busiest line spent ${USED:-nothing} of ${OPEN:-nothing}, where a fill should take them all"
	exit 1
fi

# the window draws the same tallies as a panel, so the panel is read back here on the same frame
PANEL="$("$GATE" debug "$ROOT/samples/art/rom/out/release/rom.bin" --settle 13 --views \
	| sed -n '/--- slots ---/,/^--- /p')"
echo "$PANEL" | sed 's/^/  /'

FROM_REPORT="$(echo "$SPEND" | sed -n 's/.*a fill or a copy moved \([0-9]*\) bytes.*/\1/p')"
FROM_PANEL="$(echo "$PANEL" | sed -n 's/.*by dma  *\([0-9]*\)  .*/\1/p')"

printf "slots %-18s" "the panel agrees"
if [ -n "$FROM_PANEL" ] && [ "$FROM_PANEL" = "$FROM_REPORT" ]; then
	echo "ok"
else
	echo "FAILED"
	echo "  the panel says ${FROM_PANEL:-nothing} bytes where the report says ${FROM_REPORT:-nothing}"
	exit 1
fi

printf "slots %-18s" "and draws it full"
case "$PANEL" in
	*"205/205  ################"*) echo "ok" ;;
	*) echo "FAILED"; echo "  the panel never drew a line spending all of its slots"; exit 1 ;;
esac

echo ""
echo "--- a state a machine can be put back into ---"
"$GATE" state "$ROOT"

# a commercial ROM is the widest test there is, and the one thing here that cannot be committed
GAME="$ROOT/_realRomTest/sth2.md"
if [ -f "$GAME" ]; then
	echo ""
	echo "--- a commercial ROM, booted on hx68k-emu ---"
	# the title screen is the narrowest thing this ROM does, so one run checks seven frames of the
	# attract mode instead: the SEGA logo, two of the title screen, the two-player Emerald Hill it
	# reaches about 1,200 frames in and the same level in motion at 2,000, the title screen it
	# cycles back to at 4,000, and a one-player Chemical Plant Zone at 5,000. The interlaced ones
	# are the only place here that draws interlaced planes and interlaced sprites, and Chemical
	# Plant is the level whose water palette the interrupt spacing fixed. Every one of the seven was
	# looked at before its digest was written here. The widest check in this file, and eleven
	# seconds of it.
	#
	# 1302 rather than 1300 because the fills the level load does now take the time a VDP takes over
	# them, which the game spends waiting: frame 1302 came out bit identical to what frame 1300 drew
	# before, so the two frames are the whole of the difference.
	"$GATE" game "$GAME" 5000 		--digest 120:C18A4C00,400:B8B01EAE,900:6DF58F81,1302:DD3FE8CC,2000:6B1A7DF2,4000:39AE913C,5000:FB672DE9
fi

echo ""
echo "--- the window, which the rest of this never compiles ---"
# the gate binary reaches the window's pure parts but never its window, so without this the
# interface is the one part nothing here would notice breaking. Building the window takes a minute
# and wants SDL3 fetched; type checking it takes a couple of seconds and catches the same breakage.
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

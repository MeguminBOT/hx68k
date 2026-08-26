# HX68K

Haxe for the Sega Mega Drive / Genesis.

Three parts: a Reflaxe compiler backend that turns Haxe into freestanding C for the 68000, a
hardware SDK, and an emulator with a source-level debugger.

## Getting started

```
git clone <this repository>
cd hx68k
haxelib dev hx68k .
haxelib run hx68k setup
```

`setup` pulls every source the build and the gate need into `vendor/`, which is gitignored: SGDK
and its m68k toolchain, reflaxe, SDL3 and miniaudio for the window, Musashi and Nuked-OPN2 to
check answers against, and the SingleStepTests fixtures both cores are held to. It is about 1.6 GB, most of it
the z80 suite.

```
haxelib run hx68k setup --minimal   only what is needed to build a ROM and the window, about 260 MB
haxelib run hx68k check             what is present and what is missing
```

Then:

```
haxelib run hx68k build                    the emulator window
haxelib run hx68k run <rom.bin>            build it and run a ROM in it
haxelib run hx68k list                     every target and where it is put
./tests/run.sh                             the gate
cd samples/spike && ./build.sh             Haxe to a ROM
```

`build` takes target names, so `haxelib run hx68k build sst z80 opn` builds those three and
`build --all` builds all thirty-one. `--debug` carries debug information through. The shell scripts
`emulator/build.sh` and `emulator/run-window.sh` call the same thing, so the SDL3 and miniaudio
paths live in one place.

Requires Haxe 4.3+, `git` and `curl`. A JVM is needed only by the two samples that carry
resources: `rescomp.jar` compiles their images and music. Padding and checksums no longer need one.
The m68k toolchain comes with SGDK, so there is nothing else to install.

## What works today

Everything ticked has a test behind it that runs in `./tests/run.sh`, except the Window entries,
which need a running window: their models are gated headlessly and what the window itself was
measured doing is written down in `docs/`. Everything unticked is not started or not finished, and
nothing here is ticked on intent.

### Compiler, Haxe to 68000 C

- [x] Classes, pooled allocation, sized integers, fixed-capacity vectors, fixed point
- [x] Enums as tagged unions, pattern matching as a jump table
- [x] Inheritance with vtables only where something is overridden, interfaces as fat pointers
- [x] Function pointers with nothing on the heap behind them
- [x] Text and constant tables that stay in ROM
- [x] Source maps: a 68000 address back to its Haxe file, line and function
- [x] Optimisation passes, measured against hand-written C in 68000 cycles
- [ ] Anything beyond A6: no closures over heap state, no dynamic dispatch outside vtables

### SDK

- [x] `md.hw.*` raw hardware, one volatile access per call
- [x] SGDK bindings that stand alone, and the resource pipeline behind them
- [x] SGDK bindings that need something running first: the sprite engine, vertical-interrupt
      callbacks, and the XGM driver playing on the Z80 uploaded into the machine
- [x] The palette, native Haxe over `md.hw`, at 327 cycles a sixteen colour load against SGDK's 684
- [x] The tilemap and the patterns, native, at 164 cycles a cell against SGDK's 334, and faster on
      fills and pattern uploads as well
- [x] The sprite attribute table, native, transferred 11.9% faster than SGDK moves its own cache
- [x] The DMA queue, native, at 4018 cycles for four queued transfers and a flush against 4737,
      splitting a transfer that crosses a 128 KB boundary in its source
- [x] The PSG and the YM2612, native, with the PSG's clock folded to a literal by the region define
- [x] `haxelib run hx68k new <name>` writes a project that builds and boots, checked by the gate
- [ ] The last of the Java: `sizebnd` is gone and its replacement is byte for byte the same ROM,
      `rescomp` is not

### Emulator

- [x] 68000 core, 317,500 tests at 100% on final state, cycle counts and bus transactions
- [x] Z80 core, 1,604,000 tests at 100% on state, cycles and pins
- [x] YM2612, 1032 of 1032 fixtures bit identical to Nuked-OPN2
- [x] SN76489 including the noise LFSR, held to 38 checks from its documentation
- [x] Bus, memory map, Z80 arbitration, the SSF2 mapper, pads
- [x] All three interrupts: vertical, horizontal, and the external one the HL trigger raises,
      with the HV counter stopping on it when register 0 asks
- [x] NTSC and PAL, chosen by the cartridge header when the ROM loads: 262 lines at 59.92 frames
      a second, or 313 at 49.70
- [x] VDP renderer: planes, window, sprites, priority, shadow and highlight, H40/H32, V28/V30,
      all three interlace settings, sprite masking and the per-line and per-dot limits
- [x] VDP timing: the four entry write FIFO with its `!DTACK` stall, the external access slots a
      line offers, and all twelve documented DMA rates, exactly rather than to a tolerance
- [x] Both HV counters, walked across a line of each width and across a whole frame
- [x] Sound to the speakers in stereo, resampled, at about 30 ms
- [x] A commercial ROM boots, plays and draws, held to seven frames out to 5,000
- [x] Five hardware test ROMs in the gate: Nemesis' port access ROM at 100% on both pages, his
      sprite masking ROM 9 of 9 in both widths, the 240p suite's seven patterns, and two
      self-checking 68000 ROMs
- [x] A read drains the write FIFO before it happens, which the port access ROM discriminates on,
      and the longest the bus is held matches Sega's own figure to the clock
- [x] The vertical counter's endpoints for both standards and both heights, and what it reads
      under interlace
- [x] What the bus costs: two cycles in every 128 taken from the 68000, and a Z80 reaching the
      68000's bus holding it for eleven of its cycles while paying 3.3 of its own
- [x] The colour the VDP actually puts on the pin: fifteen levels rather than sixteen, spaced on a
      curve rather than evenly, with normal, shadow and highlight three readings of the one ramp
- [ ] A Z80 write through its window into 68000 space, which currently goes nowhere
- [ ] SRAM and EEPROM

### Debugger

- [x] Break on a Haxe function, a Haxe line, or a symbol the Haxe map never heard of
- [x] Step by instruction or by line, and stop on the nth time round
- [x] Read a Haxe static, a local or a parameter by name, through DWARF 4 and DWARF 5
- [x] Backtrace in Haxe names, with no frame pointer to walk
- [x] Disassembler, held to the same fixtures as the core, 100% on all three axes
- [x] Instruction trace beside the Haxe that produced it
- [x] Frame profiler by Haxe function and by scanline
- [x] VDP viewers: layout, palettes, sprites, plane cells, VRAM use
- [x] Raster overlay: where the beam was when the code touched the VDP
- [x] What each scanline spent the VDP's access slots on, and what the FIFO cost the 68000
- [x] Savestates, rewind, and scrubbing back and forward through the ring
- [x] A gdb remote, so the `m68k-elf-gdb` SGDK already ships debugs a machine running here
- [ ] An evaluator for DWARF expressions of more than one operation. gcc writes a `bool` that way,
      and such a variable is reported unreadable rather than guessed at

### Window

- [x] SDL3 and miniaudio called directly, no framework in between
- [x] The machine paced by its own clock, independent of the display and the sound device
- [x] Debugger panels, dockable, each poppable into a window of its own, in a grid or floating
- [x] A settings file, a window that edits it, and every key rebindable
- [x] Savestate and rewind on keys, with a timeline under the toolbar to scrub the ring
- [x] The gdb remote served from the window, so gdb reaches the machine on screen
- [x] Hot reload: the ROM file is watched and loaded again when it changes

### Not started

- [ ] CI, hardware verification on a flashcart, packaging for haxelib
- [ ] The game framework: states, sprites, input and collision, built for this hardware
- [ ] Other 68000 machines: Neo Geo, then arcade boards

The hardware behind the emulator is written up in [docs/68000-NOTES.md](docs/68000-NOTES.md),
[docs/Z80-NOTES.md](docs/Z80-NOTES.md), [docs/VDP-NOTES.md](docs/VDP-NOTES.md),
[docs/YM2612-NOTES.md](docs/YM2612-NOTES.md) and [docs/PSG-NOTES.md](docs/PSG-NOTES.md): what the
fixtures and the test ROMs taught, and what is inferred rather than measured.

## In more detail

The checklist above is the summary. What follows is the evidence behind it.

**Compiler.** Haxe compiles to a real ROM with classes, pooled allocation, sized integers,
fixed-capacity vectors, fixed point, enums as tagged unions, pattern matching as a jump table,
inheritance with vtables only where something is overridden, interfaces as fat pointers, function
pointers with no heap behind them, and text and constant tables that never leave ROM. The ROM boots
and runs correctly on an emulated 68000, and the suite checks the generated C and the map file as
well as the running program. 96 checks, 0 failures.

Given a 68000 address, the map tool names the Haxe file, line and function it came from: 122 of 122
probes, none wrong. The debugger stands on that chain, and it works: a bug planted in a sample is
found by breaking on a Haxe function, stepping Haxe lines and watching a Haxe static, which is what
the whole project was for.

```
break at Main.hx:26  Main.accumulate
  Main.hx:30  Main.total = 2
found: Main.hx:30 sets Main.total to 2 where 1 was expected
```

The same chain reads the other way, as a trace: every instruction the 68000 ran, disassembled,
beside the Haxe line behind it. It says not just which line went wrong but why, since the sample
means to add `i` once and the trace adds it twice.

```
000476  MOVE.l ($FF0046).l,D0       Main.hx:30  Main.accumulate
00047C  ADD.l D1,D0                 Main.hx:30  Main.accumulate
00047E  ADD.l D1,D0                 Main.hx:30  Main.accumulate
000480  MOVE.l D0,($FF0046).l       Main.hx:30  Main.accumulate
```

It watches a local, not just a static. DWARF puts the loop variable of the planted bug in a
register for the stretch of the loop and nowhere at all before it, so reading it means resolving a
location list at the address the program has reached, through a frame base that is the call frame
address and nothing simpler. Breaking on the Haxe line and running it again for each pass:

```
pass 1: i  local  s32  in Main_accumulate = 1
pass 2: i  local  s32  in Main_accumulate = 2
pass 3: i  local  s32  in Main_accumulate = 3
pass 4: i  local  s32  in Main_accumulate = 4
```

The sample says how many passes there are, so the test moves with it. A parameter reads the same
way: `n` is 4, which is what the sample passes.

It says who called whom, in Haxe names. gcc keeps no frame pointer at `-O1`, so the stack is
scanned rather than walked, and a candidate counts as a return address only where a JSR or BSR of
exactly the right length ends on it, which is a test the disassembler makes and the fixtures back.
Six calls into the recursive `fib` in the conformance sample:

```
0007B8  Main.fib                Main.hx:177
0007D0  Main.fib                Main.hx:179       called from $0007CE, on the stack at $FFFD4C
0007D0  Main.fib                Main.hx:179       called from $0007CE, on the stack at $FFFD60
...
000FB2  Main.main               Main.hx:54        called from $000FAC, on the stack at $FFFD9C
002E34  _start_entry            -                 called from $002E2E, on the stack at $FFFDE4
```

A machine can be put back where it was. A savestate holds everything it needs to carry on, and a
ring of them lets a session go back as well as forward. The proof is that the same frames run twice
from the same state reach the same bytes, draw the same frame, and leave the same memory behind:
dropping one word of the prefetch queue from the state was confirmed to fail that before the pass
was believed.

It also says where the beam was when the code touched the VDP, and what was running then. Writes
are split by what actually matters: with the display off, with it on but the beam blanked, and with
it on while the beam is drawing. Over 60 frames of the art ROM, every one of its 267 writes is
placed against the beam, and 140,966 of its 140,991 reads belong to SGDK's `VDP_waitVBlank`.

The VDP reads back the same way, in the terms the documentation uses rather than as addresses: the
layout the registers describe, plane cells decoded into tile and palette and priority, the sprite
list in link order, tiles as their palette indices, and how much of VRAM has been written. Viewing
the art ROM finds the sprite that sample declared, at the size it declared it.

```
sprites 1 in the link chain
    0  at  100,  80  2x2 cells  tile 1020  palette 0  link 0
```

The same reading gives a profile: where a frame's cycles went, named in Haxe. Over three frames of
the conformance sample, `Main.fib` takes 92.9% of them, and the scanline map puts every line but one
against it. The exception is line 224, which is the vertical interrupt, and it is attributed to no
symbol because it belongs to none.

```
   239080   92.9%     16982  Main.fib
     5084      2%       608  Main.breakContinue
     3664    1.4%       470  Main.nested

    0-223  Main.fib
      224  outside any symbol
  225-261  Main.fib
```

The disassembler is held to the fixtures the core is held to, on three axes across all 127 opcode
groups and 317,500 cases: the instruction each group names, every register the suite's own test
names mention, and the length of the instruction, which the fixture's final pc measures for the
215,777 cases that neither branch nor fault. **All three at 100%.** The only encodings it refuses to
name are the 5,000 line-A and line-F cases, which are not instructions.

It is also compared against the core's own dispatch table over every one of the 65,536 opcode words,
which reaches encodings no fixture carries: the two agree on all 57,344 that are not line-A or
line-F traps. Four real disagreements came out of that comparison and are written up in
[docs/68000-NOTES.md](docs/68000-NOTES.md). On real compiled code the trace checks itself the other
way round, against the core that just ran the same bytes: 200,000 instructions of each debug sample,
every one disassembled, every one either falling through by its own length or saying where it moved
the pc.

The generated code is held to the C written beside it, measured in 68000 cycles on the emulated
machine: 19,582 against 19,586 on an array pass, 9,022 against 9,024 on a pass over linked objects,
and identical on a third.

**SDK.** `md.hw` reaches the VDP, the pads, the Z80's bus and both sound chips through one volatile
access each, and a sample ROM that calls nothing from SGDK sets a colour and reads a pad on both
emulators. Above it, `md.*` binds SGDK's VDP, palette, joypad, DMA, system, timer, maths, SRAM and
Z80 layers, checked by a sample that drives each of them. Resources are declared in Haxe and
compiled by SGDK's rescomp from a `.res` file a build macro writes, so an image, a sprite and a tune
reach the ROM with nothing written by hand twice.

**Emulator.** A cycle-accurate 68000 validated against SingleStepTests: all 127 opcode groups
implemented, **317,500 of 317,500 tests passing on final state, cycle counts and bus transactions.**
Around it, a machine: the memory map, the VDP as memory and interrupt source, the Z80 with its own
bus and its share of the master clock, and the clock itself. Six sample ROMs boot on it and
reproduce every observable the Musashi harness recorded running the same ROM, and a seventh runs
only here: the one that waits for the sound driver to answer. The per-pixel renderer draws planes,
window and sprites with their priority order, checked by 29 scenarios written from the hardware
documentation.

It runs in a window. `./emulator/run-window.sh <rom.bin>` builds an hxcpp host that calls SDL3 and
miniaudio directly, with no framework in between, and puts the framebuffer on the screen through one
texture and one quad. The machine is paced off its own clock at the 59.92 frames a second the VDP's
constants give, not off whatever the monitor happens to do. Compiled, the cores run about 435 frames
a second where 60 is wanted, so the picture is not what costs. An earlier version of this host was
built on lime, and `CLAUDE.md` records the four things that were true underneath it that this
repository's own code gave no sign of.

A commercial ROM runs on it: Sonic the Hedgehog 2 boots, uploads its sound driver to the Z80,
plays it, and draws its title screen. Nothing about the game was written for this emulator and
nothing in the emulator was written for the game.

The Z80 is held to the same standard and meets it: all 1,604 opcode groups, **1,604,000 of
1,604,000 tests passing on final state, T-state count and the pin log**, prefixes and undocumented
flags included.

**The VDP is held to the hardware's own test ROMs.** Nemesis' port access ROM passes all fifteen of
its suites, 100% of the pixels on both pages, which is what settled how a CRAM or VSRAM read exposes
the write FIFO and what an 8-bit VRAM read returns. His sprite masking ROM passes 9 of 9 in both
widths, which is what named the four sprite rules. The 240p suite's seven patterns are walked
through its own menus and held to what they drew. Every documented DMA rate now comes out of the
access slot positions rather than being written in, exactly rather than to a tolerance, and
`hx68k.debug.Slots` says what each of a frame's scanlines spent its slots on.

**gdb can drive it.** `hx68k.debug.Gdb` speaks the remote serial protocol, so the `m68k-elf-gdb`
SGDK already ships debugs a machine running here, reading DWARF from `rom.out` itself and reaching
the machine only through the stub. The gate runs the protocol against itself with no gdb involved,
then runs the real thing against the planted-bug sample and holds what it prints to what the
debugger here reads a different way.

```
Breakpoint 2, Main_accumulate (n=4) at src/Main.c:23
$2 = 1
#0  Main_accumulate (n=4) at src/Main.c:23
#1  0x0000049a in Main_main () at src/Main.c:7
#2  0x000004c0 in main (hardReset=1 '\001') at src/hx_entry.c:8
```

See [docs/68000-NOTES.md](docs/68000-NOTES.md), [docs/Z80-NOTES.md](docs/Z80-NOTES.md),
[docs/VDP-NOTES.md](docs/VDP-NOTES.md), [docs/YM2612-NOTES.md](docs/YM2612-NOTES.md) and
[docs/PSG-NOTES.md](docs/PSG-NOTES.md) for the hardware behaviours the fixtures and the test ROMs
revealed.

## Test

```
./tests/run.sh
```

Builds every sample ROM and the headless 68000 harness, boots them on both emulators, runs the
conformance suites, the hardware test ROMs and a commercial ROM where one is present, and exits
nonzero on any failure. About seventy seconds.

## Map a 68000 address back to Haxe

```
cd samples/conformance && ./build.sh debug
./emulator/gate.sh map samples/conformance/rom/out/debug/rom.out samples/conformance/rom/src 0x000D58
```

With no address it checks every function it recorded; with `--statics` it lists each Haxe static
and the address it landed on.

## Build the spike

```
cd samples/spike
./build.sh
```

Produces `samples/spike/rom/out/rom.bin`.

## Layout

```
compiler/    Reflaxe backend, Haxe -> C99 -> m68k
sdk/         md.hw raw hardware, the SGDK bindings above it, and the resource pipeline
samples/     art, bench, bug, conformance, events, hardware, sdk, sound, spike
tests/       headless 68000 harness, built on Musashi, that answers are checked against
emulator/    cycle-accurate cores, the debugger, and the window
vendor/      third-party reference sources and the window's build dependencies
docs/
```

## Vendored sources and licences

`haxelib run hx68k setup` puts these in `vendor/`, which is gitignored. Licences differ and matter:

| Source | Licence | Use |
|---|---|---|
| reflaxe, reflaxe.CPP | MIT | The framework the compiler backend is written on |
| SGDK | MIT (gcc GPL3 + runtime exception) | The m68k toolchain and library |
| SDL3 | zlib | The window, linked as-is |
| miniaudio | MIT-0 / public domain | The audio device, called directly |
| Musashi | MIT | The known-good 68000 the compiler suite checks against, safe to port |
| Nuked-OPN2 | LGPL-2.1 | The FM reference; porting it would make that module LGPL |
| SingleStepTests m68000, z80 | fixtures | The specification both cores are held to |
| Spleen | BSD-2-Clause | The debugger's font, embedded in the source |
| Kabuto's Mega Drive notes | freely published | Hardware measured on real consoles, cited where taken |
| TmEE's VDP colour measurements | freely published | The colour ramp, measured off several consoles |
| VDPFIFOTesting, Sprite Masking Test | test ROMs | What the VDP's ports and sprites are held to |
| 240p Test Suite | test ROM | What the renderer's patterns are held to |
| Flamewing's BCD verifier, an illegal opcode ROM | test ROMs | Two the 68000 core is held to |

Nothing above is patched in place. The harness copies Musashi into `tests/harness/.build/` before
patching it, and anything else needing modification does the same.

These are **not** fetched by `setup`, because nothing here builds against them. They were read while
writing the emulator and are listed so their terms are on the record:

| Source | Licence | Terms |
|---|---|---|
| marsdev | MIT | Non-Windows toolchain builds |
| superzazu/z80 | MIT | Safe to port |
| gwenesis | AGPL-3.0 | **Read-only reference. Never copy.** |
| Genesis Plus GX | non-commercial | **Read-only reference. Never copy.** |

Hardware behaviour here comes from documentation, from the SingleStepTests fixtures, or from test
ROMs. It is not taken by reading a restrictive source and transcribing what it does.

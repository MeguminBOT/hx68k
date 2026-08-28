# What works today, and the evidence behind it

The checklist is in the [README](../README.md). What follows is what stands behind each tick:
numbers that were measured, and what measured them.

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
[docs/notes/68000.md](docs/notes/68000.md). On real compiled code the trace checks itself the other
way round, against the core that just ran the same bytes: 200,000 instructions of each debug sample,
every one disassembled, every one either falling through by its own length or saying where it moved
the pc.

The generated code is held to the C written beside it, measured in 68000 cycles on the emulated
machine: 19,582 against 19,586 on an array pass, 9,022 against 9,024 on a pass over linked objects,
and identical on a third.

**SDK.** `md.hw` reaches the VDP, the pads, the Z80's bus and both sound chips through one volatile
access each, and a sample ROM that calls nothing from SGDK sets a color and reads a pad on both
emulators. Above it, `md.*` binds SGDK's VDP, palette, joypad, DMA, system, timer, maths, SRAM and
Z80 layers, checked by a sample that drives each of them. Resources are declared in Haxe and
compiled by `hxres`, so an image, a sprite and a tune reach the ROM with nothing written by hand
twice.

**Emulator.** A cycle-accurate 68000 validated against SingleStepTests: all 127 opcode groups
implemented, **317,500 of 317,500 tests passing on final state, cycle counts and bus transactions.**
Around it, a machine: the memory map, the VDP as memory and interrupt source, the Z80 with its own
bus and its share of the master clock, and the clock itself. Six sample ROMs boot on it and
reproduce every observable the Musashi harness recorded running the same ROM, and a seventh runs
only here: the one that waits for the sound driver to answer. The per-pixel renderer draws planes,
window and sprites with their priority order, checked by 29 scenarios written from the hardware
documentation.

It runs in a window. `haxelib run hx68k run <rom.bin>` builds an hxcpp host that calls SDL3 and
miniaudio directly, with no framework in between, and puts the framebuffer on the screen through one
texture and one quad. The machine is paced off its own clock at the 59.92 frames a second the VDP's
constants give, not off whatever the monitor happens to do. Compiled, the cores run about 435 frames
a second where 60 is wanted, so the picture is not what costs.

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

See [docs/notes/68000.md](docs/notes/68000.md), [docs/notes/z80.md](docs/notes/z80.md),
[docs/notes/vdp.md](docs/notes/vdp.md), [docs/notes/ym2612.md](docs/notes/ym2612.md) and
[docs/notes/psg.md](docs/notes/psg.md) for the hardware behaviours the fixtures and the test ROMs
revealed.


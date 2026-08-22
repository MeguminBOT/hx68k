# HX68K

Haxe for the Sega Mega Drive / Genesis.

Three parts: a Reflaxe compiler backend that turns Haxe into freestanding C for the 68000, a
hardware SDK, and an emulator with a source-level debugger.

## Status

**Compiler.** Haxe compiles to a real ROM with classes, pooled allocation, sized integers,
fixed-capacity vectors, fixed point, enums as tagged unions, pattern matching as a jump table,
inheritance with vtables only where something is overridden, interfaces as fat pointers, and text
and constant tables that never leave ROM. The ROM boots and runs correctly on an emulated 68000, and
the suite checks the generated C and the map file as well as the running program. 64 checks, 0
failures.

Given a 68000 address, the map tool names the Haxe file, line and function it came from: 116 of 116
probes, none wrong. That chain is what the source-level debugger in track C is for.

The generated code is held to the C written beside it, measured in 68000 cycles on the emulated
machine: 19,582 against 19,586 on an array pass, 9,022 against 9,024 on a pass over linked objects,
and identical on a third.

**Emulator.** A cycle-accurate 68000 validated against SingleStepTests: all 127 opcode groups
implemented, **317,500 of 317,500 tests passing on final state, cycle counts and bus transactions.**
Around it, a machine: the memory map, the VDP as memory and interrupt source, and the master clock.
Both sample ROMs boot on it and reproduce all 68 observables the Musashi harness recorded running
the same ROM. The per-pixel renderer draws planes, window and sprites with their priority order,
checked by seventeen scenarios written from the hardware documentation.

See [docs/68000-NOTES.md](docs/68000-NOTES.md)
for the hardware behaviours the fixtures revealed.

## Test

```
./tests/run.sh
```

Builds both sample ROMs and the headless 68000 harness, boots them, asserts on the results, and
exits nonzero on failure.

## Map a 68000 address back to Haxe

```
cd samples/conformance && ./build.sh debug
cd emulator && haxe map.hxml
neko emulator/bin/map.n samples/conformance/rom/out/debug/rom.out samples/conformance/rom/src 0x000D58
```

With no address it checks every function it recorded; with `--statics` it lists each Haxe static
and the address it landed on.

## Build the spike

```
cd samples/spike
./build.sh
```

Produces `samples/spike/rom/out/rom.bin`. Requires Haxe 4.3+, `reflaxe 4.0.0-beta`, and Java.
The m68k toolchain is vendored with SGDK; nothing else to install.

## Layout

```
compiler/    Reflaxe backend, Haxe -> C99 -> m68k
sdk/         hardware layer and SGDK bindings
samples/     spike, conformance rom
tests/       headless 68000 harness (Musashi-based functional oracle)
emulator/    cycle-accurate cores + SingleStepTests conformance
vendor/      third-party reference sources
docs/
```

## Vendored sources and licences

`vendor/` holds reference material, not dependencies of shipped code. Licences differ and matter:

| Source | Licence | Use |
|---|---|---|
| reflaxe, reflaxe.CPP | MIT | Framework and blueprint |
| SGDK | MIT (gcc GPL3 + runtime exception) | Toolchain and library |
| marsdev | MIT | Non-Windows toolchain builds |
| Musashi | MIT | 68000 core, safe to port |
| superzazu/z80 | MIT | Z80 core, safe to port |
| Nuked-OPN2 | LGPL-2.1 | YM2612; porting makes that module LGPL |
| gwenesis | AGPL-3.0 | **Read-only reference. Do not copy.** |
| Genesis Plus GX | non-commercial | **Read-only reference. Do not copy.** |

# MegaHaxe

Haxe for the Sega Mega Drive / Genesis.

Three parts: a Reflaxe compiler backend that turns Haxe into freestanding C for the 68000, a
hardware SDK, and an emulator with a source-level debugger.

## Status

**Compiler.** Haxe compiles to a real ROM with classes, pooled allocation, sized integers,
fixed-capacity vectors, fixed point, enums as tagged unions and pattern matching as a jump table.
The ROM boots and runs correctly on an emulated 68000, and the suite checks the generated C as well
as the running program. 55 checks, 0 failures.

**Emulator.** A cycle-accurate 68000 validated against SingleStepTests: all 127 opcode groups
implemented, **317,500 of 317,500 tests passing on final state, cycle counts and bus transactions.**

See [docs/68000-NOTES.md](docs/68000-NOTES.md)
for the hardware behaviours the fixtures revealed.

## Test

```
./tests/run.sh
```

Builds both sample ROMs and the headless 68000 harness, boots them, asserts on the results, and
exits nonzero on failure.

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

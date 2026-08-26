# SGDK, and what this repository takes from it

Three questions, answered separately because they have different answers: which of SGDK's own
sources have a Haxe replacement, which of its files a build actually needs, and which of them are
carried only to be read.

SGDK is MIT. Reading it, porting it and copying it with attribution are all permitted, which is
why the first table exists at all.

---

## What has been ported, and into what

`md.hw.*` sits below all of this and has no SGDK counterpart: it is one volatile access per call,
shared by the native side and the bindings and owned by neither. Every binding named here still
exists and still compiles, because a program that prefers SGDK must keep working.

| SGDK source | lines | native Haxe | the binding it moved to | measured against it |
| --- | --- | --- | --- | --- |
| `pal.c` | 484 | `md.Palette` | `md.sgdk.Palette` | 327 cycles a sixteen colour load against 684 |
| `vdp_tile.c` | 1016 | `md.Tilemap`, `md.Patterns` | `md.sgdk.Tilemap` | 164 cycles a cell against 334; a 40 by 28 fill 8544 against 10407; sixteen patterns 3724 against 4106 |
| `vdp_spr.c` | 322 | `md.SpriteTable` | `md.sgdk.SpriteTable` | forty positions and a transfer 4535 a frame against 4716; the transfer alone 2408 against 2733 |
| `dma.c` | 782 | `md.Dma` | `md.sgdk.Dma` | four queued transfers and a flush 4018 a frame against 4737 |
| `psg.c` | 82 | `md.Psg` | `md.sgdk.Psg` | 164 cycles an attenuation and a tone against 170 |
| `ym2612.c` | 175 | `md.Fm` | `md.sgdk.Fm` | 285 cycles a register against 288 |
| `joy.c` | 1361 | `md.Joy` | `md.sgdk.Joy` | 605 cycles for three ports against 2878, and it does less: see below |

**Where a comparison is not like for like, it says so.** `md.Joy` reads three ports as three-button
pads and tells a port with a pad in it from an empty one. `JOY_update` also runs the six-button
protocol, dispatches change events and honours a per-port support setting, so most of that gap is
work not done rather than work done better. It stays that way until an emulator here counts the TH
pulses a six-button pad answers, because until then the extra code is unreachable by any test.

**Not ported, and not going to be.** `sprite_eng.c` at 2256 lines is an engine over the sprite
table, with animation, VRAM allocation and depth sorting. Track E owns all three, so building it
here builds it twice. `md.sgdk.Sprite` binds it in the meantime. `snd/xgm.c` and its driver are the
same case for a different reason: the driver is z80 assembly, and a compiler targeting the 68000 has
nothing to say about it.

---

## Still to port

In the order they should go, with what each waits on.

| SGDK source | lines | waits on |
| --- | --- | --- |
| `sys.c`, `sys_a.s`, `boot/sega.s` | 1052, 74, 365 | nothing, and nothing else on this list matters as much |
| `vdp.c` | 1060 | nothing. Almost every call is one register write |
| `z80_ctrl.c` | 334 | nothing. The driver blobs stay vendored either way |
| `timer.c` | 201 | nothing |
| `sram.c`, `sram_a.s` | 30, 41 | nothing |
| `maths.c` | 878 | its tables, which should be generated rather than carried |
| `string.c` | 720 | nothing, and only the small part of it |
| `mapper.c` | 280 | nothing |
| `vdp_bg.c` | 534 | a font in VRAM and the image structures, so it follows B5 |
| `tools.c`, `tools_a.s` | 1299, 979 | rescomp's compressors, whose output they unpack. The two unpackers are 862 lines of the 979: `aplib_unpack` at lines 118 to 251 and `lz4w_unpack` at 252 to 979, the second hand unrolled. Most of `tools.c` is `KLog` rather than unpacking |

**`memory.c` and `memory_a.s`, 1066 lines between them, are deliberately not on that list.** They
are a heap: `MEM_alloc`, `MEM_free`, a free list and a compactor. `CLAUDE.md` forbids exactly that
on this target, so porting them would import the thing those rules exist to keep out. `md.Pool`
replaces them, and covers `pool.c` at the same time.

---

## Which files a build needs

Measured against what `makefile.gen` and the sample builds actually open. Sizes are of the clone as
`haxelib run hx68k setup` fetches it today, which is 238 MB.

**Needed to build a ROM.** Nothing here can be dropped without breaking the toolchain.

| path | size | what it is |
| --- | --- | --- |
| `bin/` | 96 MB | the m68k toolchain, and the four tools hxres replaced: `rescomp.jar`, `apj.jar`, `lz4w.jar` and `xgmtool.exe`. No build here calls any of them, since every `build.sh` passes `RESCOMP=false`; they are kept because the resource checks compare against them where a JVM is present |
| `lib/libmd.a`, `lib/libgcc.a` | 4.6 MB | the prebuilt library every ROM still links |
| `inc/` | 897 KB | 36 headers. `hx.h` includes `genesis.h`, so the generated C needs them |
| `md.ld` | 4 KB | the linker script |
| `makefile.gen`, `common.mk` | 12 KB | the build the sample scripts drive |
| `src/boot/sega.s` | 365 lines | copied into each build and assembled: the vector table and entry |
| `src/boot/rom_header.c` | | only as the file SGDK copies when one is absent, which ours never is |
| `license.txt`, `COPYING.RUNTIME` | 2 KB | the licence, which travels with the rest |

**Carried only to be read.** Not opened by any build, and worth keeping anyway, because every
hardware claim in `docs/` that came from SGDK came from reading these.

| path | size | note |
| --- | --- | --- |
| `src/*.c`, `src/*.s`, `src/snd/`, `src/ext/` | 3.0 MB | the reference for everything in the tables above |
| `res/` | 83 KB | the default font and the logo. Needed only if a native `drawText` wants that font rather than one of ours |

**Removable, and the reason the fetch is 238 MB.**

| path | size | why it goes |
| --- | --- | --- |
| `.git` | 68 MB | a shallow or sparse fetch never creates it |
| `sample/` | 56 MB | SGDK's own demos. Nothing here builds them |
| `doc/` | 7.6 MB | generated documentation |
| `tools/` | 2.9 MB | the source of what sits in `bin/`: Java for rescomp, apj and lz4w, C for `xgmtool`. All four are ported into `sdk/src/hxres`, and this is what each was read from. Never built here |
| `.github/`, `.vscode/`, `project/`, `CMakeLists.txt`, `build_*.bat`, `makelib.gen` | | building SGDK itself, which this repository never does |

That is **134 MB of 238 removable outright**, and a further 3 MB that could go if the reference
copy were dropped. `bin/` is 96 MB of it and cannot shrink much: `cc1.exe` and `lto1.exe` alone are
47 MB and both are needed. Of `bin/`, `gdb.exe` at 9.4 MB is the one honest candidate, since this
project speaks the gdb remote protocol to whatever gdb a user already has.

**What that means for `setup`.** A sparse checkout of `bin`, `inc`, `lib`, `res`, `src`, `md.ld`,
`makefile.gen`, `common.mk` and the licence, at depth 1, is about 104 MB against 238 and carries
the reference sources with it. Dropping `src` and `res` as well takes it to 101 MB, which is not
worth losing the reference for. The saving is almost entirely `.git`, `sample` and `doc`.

---

## What is never ported

Not judgements about effort. These are not C that a Haxe compiler for the 68000 could replace.

- **`src/snd/*.s80`**, of which `drv_xgm.s80` is 3037 lines: z80 assembly, and the driver a ROM
  uploads into the z80's own memory.
- **`res/image/font_default.png` and the rest of `res/`**: data. Either carried or replaced with
  something of ours.
- **`bin/` and `lib/`**: the toolchain and the prebuilt library. That is the compiler, not the SDK.
- **`tab_sqrt.c`, `tab_log2.c`, `tab_log10.c` at 8201 lines each, `tab_sin.c` at 2058**: lookup
  tables. 26,661 lines that should be generated at build time rather than carried in any form.

## What is not needed at all

`bmp.c` at 1539 lines with `bmp_a.s`, a software bitmap mode that is slow and rarely used;
`maths3D.c` at 480; `sprite_eng_legacy.c` at 2309, which SGDK itself superseded; and all of
`src/ext/`, which is flash carts, FAT16, link cables, serial and a mouse.

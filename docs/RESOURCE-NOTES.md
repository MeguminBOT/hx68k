# Resource pipeline notes

What `hxres` reproduces, and how each behaviour was established. This file exists for the same
reason `68000-NOTES.md` does: a behaviour that no general rule predicts is written down with the
evidence for it, rather than left as a surprising line of code.

The pipeline is held to `rescomp.jar` byte for byte, so several entries here are facts about
rescomp and about the `javax.imageio` PNG reader underneath it rather than facts about a Mega
Drive. Where that is the case it says so, because a number lifted out of another tool is that
tool's answer.

Every entry names the check that holds it. `./sdk/run-resources.sh` runs them all, and reports
skipped rather than passed where there is no JVM to compare against.

---

## PNG decoding

### A palette word is `(b << 8) | (g << 4) | r`, masked with `0x0EEE`

`ImageUtil.getRGBA8888PaletteFromIndColImage` builds each entry as `0xAABBGGRR`, which is byte
reversed from the `0xAARRGGBB` a pixel is, and `convertRGBA8888toRGBA4444` then keeps the high
nibble of each channel. The mask is what the VDP keeps: three bits per channel, in bits 1 to 3 of
each nibble. So a red of `0xB4` reaches CRAM as `0x000A`, not `0x000B`.

Established by decoding `samples/art/gfx/blocks.png` by hand and comparing every entry with
`blocks_palette_data` in rescomp's output.

### The palette is expanded to `1 << bitDepth` entries, not to the PLTE length

A PNG declares its palette in a `PLTE` chunk which may be shorter than the bit depth allows.
`getMapSize()` reports `1 << bitDepth` regardless: 256 for an eight bit image, 16 for four bit, 4
for two bit, 2 for one bit. `Palette` then truncates to `(maxSize + 15) & 0xF0`, which is 64 for a
`PALETTE` resource and 16 for the palette inside a `SPRITE`.

So an eight bit PNG declaring sixteen colours produces a **64 entry** palette, and forty eight of
those entries name a colour no pixel in the image can reference.

### The expansion repeats the last colour for a palette of 2, 4 or 16, and zero fills otherwise

This is the one that no rule predicts, and it is a `javax.imageio` behaviour rather than anything
rescomp chose. Measured across every palette size from 1 to 256 by generating PNGs and reading the
`IndexColorModel` back:

| declared colours | entries past the palette |
| --- | --- |
| 1 | zero |
| 2 | the last colour, repeated |
| 3 | zero |
| 4 | the last colour, repeated |
| 5 to 15 | zero |
| 16 | the last colour, repeated |
| 17 and above | zero |

2, 4 and 16 are exactly the palette sizes that fill a PNG bit depth of 1, 2 and 4. A palette of one
colour does **not** repeat, which the first measurement missed because the fixture's single colour
was black and the two answers are indistinguishable there. The fixture that found it declares one
non-black colour.

`samples/art/gfx/blocks.png` declares sixteen colours, so this rule decides what its palette lines
1, 2 and 3 hold: the brightest colour of the image rather than black. No observable in
`samples/art` reads them, but the picture depends on it.

Held by `Png.EXPANDS_BY_REPEAT` and by twenty four generated fixtures in `hxres.Check`, which cover
palette sizes 1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 32, 64, 65, 200 and 256 at eight bits and 1, 2
and the full size at one, two and four bits.

### rescomp deduplicates identical data blocks

Two resources whose bytes are the same share one label: the `PALETTE` for `blocks.png` and the one
for `diamond.png` both point at `blocks_data`, and palettes declaring 65, 200 and 256 colours all
point at `wide65_data` because they are the same once truncated to 64 entries. Anything comparing
against rescomp's output has to follow the `dc.l` in the resource structure rather than assume a
label named after the resource.

Found by the check reporting three resources missing from rescomp's output that were in fact
present under another name.

---

## The sprite cut

### The order cells reach a solution in comes from a Java HashSet, and it changes the answer

`CellGrid.getSpriteCells` returns `new ArrayList<>(new HashSet<>(...))`, so the cells arrive in
`HashMap` bucket order rather than in grid order. That order survives into the solution: cells are
sorted by tile count with a stable sort, so cells of equal size keep the order they arrived in, and
that decides which merges `optimizeMergeForPart` tries first.

Reproducing it needs three things, all measured against Java rather than assumed:

- **`java.awt.Rectangle.hashCode` is `Rectangle2D`'s**, which converts x, y, width and height to
  IEEE 754 doubles, sums them weighted 1, 37, 43 and 47 as 64 bit integers, and folds the halves
  together with exclusive or. `HashOrder.hash` builds the double bit patterns by hand; twelve
  rectangles pin it.
- **The bucket index is `(capacity - 1) & (h ^ (h >>> 16))`**, and within a bucket the order is
  insertion order.
- **The table doubles for two different reasons, and the second is the one that surprises.** The
  familiar one is size passing three quarters of capacity. The other is `treeifyBin`: when a bucket
  reaches nine entries and the table is smaller than 64, `HashMap` resizes instead of turning the
  bucket into a tree. Eleven of the twelve reference rectangles trigger exactly that, and a model
  with only the load factor rule puts the table at 16 where Java has 32 and gets the order wrong
  from the eleventh cell on.

Established by reading `HashSet.map.table.length` back through reflection at each size, after a
model built on the load factor alone disagreed with Java at eleven and twelve rectangles and agreed
everywhere below.

It is load bearing rather than theoretical. Returning the grid's cells in scan order instead cuts
`bigcross`, `diagonal` and `scatter` differently from rescomp, in the hardware sprites and in the
pattern bytes both.

### The cut is decided in floating point, so the arithmetic has to match

A sprite's score is `8 + tiles * 2.5 + width / 32` for the balanced aim, and a covering's score adds
its own overdraw divided by 3000 and doubles the total above sixteen sprites. Those are doubles,
compared with `<`, and the result is rounded to five decimal places with `Math.round(x * 100000) /
100000`. Haxe's `Float` is the same IEEE 754 double, so the arithmetic carries over unchanged, but
two details do not carry themselves:

- **The rounding is a floor of `x + 0.5`, not a round to even.** `Math.ffloor((x * 100000) + 0.5)`
  reproduces it; `Math.round` would overflow `Int` on a covering with a thousand cells before it
  was optimised down.
- **Ordering ties have to stay stable.** Cells are sorted by tile count descending, and `Cover`
  reorders the same list repeatedly, so equal sized cells keeping their arrival order is what makes
  the arrival order matter at all. `haxe.ds.ArraySort` is a stable merge sort and `Array.sort` is
  not, so the choice is not a preference.

### `removeAll` matches by rectangle, not by identity

`SpriteCell` extends `java.awt.Rectangle`, so its `equals` is value equality, and
`cells.removeAll(covered)` in the merge pass drops **every** cell whose rectangle equals a covered
one rather than the instances it was handed. Removing by identity leaves duplicates behind and the
covering diverges.

### The order the passes run in, and what a solution is compared against

`fastOptimize` alternates two rounds, one measured against the coverage image and one against the
original, and stops after three rounds with no improvement. Each round is merge, reposition, trim,
spread to avoid overdraw, then pull back inside the frame. The best solution seen is kept and
restored at the end rather than the last one produced.

Held by sixteen generated frames in `hxres.Check`, seven of them 64 by 64 so that no single hardware
sprite can cover a frame and the merge actually runs: the cuts come out at four to eight sprites and
26 to 64 patterns, matching rescomp in the frame words and the pattern bytes both.

### Reusing a cut across frames with the same mask is a speedup and nothing else

rescomp scans every sprite frame compiled so far and, where one has the same opaque mask and the
same dimensions, reuses its cut rather than computing a new one. `hxres` does the same.

It was worth checking whether that changes an answer, because a cut carried over from another
resource would be one this could not reproduce by computing. It does not: every step of the cut
reads the image only through "is this pixel non zero", so the result is a function of the mask, the
frame size and the aim, and `hxres` always uses the balanced aim. Disabling the reuse leaves all 220
checks passing with the same cut on every fixture, `samemask`'s four frames included. So it is worth
having for the time it saves on a sheet whose frames repeat a silhouette, and for nothing else.

Established by running the whole check with the reuse branch forced off and comparing.

---

## Binary data

### An odd length blob is padded to a word with zero, whatever the fill value is

`BIN` takes a size alignment and a fill byte, and pads the data up to a multiple of that alignment
with that byte. Then, separately, `Util.outS` appends a single `0x00` if the length is still odd,
under its own comment saying it is better to pad data to a word. So the two paddings answer to
different rules and the second one ignores the fill entirely.

It only shows up where the size alignment is 0 or odd, which is why five of the forty five binary
fixtures failed on it and the other forty did not.

Established by `hxres.Check.binaries`, which compares nine blob sizes against five alignment shapes.

---

## The 68000 unpackers

Measured on `samples/bench`, unpacking the same blob, pinned to logical processors 16 to 23:

| | cycles | against the assembly beside it |
| --- | --- | --- |
| `md.Unpack.lz4w` | 20562 | -0.3% |
| SGDK `lz4w_unpack` | 20628 | |
| `md.Unpack.aplib` | 81044 | -37.6% |
| SGDK `aplib_unpack` | 129954 | |

Both are written as 68000 carried in `@:md.body`. Written in Haxe they were 35534 and 227202, and
what each of them cost is in its own section below, because the two have nothing in common: one is
a dispatch problem and the other is a call overhead problem.

### The dispatch structure is the whole of the lz4w difference

Written in Haxe, `lz4w` came out at 35534 cycles, +72.4%. Nine attempts at closing that from the C
side moved it by under 1% between them: volatile access is worth 5 to 10%, a `"memory"` clobber
nothing, longword literal copies through a C loop are worse, byte wise header reads nothing, a
fused 256 case `switch` in C worse, unrolled chains with a computed entry 0.6%.

The reason none of them reach it is arithmetic rather than code generation. A segment header is
`LLLL MMMM OOOOOOOO`, so a literal copy of L words is followed by a match copy of M+1 words, and
anything that selects the two copies separately pays for two computed jumps. A computed jump on a
68000 is `lea target(pc),a1` at 8, `suba.w` at 8 and `jmp (a1)` at 8, so 24 cycles; a two word
literal copy through `dbra` is 44 cycles and through a computed entry into straight `move.w` is
also 44. The dispatch costs exactly what it saves, and anything paying for two of them plateaus
near 35000.

One dispatch has to serve both copies, which means the pair has to index one table, which means
256 entries. That is why SGDK has 256 of them, and there is no cheaper shape:

- the whole per segment overhead is `moveq`, `moveq`, two `move.b (a0)+`, two `add.w Dn,Dn` and
  `jmp (a3,d0.w)` at 46 cycles, a `bra.w` at 10, and the match preamble `add.w`, `neg.w`,
  `lea -2(a1,d1.w),a2` at 20. 76 cycles, then 10 per literal word and 12 per match word.
- reading the header as one `move.w` saves 12 cycles on the read and loses more than that
  deriving a table index from it: `lsr.w #6` alone is 18.
- a table of 16 bit offsets rather than `bra.w` entries needs `add.w`, `move.w (a3,d0.w),d2` and
  `jmp (a3,d2.w)`, which is 32 cycles, exactly what the `bra.w` table costs.

Literals are copied `move.l` at a time, two words for 20 cycles rather than 24, which is only
available because each literal count has its own entry point in one of two fallthrough chains: an
even one ending in `move.l` and an odd one ending in `move.w`.

### The lz4w table is generated, not transcribed

SGDK writes the table and its chains out: 728 lines. Five gas macros nested two deep produce the
same 3450 bytes from 144 lines, because `.irp` inside `.macro` substitutes both the macro's
parameter and the loop's. The separator matters: `Lliteral\literal\()match\match` works and
`Lliteral\literalmatch\match` does not, since gas reads the parameter name up to the first
character that cannot be in an identifier and `match` is one. Dropping it is an assembler error
rather than a wrong table.

Two things are deliberately not SGDK's. The long match chain is reached through a base held in
`a4` rather than `jmp label(pc,d1.w)`, whose displacement is 8 bit signed and is what forces SGDK
to carry three copies of the same six instruction preamble to stay in range. And a match sourced
from the compressed stream, which the packer here never emits, is a `dbra` loop rather than a
second 128 entry table and its two unrolled chains, which saves about 2 KB for a path no data
reaches.

### aplib spends more than a third of its time in bsr and rts

SGDK's decruncher reads one bit per call to `.get_bit`, and the call is `bsr` at 18 and `rts` at 16
around an `add.b` at 4 and a `bne` at 10. 34 of those 48 cycles are the call. `.decode_gamma` is
called the same way and pays another 34.

Inlined, a bit is `add.b %d3,%d3` and `bne.s`, so 14 cycles, or 24 on the one call in eight that
refills the tag byte. Nothing else about the routine changes: it is the same sentinel bit riding
below the data in `d3`, the same `addx` accumulation through X, the same three offset bands. It
costs 240 bytes rather than 164.

The bench blob's stream holds 1193 bit reads, 182 gamma decodes and 334 literals in 79 runs, and
hoisting the LWM store out of a literal run saves 4 cycles on each literal after a run's first.
34 x 1193 + 34 x 182 + 4 x 255 predicts 47770 cycles saved; 48910 were measured, the difference
being the refill path, which pays the call overhead too. The prediction is what says the reading is
right, rather than that a number moved.

`md.Copy` went with the Haxe version. It existed to give that implementation a byte copy and had no
other caller, and an SDK primitive with no caller and no check is the gap this repository has
already objected to once.

### The fixtures covered 3 of aplib's 11 paths and 16 of lz4w's 256 entries

`data/table.dat` is a 100 byte ramp with no repeats in it. Every segment of its lz4w parse is
`lit=15, mat=0`, one column of one row, and its aplib parse is 100 literals, one code pair and the
ending block: 3 of the 11 paths the decruncher has. Two mutations of the lz4w table survived the
whole gate on it, one widening the odd chain's last copy to a longword and one shortening the long
match chain.

`data/crunch.dat` takes all 11 aplib paths. Its size is set by one of them: the length correction
splits at 128, 1280 and 32000, so reaching the last band needs a match more than 32000 bytes back,
which needs a file longer than that. It is 33379 bytes, most of it a repeated block that packs into
long matches and costs little to unpack, with the crafted cases at either end. Two mutations fail on
it, one dropping the correction in the 1280 to 31999 band and one leaving LWM at 2 after a match.
The first of those is caught by a single occurrence in the whole file, one byte short in 33379.

`data/spread.dat` is built to reach all 256. Literal words are all distinct, so the only matches
are the ones put there deliberately, and each is copied from a distance rather than from the words
just written, because an adjacent copy lets the parser merge two segments into one longer match and
the `mat` column at zero literals then never appears at all. Constructed naively it reached 239 of
256; sourcing matches from a distance took it to 253, and forcing pairs of adjacent matches with
unrelated offsets took it to 256. It also carries long matches of 17, 20, 128, 256 and 257 words,
which are both ends of the 257 entry chain, and an odd byte count so the ending block carries its
trailing byte. Both mutations fail on it.

The coverage was measured by decoding the packed bytes out of the generated `art.c` and tallying
which `(literal, match)` pairs appear, not by reasoning about the parser.

---

## Music

rescomp runs `xgmtool in.vgm out.bin -s` with AUTO timing and wraps the result as
`Bin(align 256, sizeAlign 256, fill 0, no compression, far)`. Because the output extension is not
`.xgm`, xgmtool runs `VGM_create`, four clean-up passes, `XGM_createFromVGM` and then `XGC_create`,
so the port is three stages rather than one.

### xgmtool writes all three intermediate forms, which is what made the port tractable

`in.vgm` to `out.vgm` applies the four passes and stops; to `out.xgm` adds the XGM conversion; to
`out.bin` adds the XGC compilation. That gives an independent byte comparison per stage instead of
one at the end, which is the difference between finding a fault in the stage that caused it and
finding it three stages later. 33 generated tunes are held to all three, which is 99 comparisons.

### A PSG data byte with no latch byte behind it does nothing

`PSG_copy` sets the latched index and type to -1, and `VGM_cleanCommands` copies the PSG state at
the start of every frame. So a frame whose first PSG write is a data byte rather than a latch byte
reaches `psg->registers[-1][-1]`. That is three ints before the struct, and the matching
`psg->init[-1][-1] = true` lands inside `registers[3][1]`, in a byte the `0xF` volume mask throws
away. Nothing the delta reads is touched either way, so the observable answer is that the write
does nothing, and hxres does exactly that. In hxcpp the same indexing is a segfault, which is how
it was found. Two tunes hold it.

### What the corpus was not reaching

Four mutations passed the whole check before the tunes that catch them were written, and each names
a hole worth knowing about:

- **The 15% wait margin.** No tune had a wait landing between `limit - 15%` and `limit - 14%`.
  628 samples for NTSC and 754 for PAL sit in that window.
- **The `0x27` timers mask.** The values written were `0x00` and `0x40`, identical under `0xC0` and
  under `0xE0`. A value with bit 5 set tells them apart.
- **The state change table's base address.** `XGC_getStateChange` walks the release registers at
  0x80 to 0x8E, and the tunes that wrote a spread of YM registers started at 0x30 and stopped at
  0x66. The DAC entry at 0x60 was reached and the twenty four register entries were not, so moving
  the base from 0x44 to 0x45 changed nothing.
- **The sixteen write chunk.** A PSG delta can never exceed twelve commands in a frame, so the PSG
  chunk boundary is unreachable by construction; a YM port delta can, and forty writes in a frame
  reaches it.

A fifth mutation survives and should: `YM2612_set` stores a key write at `registers[port][value & 7]`
and returns whether it changed. Registers 0 to 7 are ones `canIgnore` filters out, so neither `get`
nor the delta ever reads them back, and every caller discards the return value. The store is dead
in the whole conversion path.

---

## What is deliberately not reproduced

Nothing yet. Where a rescomp behaviour is judged wrong rather than merely surprising, the
divergence goes here with the reason and the check is changed to match, in that order.

---

## What is rejected rather than read

- **Adam7 interlaced PNGs.** The error names what to do about it.
- **16 bits per sample.** Same.
- **PNG colour types other than 0, 2, 3, 4 and 6.** There are no others, so this is only reached by
  a corrupt file.
- **Colour at fewer than eight bits per sample**, which PNG does not allow anyway.

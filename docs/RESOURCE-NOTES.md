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

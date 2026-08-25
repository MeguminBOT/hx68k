# VDP behaviour a commercial ROM pinned down

Nothing covers the VDP the way `SingleStepTests` covers the two CPUs, so what is here was
established by running Sonic the Hedgehog 2 on hx68k-emu and looking at what it drew. Each entry
says how it was arrived at, and says so where a figure is inferred rather than measured.

## Where in a line an interrupt is raised

**The horizontal interrupt for a line is raised where that line's active display ends, not where the
line ends.** A line is 3420 master clocks and the display takes 2560 of them in H40, so the counter
is examined 860 clocks before the line boundary, and the line is handed to the renderer at the same
point. A palette the handler writes therefore lands on the line after the one it interrupted, which
is what a handler doing a raster split is written to expect.

**The vertical interrupt is raised at the start of line 224.** That puts 860 master clocks, about
122 cycles of the 68000, between the horizontal interrupt of line 223 and the vertical interrupt
that follows it. The gap is load-bearing.

Sonic 2 shows why. A level with water keeps two palettes, dry and wet, and swaps to the wet one from
the horizontal interrupt handler at the water line. When the water line is off screen the swap is
still armed, with register 10 set to 223 so the handler fires on the last active line where its
effect cannot be seen, and the vertical interrupt handler transfers the dry palette back before the
next frame begins. Raising both interrupts at the same instant inverts that: the 68000 takes level 6
first, the dry transfer happens, and the level 4 still pending behind it then writes the wet palette
over the top, so every line of the next frame is drawn wet. Chemical Plant Zone act 2 comes out
entirely purple and its water line never appears.

860 clocks is enough for the handler at `$000F1C` to reach the `MOVE #$2700,SR` that shuts the
vertical interrupt out. Exception entry for a level 4 autovector is 44 cycles, the four instructions
ahead of the mask are 12, 12, 12 and 10, and the mask itself is 12, which is 102 of the 122
available and leaves about 20 for whatever instruction was in flight when the interrupt arrived.
The margin real hardware allows is inferred rather than measured: what is measured is that Sonic 2
draws its water line correctly with the two interrupts one horizontal blank apart, and incorrectly
with them together.

## The horizontal counter

**Register 10 is reloaded into the counter on every line outside the active display, and the counter
is examined on lines 0 to 224 inclusive.** Holding register 10 at 223 therefore fires the interrupt
once a frame, on line 223, which is how a game parks it rather than disabling it.

## Palettes are read per line, not per frame

The renderer takes its 64 colours from CRAM at the point the line is drawn, so a handler writing
CRAM part way down the screen splits the picture where it wrote. Sonic 2 writes all 64 entries from
a 32 instruction `MOVE.l` run, which is far longer than a horizontal blank and carries on into the
following lines. Hardware shows that as a disturbed row of pixels at the water line. Here the
disturbance is a whole line or two drawn from a half swapped palette, since a line is drawn in one
go from whatever CRAM holds when its display ends.

## Interlace mode 2, which Sonic 2 uses for two players

**Register 12 bits 1 and 2 both set means every vertical measurement doubles.** The picture is 448
lines across two fields, and the parts of the chip that count lines count them in that doubled
space:

- **A pattern is 8 by 16 rather than 8 by 8**, so it takes 64 bytes of VRAM rather than 32 and the
  row within it is four bits rather than three.
- **A plane cell covers 16 of the doubled lines**, so the name table row is the doubled line divided
  by sixteen. A plane 32 cells tall still covers the same picture it did, 512 doubled lines.
- **VSRAM holds doubled values.** Sonic 2's two-player Emerald Hill writes 0x230, which is 280 in
  the units a progressive game would have used.
- **A sprite's vertical position and height are doubled too**, so the bias subtracted from the y
  field is 256 rather than 128, a size of one cell is 16 lines, and the pattern the sprite reads is
  64 bytes a cell like any other.
- **Status bit 4 says which field is being drawn**, set on the odd one. It reads zero whenever the
  mode is off.

Only one field is drawn here, alternating with the frame counter, which is what a display without a
line doubler shows.

**How it was established.** Sonic the Hedgehog 2's attract mode reaches a two-player Emerald Hill
demo about 1,200 frames in, and it sets register 12 to 0x87. Before this the picture came out
striped in vertical bands eight pixels wide, which is the signature of reading 32 bytes a pattern
where the hardware reads 64: even columns showed the top half of one pattern and odd columns the
bottom half of the same one. With the doubling in, the same frames draw two half screens with the
zone title, both characters, the HUD and the parallax, and the frames after it draw the level in
motion. Nothing else in the emulator changed and every other check reads exactly as it did.

**What is still not modelled.** Interlace mode 1, register 12 bit 1 alone, which doubles nothing and
only interlaces the two fields. No ROM here uses it.

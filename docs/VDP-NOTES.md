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

## The port, as Nemesis' test ROM has it

`vendor/VDPFIFOTesting/VDPFIFOTesting.bin` is fifteen suites of VDP port access, and
`emulator/fifo.hxml` reports each one's result row. Everything below was arrived at the same way:
take the rule from Charles MacDonald's `genvdp.txt`, put it in, and keep it only where the ROM's
number went up. Where the document and the ROM disagree the ROM wins, and the disagreements are
written out here because the document is the one most people will read.

**A VRAM write byteswaps when the address is odd.** The high half of the word goes to the odd byte
and the low half to the even one. `genvdp.txt` says this plainly and the ROM agrees: suite 7 went
from 42.5% of its row to 73.3%, and the pages went 42.5% to 44.9% and 72.9% to 74.1%.

**A VRAM read does not byteswap.** The mirror of the write rule looks obvious and is wrong: applying
it to a read took suite 7 back down from 73.3% to 50%.

**The 8-bit VRAM read target, code 1100, returns the byte at the address in the high half and the
adjacent byte in the low half.** So it is the write rule read back. Reading it as an ordinary word
gives 43.9%, duplicating the byte into both halves gives 2.6%, and this gives 53.4%, from 0% when
the code was not decoded at all. `genvdp.txt` predates this target and does not mention it.

**Writing a register clears only the low two bits of the code register.** `genvdp.txt` says a
register write "will clear the code register", and Golden Axe II and Sonic 3D are named as games
that depend on it. Clearing all six bits takes suite 13 from 67.5% down to 58.7%; clearing CD1 and
CD0 and leaving CD5 to CD2 takes it up to 84.1%. Latching bits 15 and 14 of the word into CD1-CD0
as well, or latching the address with them, changes nothing this ROM can see, so the narrower claim
is the one made.

**A VRAM fill writes the initial word and then as many bytes as the length register says, not one
fewer.** Suite 4 went from 90% to 93.3%. `genvdp.txt`'s pseudocode writes only the low byte of the
initial word rather than a whole word through the normal write path, which scores 87.3%, so the
first write is an ordinary FIFO write and the fill engine follows it.

**A CRAM or VSRAM read returns the bits it does not store from the last word written to VRAM.**
CRAM keeps nine bits at 0EEEh and VSRAM eleven at 07FFh; the rest come from a latch. Which writes
fill that latch is the part worth writing down, because it was measured rather than assumed:

| what fills the latch | total result pixels passing |
| --- | --- |
| nothing | 5,653 |
| every data port write | 5,968 |
| VRAM writes only, CRAM reads exposing it | 6,078 |
| VRAM writes only, CRAM and VSRAM reads exposing it | 6,418 |
| VRAM and CRAM writes | 5,968 |
| VRAM and VSRAM writes | 6,078 |

A CRAM write does not fill it and neither does a VSRAM write. Only a VRAM write does, which is what
a FIFO holding what is on its way to video memory would do. Filling it from every write costs suites
8 and 9, the two that test CRAM and VSRAM directly, which is how the narrower rule was found. What
CRAM and VSRAM keep of the word they are given makes no difference once the read exposes the latch,
so the store masks are left as they are.

**The oracle had to be taught it too.** `samples/hardware` writes 0E80h to colour 0, writes 1234h to
VRAM, then reads colour 0 back through the port. With the latch that read returns 1E90h, and the
Musashi harness still answered 0E80h, so the two emulators disagreed and the gate said so. The
harness now holds the same latch, and the check that used to be called "colour 0 through the port"
is called "colour 0 read back over the last VRAM write", because that is what it measures. What the
CRAM cell itself holds is checked separately and is still 0E80h.

**In mode 4 the registers above 10 cannot be written.** Register 1 bit 2 chooses between the Master
System's mode 4 and the Mega Drive's mode 5, and `genvdp.txt` says that in mode 4 "none of the
registers which normally affect the Genesis work". Refusing a write to register 11 and above while
that bit is clear takes suite 12 from 79.6% to 100% and nothing else moves. Refusing a write above
register 23, which the same document also describes, changes nothing this ROM can see, so it is not
claimed.

It also caught a fault in this repository's own tests. `RenderCheck` and `ViewCheck` set the VDP up
through its ports and both wrote 40h to register 1: display on, and mode 4, which no Mega Drive
program does. Every register they set after that was legally ignored and five render checks and the
whole view suite failed. They write 44h now, display on and mode 5, and pass with exactly the
expectations they had before.

## The FIFO, and why there is not one yet

A write FIFO was built and then taken out again, which is worth writing down so the next attempt
starts from the measurement rather than from the same idea.

**What was built.** Four entries, each holding the code, the address and the word; the data port
pushes and the address register increments at the push; `tick` drains one entry per external access
slot, spread evenly over the line at 18 slots in H40, 16 in H32 and 167 while blanked; a push onto a
full FIFO holds the bus until the next slot, which the machine charges to the write; and status bit
9 says empty and bit 8 says full from the count rather than from a constant.

**What it did.** Nothing. The test ROM fills it to 3 of its 4 entries and never overflows, the bus
is never held for a single clock, Sonic 2 is byte for byte the same over 1,300 frames, and the
result rows do not move: 6,552 passing pixels with the FIFO and 6,552 without. An evenly spread
slot every 190 master clocks is faster than a 68000 can write, so the FIFO is never the thing that
is waiting.

**What making it slower did.** A VRAM entry taking two slots rather than one is the obvious
refinement, since VRAM is byte wide and a word costs two accesses. It does produce stalls, 1,314
master clocks over the run, and it takes suite 1 from 36.9% to 39.8% and suite 15 from 54.3% to
60.4%. It also takes suites 11 and 12 from 100% to 62.5% and the total from 6,552 down to 6,090.
Slowing the blanked rate as well makes it worse again, 5,918 and 5,936.

### Where the external access slots are

Nemesis published the whole line as two hand-drawn timing diagrams, `VDP VRAM timing H32` and
`VDP VRAM timing H40`, at `nemesis.hacking-cult.org/MegaDrive/Documentation/VDP/`. They are images
rather than text, and what they say is this.

A line is a run of **access slots**, each four serial clock cycles long: **210 of them in H40** and
**171 in H32**, so a slot is 3420/210 master clocks in H40 and 3420/171 in H32. Each slot is used
for one of the hscroll fetch, a layer A or B mapping or pattern fetch, a sprite mapping or pattern
fetch, a refresh cycle, or an **external access**, which is the one the 68000 and DMA get.

While the display is on and the line is an active one:

| | H40 | H32 |
| --- | --- | --- |
| slots in the line | 210 | 171 |
| the preamble, slots 1 to 13 | none external | none external |
| the repeating block, 32 slots from slot 14 | external at 15, 23 and 31; refresh at 39 | the same |
| how many times it repeats | 5, reaching slot 173 | 4, reaching slot 141 |
| the tail | external at 174, 175 and 199 | external at 142, 143, 157 and 171 |
| external slots in the line | **18** | **16** |
| refresh cycles in the line | **5** | **4** |

While the display is off, or on a line outside the active display, every slot is an external access
except the refresh cycles, which stay where they are. That gives **205** in H40 and **167** in H32,
and those two figures are the check: they are what the documentation states independently, and they
fall out of the positions above exactly. The other check is the gap: the widest run with no external
slot in it is from slot 199 to slot 15 of the next line, which is 26 slots, and 26 is the figure
measured off a logic analyser on the VRAM bus.

**And it was tried again with better numbers.** The blanked figure of 167 is the H32 one; H40 has
205 external slots and 5 refresh slots against H32's 167 and 4. Splitting the two, so the rate
follows the width, changes nothing at all: 6,090 again with the two-slot rule and 6,552 without, to
the pixel. Halving the active-display slots to 9 and 8 raises suite 4 to 93.3% and suite 5 to 70.5%
and still leaves the total at 6,142, below no FIFO at all, and suite 12 back at 62.5%.

**And a third time, with the positions above rather than a rate.** It makes no difference: 6,552
with one slot per entry, which is the figure with no FIFO at all and no stall ever taken, and 5,974
with a VRAM entry costing two, with the same three register-write suites falling to 62.5%, 62.5%
and 83.6%. Reading the pages back shows what those three do: their first several cells turn red
together and the rest stay green, which is a run of tests failing at the start of each suite rather
than tests failing throughout.

**What that says, and it is not what it looked like.** The stall was the suspect and the stall is
innocent. Keeping the whole model, stall and all, and *also* landing each write immediately so the
FIFO only delays nothing, puts page two back to 86.8% with all three suites at 100% and takes page
one slightly up, from 60.9% to 61.4%. So the timing of the hold is fine and what breaks those
suites is a write not having landed when the ROM reads it back.

That narrows the whole thing to one question: **how many external access slots does a VRAM word
write consume?** At two it is 9 words per active line, the FIFO stalls, and writes are still in
flight when the ROM looks for them. At one it is 18 words per active line, and the FIFO never fills
and never stalls, so the entire mechanism is inert and nothing moves. Neither is an improvement, so
there is still no FIFO here.

The reading that fits the diagram is one: a column in it is one access slot of four serial clock
cycles, a layer pattern fetch takes two columns and an external access takes one, so the external
column is already a whole word access. The "a VRAM access costs two slots" figure that appears in
the secondary sources must be counting something below that, and the way to settle it is the ROM's
own suite 1, which is called FIFO Buffer Size and is at 36.9%. Getting that one to move is the next
piece of work, and it now has the positions to work from.

**Where this stands.** Page one is 60.9% of its result rows and page two 83.2%, from 42.5% and
72.9% when the ROM arrived. By the ROM's own count page one now passes **1 of its 9** suites, up
from none: suite 2, the separate read and write buffers. On page two suite 13, register writes
against the code register, is at 100% and suite 14, the pending flag's reset, at 92.8%.

**Three suites went down for it and are written here rather than hidden**: the VRAM fill from 93.3%
to 82.3%, VRAM byteswapping from 73.3% to 66.3%, and partial control port writes from 85.2% to
74.8%. All three read back through CRAM or VSRAM, so what they are saying is that the latch is not
the last VRAM write but the FIFO's own next entry, which differs from it exactly while a fill or a
multi-word write is in flight. That is the FIFO, and it is the next piece.

What is left is mostly the FIFO itself: suites 1, 3 and 5 are the buffer's size, DMA through it, and
what a write to an invalid target does, and none of those can be right before the VDP costs the
68000 anything.

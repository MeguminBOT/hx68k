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

**The Musashi harness had to be taught it too.** `samples/hardware` writes 0E80h to colour 0, writes 1234h to
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

### The FIFO, as it is now

**A VRAM word write costs one external access slot, not two**, and the diagram says so directly: a
column in it is one word access, a layer pattern fetch is drawn two columns wide because a pattern
row is two words, and an external access slot is drawn one column wide. The "a VRAM access costs
two slots" figure in the secondary sources is counting the two bytes that one column already
covers. Charging two is what made three earlier attempts worse.

So the FIFO is in, at one slot a word: four entries, drained at the slot positions above, and a
push onto a full one holds the bus until the next external slot, which `Machine.write` charges to
the 68000. Status bit 9 says empty and bit 8 says full from the count rather than from a constant.

**It changes nothing either ROM here does**, and that is the expected answer rather than a
disappointment: both write to VRAM during blanking, where 205 external slots a line is faster than
a 68000 can fill four entries. The FIFO is what a program writing to VRAM *during active display*
runs into, which is 18 slots a line, and neither Sonic 2 nor the port access ROM does that in a
burst long enough to matter. VDPFIFOTesting reads 60.9% and 86.8% with it and without it, the four
frames of Sonic 2 are the same four frames, and the 240p patterns are the same seven.

**It is not dormant code, because `emulator/slot.hxml` drives it.** `hx68k.test.SlotCheck` sets a
VDP up through its own ports with no ROM anywhere and asserts what the diagram says: 18 external
slots on an active H40 line, 16 on H32, 205 and 167 blanked, four words accepted with the bus never
held and the fifth held for less than a line, sixty-four words accepted without a hold while the
display is off, and everything queued landed in VRAM within one line. Seventeen checks. Three
deliberate mutations, dropping an external slot from the repeating block, dropping one from the
tail, and dropping the refresh cycle, were confirmed to fail the right ones first.

**One thing the check found in the model.** The diagram numbers access slots from 1, and the drain
was numbering from 0, so a blanked line offered 206 external slots instead of 205. The census in
the check is what caught it.

**And one thing it found in this repository's own tests.** `RenderCheck` and `ViewCheck` set a VDP
up through its ports and then read it back with no time passing at all, so with a FIFO in the way
every write was still queued and eleven render checks and the whole view suite failed. Their write
helper now ticks the VDP until the queue is empty, which is what any program on the machine
experiences, and both pass with the expectations they already had. A VDP write taking time to land
is the behaviour, not a nuisance; a scenario that assumed otherwise was assuming something no
Mega Drive does.

## The sprite masking ROM, all nine tests in both widths

`vendor/SpriteMaskingTest/sprites.bin` is Nemesis' Sprite Masking and Overflow Test ROM, 2008,
fetched by `haxelib run hx68k setup` from the Internet Archive. It reads nothing back from the VDP
and it has no read path to the picture: **each result is a tick and a cross drawn over each other,
and the sprite masking under test is what hides one of them.** That is why it is a measurement of a
renderer rather than a message from the ROM, and why the check reads its result rows off the
framebuffer.

It said three of its nine tests were wrong in both widths and a fourth in H32. Four rules fixed
them, in this order, and each one was measured before the next went in:

| what went in | H32 rows left red | H40 rows left red |
| --- | --- | --- |
| nothing, as it was | 3, 5, 6, 9 | 3, 5, 6 |
| a link past the end of the table stops the scan | 3, 5, 6 | 3, 5, 6 |
| a mask needs the sprite read before it to have x above zero | 3, 6 | 3, 6 |
| the dot limit cuts a sprite rather than letting it finish | 6 | 6 |
| a masked sprite still spends its width from the dot budget | none | none |

**A link field past the end of the sprite table ends the scan.** The table holds 64 entries in H32
and 80 in H40, and a link to anything at or above that stops the walk where before it wrapped and
read whatever was there. That is the whole of test 9, which failed in H32 and passed in H40 for
exactly that reason.

**A mask is a sprite at x=0 whose immediately preceding sprite on the line had x above zero.** Not
"at least one sprite has been drawn", which is the reading that sounds the same and fails test 5:
the flag is about the sprite read before this one, so a mask straight after another mask does
nothing, and a mask that is the first sprite on its line does nothing. The flag starts each line
seeded from whether the previous line overflowed, which is what makes a first-sprite mask work
after an overflow, and that is test 6.

**The dot limit cuts a sprite in the middle.** H40 gives 320 sprite pixels a line and H32 gives
256, and a sprite that starts inside the budget and runs past it is drawn up to the budget and no
further, rather than being drawn whole or dropped. Test 3, the complex dot limit, is that and
nothing else.

**A masked sprite still spends its width.** Masking stops pixels being written; it does not stop
the VDP walking the sprites it picked for the line, and each of them takes its width out of the
budget on the way past. Without that a line that should overflow does not, and the mask on the
line after it does not fire, which is test 6 again from the other side.

**Two status bits went in with them**, both documented and neither reached by this ROM: bit 6, set
when a line has more sprites or more sprite pixels than it can take, and bit 5, set when two
sprites put a non-transparent pixel on the same place. Both are cleared by reading the status.

Fifteen scenarios in `hx68k.test.RenderCheck` hold all of it headlessly, so the rules do not rest on
one ROM: a mask after a sprite, a mask first on the line, a mask after a mask, the pixel either side
of the dot limit, both status bits and their clearing on read, and a link to entry 70 followed in
H40 and refused in H32.

## A drain stops at the line's own last slot

`drain()` turns the dot counter into a slot number, and it used to do that without holding the
answer to the line it was on. A tick that carried the dot past the end of a line therefore served
slots belonging to the next one, and `endOfLine()` then reset the count under it. The slots were
not borrowed from the next line, they were created: nothing deducted them.

Measured over ten blanked H40 lines, ticked in bus cycles of 28 master clocks rather than one at a
time, which is what the machine does:

| | with the overshoot | held to the line | what ten lines allow |
| --- | --- | --- | --- |
| VRAM fill | 2053 | 2049 | 204 then 205 nine times |
| 68K to VDP | 2054 | 2050 | 205 ten times |
| VRAM copy | 1027 | 1025 | a byte every second slot |

About a fifth of a percent fast, which no ROM here draws differently for: Sonic 2 reaches the same
seven frames and the port access ROM stays at 100% on both pages. It shows up only when something
counts the slots, which `hx68k.debug.Slots` now does. Ticking one master clock at a time never
reaches it, because the dot then never overshoots a line end by more than one clock, so the check
that holds it ticks in bus cycles.

The drain runs a second time straight after `events()` has rolled the line, so the part of a tick
that belongs to the new line is served on that tick rather than the next one.

## Why the documented fill rates are one below the transfer rates

Sega's table gives 205, 18, 167 and 16 words a line for a 68000 to VDP transfer and 204, 17, 166
and 15 bytes for a VRAM fill, one less in every one of the four widths. That is not a slower rate.
A fill is started by a write to the data port and that write takes an access slot of its own, so
the line the fill starts on has one fewer slot left for it; the second line of the same fill
carries 205. A copy is started by a control port write, takes no such slot, and comes out at
floor(205 / 2) because it reads before it writes.

All twelve rates are now held exactly rather than to five either way, and the fill's first line is
held to 204 with the run of lines after it held to 205 each.

## The HV counter stops, and what stops it

Register 0's M3 bit, value 02h, is documented as "HV. Counter stop", and the prose beside it says
the counter "will freeze when trigger signal HL goes high, as well as triggering a level 2
interrupt". So M3 arms rather than freezes: with it set, the next rise of HL captures the counter,
and every read after that returns what was captured until M3 is cleared again.

The external interrupt is level 2, autovectored like the other two, and enabled by IE2, which is
register 11 bit 3. The overview says it "is generated by a peripheral device (gun, modem) and stops
the counter for later examination by the CPU".

**What drives HL is TH on a controller port, and SGDK is what establishes it.** The overview names
the peripheral but never the pin. SGDK sets a light gun port up by writing 30h to its control
register, which leaves bit 6, TH, an input for the peripheral to pull, where a pad port drives TH
as an output to strobe the pad. So with no gun plugged in, TH sits high on its pull-up and never
transitions, and nothing latches. A program driving TH as an output does produce edges, which is
real: it is why a game leaves M3 clear while it reads pads.

**HL is an edge and not a level.** Writing the same high value to the port again is not a second
trigger. Nothing in the first draft of the checks said so, and a mutation that took the level
instead of the rise passed all of them, which is how the gap was found rather than by reading it
back.

The interrupt is raised on the rise whether or not M3 is set, and IE2 alone decides whether the
68000 sees it. The documented sentence ties the freeze and the interrupt together under M3, so the
other reading is that M3 gates both; nothing here can tell the two apart, since no ROM in this
repository enables IE2, and this is the reading that keeps the two register bits doing the one job
each is named for.

## What the 68000 waits when the FIFO fills, and one number that does not agree

Sega's overview gives the longest a program can be held when it writes in a tight loop during
active display: **5.96 microseconds in H32 and 4.77 in H40**, both marked approximate. Those are
checkable against the slot table directly, without going near the stall path, by walking the table
and taking the widest gap between two external slots.

**H32 matches exactly.** An active H32 line has sixteen external slots and the widest gap between
two of them is sixteen slot positions, which at 3420 master clocks over 171 positions is 320 clocks,
which is 5.96 microseconds. Every part of that line, tail included, is inside the figure.

**H40 matches in its body and not in its tail.** An active H40 line has eighteen external slots. In
the body, below position 174, the widest gap is sixteen positions, which is 4.85 microseconds
against the documented 4.77, inside the rounding of an approximate figure. In the tail there is a
gap of **24 positions between slots 175 and 199**, which is 7.28 microseconds, half as long again as
the documented maximum.

One of the two is wrong and nothing here settles it. The tail positions come from Nemesis' timing
diagrams, and the port access ROM passes all fifteen of its suites with them, so they are not
changed on the strength of a figure the same document calls approximate. Both numbers are held by
checks so neither can drift quietly, and this paragraph is the reason the 24 is written down as an
expectation rather than as a target.

**A real fault came out of looking.** `until()`, which works out how long a full FIFO holds the bus,
wrapped its slot index with `index >= total` where slot indices run from 1 to total rather than from
0. Slot 171 in H32, which is an external slot, therefore wrapped to slot 0, which is not, and the
wait ran on into the next line. Measured on a tight write loop, the longest stall was 524 master
clocks where the table allows 320; with the wrap fixed it is 264. No ROM here writes to the VDP
during active display, so nothing the gate draws moved.

**The write waits before it is queued, not after.** A full FIFO used to pop an entry inside `push`
to make room, and the drain then served the same slot again when the stall was handed back to the
machine, so the queue emptied at up to twice the rate the slots allow. `Machine.write` now asks the
VDP how long it is held, spends that time, and only then stores: the drain frees the entry during
the wait, exactly as a slot does on the hardware, and nothing pops twice. `Vdp.holdFor` is the
question and `writeData` no longer answers with a duration.

With that, the stall the 68000 takes is the slot table's own gap, to the clock:

| | widest gap | in master clocks | the bus is held | plus the write's own four cycles |
| --- | --- | --- | --- | --- |
| H32 | 16 slots | 320 | 292 | 320 |
| H40 | 26 slots | 423 | 395 | 423 |

The four cycles are the write's bus cycle, which the CPU spends before it can be held at all, so a
program in a tight loop sees the gap less the work it already did. H32's 320 is Sega's 5.96
microseconds exactly.

The port access ROM passes all fifteen suites through the reordering, which is the thing that had to
be true: its first suite is the FIFO buffer size and its third is a transfer through the FIFO, and
what a CRAM or VSRAM read exposes depends on which slot the next write will use.

## The vertical counter in PAL, and under interlace

**PAL has its own endpoints, and the NTSC pair is provably wrong for it rather than merely
unchecked.** A counter walk over a 313 line frame with NTSC's endpoints ends at 50 instead of 255,
which is not a matter of opinion. The pair here is **102h last, 1CAh resume**, inferred rather than
read off a document, and this is the reasoning:

- the frame is 313 lines, established from the vertical blanking table two sections up
- a walk has to start at 0, end at FFh, and jump exactly once, which is what the NTSC pair is held
  to and what a counter that reads a 9 bit position through 8 bits does
- (102h + 1) + (200h - 1CAh) is 259 + 54, which is 313
- SGDK's blank rollback adjustment tests the PAL counter against CAh, where it tests NTSC's against
  DFh, a little below its E5h resume. CAh is the resume above, read back the same way

That is corroboration and arithmetic, not a measurement, so it is marked inferred. What it produces
is a counter that reads 0 to FFh, then 0, 1, 2 again, then CAh to FFh: 313 readings, the last of
them FFh.

**Under interlace the counter loses its lowest bit and gains the ninth.** Sega's overview: "During
interlace mode, the LSB of the vertical position is replaced by the new MSB." The new MSB exists
because interlace doubles the vertical position, a field covering every other line of a frame twice
as tall, so the position needs nine bits where the counter has eight.

The first attempt here got it wrong in a way worth recording, because the mistake is easy: this
model already carries a ninth bit, the one that tells the blanking tail from the visible part, and
that is not the bit the sentence means. Taking that one gave 132 readings a frame where there should
be 262. The right position is the count doubled, so the reading is `((c << 1) & FEh) | (c >> 7)`,
which is a bijection on 0 to 255: the lower half of the count comes back doubled and even, the upper
half comes back odd. 262 readings, first 0, last FFh, exactly as without interlace.

Sonic 2's two player mode is interlace mode 2 and its frames at 1302 and 2000 are unchanged by it,
so nothing it draws depends on reading the counter there.

## The two television standards, and how 313 was settled

| | lines a frame | processor clock | master clock | frames a second |
| --- | --- | --- | --- | --- |
| NTSC | 262 | 7.67 MHz | 53693175 | 59.92 |
| PAL | 313 | 7.60 MHz | 53203424 | 49.70 |

Both rates are 3420 master clocks a line divided into the master clock, and `SlotCheck` holds each
to the hundredth.

**313 rather than 312, which is what SGDK's `VDP_getScanlineNumber` returns.** Sega's own overview
tallies the vertical blanking, in a table it uses for working out how much a DMA can move:

| display mode | lines of vertical blanking |
| --- | --- |
| V28 NTSC | 36 |
| V28 PAL | 87 |
| V30 PAL | 71 |

Against 262 for NTSC and 313 for PAL, each of those is exactly two short of the whole frame less
the active lines: 262 - 224 - 2, 313 - 224 - 2, 313 - 240 - 2. Three rows agreeing on one offset of
two, which is the vertical sync where no transfer is possible. 312 fits none of the three. SGDK's
number is used only for a frame load percentage, where a line either way does not show.

The same document gives the PAL processor clock as 7.60 MHz against NTSC's 7.67, which is the
53203424 above, and describes V30 as a PAL mode that software leaves off under NTSC. The bit is
honoured whichever standard is running, because that is what the hardware does with it rather than
what the documentation advises.

## Which standard a cartridge asks for

The machine reads the region field, sixteen bytes at 1F0h, once when the ROM loads, and never looks
again. **A header naming Europe and nowhere else is PAL; everything else is NTSC.** `E`, or `8` in
the numeric form, means Europe; `J`, `U`, `1` and `4` mean somewhere that is not. Most commercial
cartridges say `JUE` and are therefore NTSC here, which is what keeps Sonic 2 drawing the frames it
always drew.

This is a rule rather than a detection, and it is written down because the header cannot answer the
question properly: it says which market the cartridge was sold into, not which console it is
plugged into. A PAL cartridge in an NTSC machine runs a fifth too fast on real hardware, and
nothing in the header would say so.

## The active display ends where the height register says

V28 is 224 lines and V30 is 240, and Sega's overview gives the active counter ranges as 0 to DFh
and 0 to EFh, which are those two numbers. The vertical blanking flag, the vertical interrupt, the
render gate and the horizontal interrupt counter all turn at that line.

They did not, once. The renderer read the height register and drew 240 lines in V30 while the rest
of the VDP kept turning at 224, so a program setting V30 got its vertical interrupt sixteen lines
early and a blanking flag that disagreed with its own picture. Four checks in `SlotCheck` walk to
the line where the flag first sets and where the interrupt first fires, in both heights.

## The three interlace settings, and why only one of them changes the picture

Register 12 holds a three-way setting rather than a flag: bits 2 and 1 are 00 for progressive, 01
for interlace mode 1, 11 for interlace mode 2. 10 is prohibited and is treated as progressive here.

**Mode 2 doubles every vertical measurement**: 8 by 16 patterns of 64 bytes, a plane cell covering
sixteen of the doubled lines, VSRAM read in doubled units, sprites biased by 256 and sized in
doubled lines. **Mode 1 doubles nothing.** It renders exactly what a progressive frame renders and
differs only in that the two fields are offset by half a scanline on the television, which a
framebuffer does not have. So in this emulator the whole of mode 1 is one thing: the odd field is
reported in status bit 4, alternating with the frame, where before that bit only moved in mode 2.

That is why `Vdp.doubled()` is named for what it asks rather than being called `interlaced()`. Two
questions were being answered by one boolean: whether the fields alternate, which both modes do,
and whether the geometry doubles, which only mode 2 does.

**Still not modelled, with the documentation for it written down here rather than guessed at.** Sega's
overview says that during interlace "the LSB of the vertical position is replaced by the new MSB",
the counter having eight bits where interlace needs nine. Reproducing that needs the doubled
vertical position as a counter, and this model keeps `line` undoubled and doubles inside the
renderer instead, so there is no ninth bit to promote. Nothing here reads the vertical counter
during interlace, so there is nothing that would say whether a guess at it was right.

## The horizontal counter has a range for each width

The counter is not a pixel count: it counts once every two pixels and it skips a stretch in the
middle of the blanking, so what a program reads jumps once a line. Both widths have their own pair
of endpoints, and only H40's was modelled:

| | counts up to | resumes at | counts a line |
| --- | --- | --- | --- |
| H40 | B6h | E4h | 211 |
| H32 | 93h | E9h | 171 |

The vertical counter does the same once a frame, counting to EAh and resuming at E5h, which is 262
lines of NTSC. `hx68k.test.SlotCheck` walks a whole line of master clocks for each width, and a
whole frame of them for the vertical one, holding each counter to starting at zero, ending at FFh,
taking as many counts as the line or the frame has, and jumping exactly once, from and to the values
above. Moving the vertical resume one count fails four of those.

**Still not modelled, and written here rather than guessed at.** The read prefetch, where the VDP
fetches the word at the read address before a program asks for it and a data port read returns that
buffer rather than memory; and what the vertical counter reads in interlace mode 2, where the line
count needs nine bits and the counter has eight. The port access ROM passes every suite without
either, so there is nothing here that would say whether a guess at them was right.

## The port access ROM, all fifteen suites

Nemesis' VDP Port Access Test ROM reads **100% on both pages**, 9 of 9 by its own count on page one
and 6 of 6 on page two, from 60.9% and 86.9% and 1 of 9. Three changes did it, and each of them is
one sentence of hardware that everything else follows from.

### Reading CRAM or VSRAM exposes the FIFO slot the next write will use

The bits CRAM and VSRAM do not store, nine of sixteen and eleven of sixteen, come from the VDP's
write FIFO: specifically the data field of **the slot the next write will go into**, which still
holds whatever was written into it four writes ago, because nothing clears an entry when it is
popped. Not the last write, not the entry at the head, not a separate latch.

That one sentence took seven of page one's nine suites to 100% in a single change:

| suite | before | after |
| --- | --- | --- |
| 1, FIFO Buffer Size | 36.9% | 100% |
| 4, DMA Fill FIFO Usage | 82.3% | 100% |
| 5, FIFO Write to invalid target | 55.2% | 100% |
| 7, VRAM Byteswapping | 66.3% | 100% |
| 8, CRAM Byteswapping | 53% | 100% |
| 9, VSRAM Byteswapping | 55.2% | 100% |
| page 2, all six | 86.9% | 100% |

**The variants that were tried and are wrong** are worth keeping, because each is the obvious
reading of the same sentence: a latch filled on every commit rather than on every push gives page
one 59.2%; filled on push, VRAM writes only, 59.4%; filled on push, any target, 59.7%; the head of
the queue, 60.8%; the entry most recently pushed, 60.9%. Every one of them is at or below where it
started. The slot the next write will use is 87.5%, and nothing else is close.

Every write to the data port takes a slot, whatever its target and whether or not the target is
valid, which is why suite 5 moves with the rest. It follows from the FIFO being in front of the
target rather than behind it.

### A 68000 to VDP transfer goes through the FIFO like any other write

Suite 3, DMA Transfer using FIFO, is named after the thing it tests, and it sat at 49.3% and then
37.5% while a transfer wrote straight to video memory. A transfer reads a word over the 68000's
bus and pushes it into the same four entry FIFO; the FIFO drains one entry an external access slot.
The read costs no slot of its own, so the rate is unchanged at one word a slot, and the FIFO sits
full for the length of the transfer. **Suite 3 went to 100%.**

Two consequences fall out of it and both are what hardware does. The length register counts words
read into the FIFO rather than words written to video memory, so it reaches zero four words early
and the 68000 is released with four still in flight. And a CRAM read during a transfer exposes what
the transfer is carrying, which is exactly what suite 3 is looking at.

### An 8-bit VRAM read returns one byte and the FIFO's high byte over it

Read target 0Ch returns the byte at the address with bit 0 inverted, in the low half, and the high
half comes from the same exposed FIFO slot. Suite 6, 8-bit VRAM Read target 0100b, was at 53.4%
under every earlier reading and goes to **100%** with this one. The byte at the address without the
inversion gives 52.9%, and putting the FIFO in the low half instead gives 5.5% and 2.9%, so the
suite separates the four sharply.

### A fill takes a slot a byte, a copy takes two, and neither freezes the 68000

The VRAM fill and the VRAM copy were the last two things in this VDP that happened in no time at
all. They now run on the same external access slot schedule the write FIFO and the 68000 to VDP
transfer run on, and the twelve rates that come out are the twelve the Sega documentation gives,
none of them written into the model:

| | H32 active | H32 blanked | H40 active | H40 blanked |
| --- | --- | --- | --- | --- |
| 68000 to VDP | 16 | 167 | 18 | 205 |
| VRAM fill | 15 | 166 | 17 | 204 |
| VRAM copy | 8 | 83 | 9 | 102 |

The three rows differ for reasons rather than by adjustment. A transfer is one word an external
slot. A fill is one byte an external slot, and it is one behind the transfer on every line because
the data port write that starts it is an ordinary FIFO write and takes the first slot itself. A
copy is one byte every two slots, because it reads a byte from video memory and then writes it,
and each of those is an access.

**A transfer freezes the 68000 and a fill or a copy does not.** A transfer reads its source over
the 68000's own bus, so the VDP takes that bus for the length of it. A fill and a copy read nothing
outside the VDP, so the 68000 keeps running, and the way a program waits for one is
**status bit 1**, which is set while any of the three is in flight. SGDK relies on exactly that:
`VDP_waitDMACompletion` is `while (GET_VDP_STATUS(VDP_DMABUSY_FLAG));` and `VDP_init` calls it
after clearing all 64 KB of video memory, which at 205 bytes a blanked line takes 320 lines.

**What it did to Sonic 2, which is the only thing here that fills at all.** Fourteen fills over
1300 frames, 176,306 bytes between them, and no copies. Four of those are large enough to cost a
frame or more: 65,535 bytes twice during boot with the display off, and the three plane clears the
two player Emerald Hill demo does at frames 1146 and 1147 with the display on, where 4,095 bytes
into plane A alone runs from line 250 of one frame to line 94 of the next. The game polls the busy
bit through all of them, 1,842 reads of the status register during that one, so the wait is real
and the demo comes up two frames later than it did.

**Nothing draws differently.** Frame 1302 of the new run came out bit identical to what frame 1300
drew before, digest and all, so the two frames are the entire difference and the gate's checkpoint
moved by two rather than its expected value changing.

**What the port access ROM said about all of it at the time: nothing.** Page one stayed at 60.9%
and page two at 86.9%, and suite 4, the VRAM fill, at 82.3%. Two further guesses were tried against
it and both left every suite where it was, so neither went in: incrementing the unused source
address registers as a fill runs, which no program can observe because the VDP's registers cannot
be read, and clearing the FIFO empty bit while a DMA is in flight. What suites 1, 3 and 5 were
measuring was not the rate a DMA runs at, and the section above this one is what they were
measuring.

### A transfer takes one external access slot a word, and freezes the 68000

A 68000 to VDP transfer used to happen in one go inside the control port write, at no cost to the
68000 at all. It now takes one external access slot a word, from the same schedule the FIFO drains
on, and `Machine.write` holds the 68000 until it finishes, which is what `genvdp.txt` describes:
the 68000 is frozen, the VDP reads a word, writes it, increments, repeats, and the 68000 resumes.
The source and length registers count as it goes rather than being zeroed at the end.

**The rate is the documented one, and it falls out rather than being written in.** A blanked H40
line has 205 external slots in 3420 master clocks, which is 489 cycles of the 68000, so a word
costs 2.39 cycles. The figure quoted for a transfer to a fast target is `words * 2.4 + 5.6`. The
2.4 is not a constant here; it is 3420 divided by 205 divided by 7.

`hx68k.test.SlotCheck` measures it: a blanked H40 line carries about 205 words, an active one about
18, a blanked H32 line about 167, and a transfer shorter than a line finishes inside it. Making a
slot carry two words was confirmed to fail three of those.

**What it did to the ROMs.** Nothing visible. Sonic 2 draws the same four frames, the port access
ROM reads the same 60.9% and 86.9%, and the 240p patterns are the same seven. What did change is
how the machine spends a frame: the z80 gets 57,894 states a frame where it got 58,514, because the
68000 now stands still through every transfer instead of teleporting through it. Sonic 2 does its
transfers in vblank, where 205 slots a line is more than it needs, so nothing it draws moves.

Both the VRAM fill and the VRAM copy were still instant when this was written. The section above
is what they became.

### Three attempts before that, and what they cost

**And a third time, with the positions above rather than a rate.** It makes no difference: 6,552
with one slot per entry, which is the figure with no FIFO at all and no stall ever taken, and 5,974
with a VRAM entry costing two, with the same three register-write suites falling to 62.5%, 62.5%
and 83.6%. Reading the pages back shows what those three do: their first several cells turn red
together and the rest stay green, which is a run of tests failing at the start of each suite rather
than tests failing throughout.

**What that says, and it is not what it looked like.** The stall was the suspect and the stall is
innocent. Keeping the whole model, stall and all, and *also* landing each write immediately so the
FIFO only delays nothing, puts page two back to 86.8% with all three suites at 100% and takes page
one up from 60.9% to 61.4%, of which the part that matters is **suite 1, the FIFO's own size, going
from 36.9% to 39.6%**. So the timing of the hold is fine, it is worth something, and what breaks
those suites is a write not having landed when the ROM reads it back. 39.6% is the number the next
attempt has to beat, and it has to beat it with a model where the write is genuinely queued rather
than landing twice.

That narrows the whole thing to one question: **how many external access slots does a VRAM word
write consume?** At two it is 9 words per active line, the FIFO stalls, and writes are still in
flight when the ROM looks for them. At one it is 18 words per active line, and the FIFO never fills
and never stalls, so the entire mechanism is inert and nothing moves. Neither is an improvement, so
there is still no FIFO here.

That question is settled above, by measuring the width of a column in the diagram rather than by
trying costs against the ROM: the answer is one, and the section above is what went in. Suite 1,
FIFO Buffer Size, stays at 36.9% with it, because the ROM measures the FIFO through timing the
68000 sees and the 68000 only sees it during active display. The next piece is DMA, which does not
go through the FIFO here at all and costs the 68000 nothing, where on hardware it freezes the 68000
for the whole transfer. That is suite 3, DMA Transfer using FIFO, at 49.3%, and it is a far larger
divergence from hardware than anything the FIFO alone was going to fix.

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

## The 240p Test Suite, looked at

`vendor/240pTestSuite/240p.bin` is Artemio Urbina's pattern ROM, v1.07, fetched by
`haxelib run hx68k setup` from the Internet Archive, since the author distributes through itch.io
and SourceForge and neither answers a plain fetch. `emulator/pattern.hxml` boots it, walks its own
menus with the pad and says what each pattern drew, holding all seven to the digests it carries.

**Every pattern renders correctly**, checked by looking as well as by digest: PLUGE's two side bars
and its four centre blocks, the red, green, blue and white ramps of the colour bars in eleven steps
each, the colour bars against grey, the grid, the linearity grid at one white line every eight
pixels, the grey ramp and the white screen. The pad-driven tests on the main menu were looked at
too: the drop shadow test draws its portrait cleanly with the sprite over it, the striped sprite
test the same, and the checkerboard and horizontal stripes alternate at exactly one pixel, which
was confirmed by reading the framebuffer rather than by eye, since at this size a one-pixel
checkerboard looks like flat grey.

**It is not in the gate.** The walk is 2 minutes 48 on neko against a gate of about sixteen minutes,
and what it covers, plane rendering and CRAM levels, the render check and the commercial ROM already
largely have. `./tests/run.sh` builds it so it cannot rot; running it is one command and it checks
itself.

**What it does not settle.** The colour bars are the pattern that would show the CRAM levels being
expanded linearly rather than through the DAC's own curve, which this renderer does and real
hardware does not. Eleven even steps is what linear expansion looks like, and it is what is drawn
here. Telling that apart from the real curve needs a capture from a console, not a test ROM.

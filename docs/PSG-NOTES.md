# SN76489 notes

What the Mega Drive's PSG does, and how each of these was established. The FM chip has 1032
fixtures behind it and the two CPUs have millions; this part has none, so what stands in for them
is `hx68k.test.PsgCheck`, which is the documented behaviour written out as assertions and run by
`./tests/run.sh`. Where a number here was measured rather than read, it says so.

## The part, and its clock

The Mega Drive's PSG is inside the VDP rather than beside it, and it takes the master clock divided
by fifteen, 3,579,545 Hz. Everything below counts in that clock. Each of the four channels counts
its own period down once every sixteen of those, so a channel's counter ticks at 223,721 Hz.

## One port, two kinds of byte

There is a single write port and no way to read anything back.

- **A byte with bit 7 set latches a register and writes its low four bits.** Bits 6 to 4 choose the
  register: channel in bits 6 and 5, and bit 4 picking the period or the attenuation.
- **A byte with bit 7 clear writes the register that was latched.** For a tone period that is the
  six bits above the four already there, making ten; for an attenuation or the noise control it is
  four bits again, and the two above them are dropped.

`PsgCheck` holds all four of those, including that a data byte to an attenuation register writes
four bits rather than six.

## Attenuation is two decibels a step

Sixteen levels, 0 the loudest and 15 silent, each one 2 dB under the one before it, which is an
amplitude ratio of 10 to the power of -0.1. The published table, scaled to a signed sixteen bit
sample, is 32767, 26028, 20675, 16422, 13045, 10362, 8231, 6538, 5193, 4125, 3277, 2603, 2067,
1642, 1304, 0, and every one of those is the ratio applied to the one before it and rounded. This
rounds rather than truncating for that reason: truncating is a unit low at half the steps.

## A period of zero holds the output high

A channel's counter is reloaded with its ten bit period and the output flips when it reaches zero,
so a period of n gives a full cycle every 2n counts and a frequency of the clock over 32n. A period
of **zero** is the exception: the output is held high and never flips, which is what a program
driving sampled sound through the attenuation register relies on. A period of **one** is not an
exception, and gives a real tone at 111,861 Hz that nothing can hear; this modelled it as another
constant high until `PsgCheck` was written and the documentation said otherwise.

## The noise register is sixteen bits and does not repeat where anyone expects

The Mega Drive's variant, like the Master System's second revision and the Game Gear's, shifts a
**sixteen** bit register with white noise feedback tapped at **bits 0 and 3**, mask 0009h, into
bit 15. The original SN76489 in a BBC Micro or a ColecoVision shifts fifteen bits tapped at bits 0
and 1, and that one is not what is here. Periodic noise taps bit 0 alone, which gives a pulse one
shift high in every sixteen.

**Writing the noise control register resets the shift register to 8000h**, whether the write is a
latch byte or a data byte.

**White noise repeats after 57,337 shifts**, which is worth writing down because the number a reader
expects is 65,535 and it is not that. No trinomial of degree sixteen is primitive over GF(2), so the
sequence is not maximal length: from 8000h it walks a cycle of 57,337 of the 65,535 non-zero states
and the other 8,198 belong to cycles it never enters. The figure was measured here and then computed
again from the feedback rule alone, outside this repository, and the two agree. `PsgCheck` holds the
model to it exactly rather than to a threshold.

The shift rate is the low two bits of the noise control register: once every 10h, 20h or 40h counts,
or the third channel's own period.

## What this does not cover

There is no fixture suite for this part, so nothing here compares it against a known-good
implementation the way `tests/opn2/` does for the YM2612 and `vendor/SingleStepTests-m68000` does
for the 68000. `PsgCheck`'s 38 checks are the documentation restated, and four deliberate mutations
were confirmed to fail the right ones before the pass was believed: the white noise taps moved from
0009h to 0003h, the reset on a noise write removed, the attenuation step halved, and the tone
counter reloaded one too high.

Not modelled, and not known to matter: whatever the part does between a write and the next count,
and the analogue mixing that sets its level against the FM chip's on the board.

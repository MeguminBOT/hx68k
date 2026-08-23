# YM2612 notes

The hardware record for `emulator/src/hx68k/md/Ym2612.hx`, `Channel.hx` and `Operator.hx`, in the
same spirit as `68000-NOTES.md` and `Z80-NOTES.md`: what the part does that no general rule predicts,
and how it was established.

Everything below was established by measurement against Nuked OPN2, which `tests/opn2/` builds as a
program of its own so that its licence never reaches this repository. A claim here means a fixture
went from disagreeing to bit identical when the behaviour was implemented, and the fixture is still
in the suite. Where something is inferred rather than measured it says so.

## The domains

**The envelope counts attenuation, not amplitude.** Total level, the envelope and the sine are all
added in that domain and one exponential turns the total into a number. 256 units of attenuation is
6 dB, so the envelope's own unit is 0.09375 dB and its full 1023 is the part's documented 96 dB.

**Total level joins the envelope before the pair saturate.** The sum of the envelope and total level
saturates at 1023 and is only then shifted left by two into the attenuation domain. Adding them after
the shift, which is the obvious reading, lets a quiet operator go further into silence than the part
allows. Measured: a total level of 16 divides the amplitude by four, 32 by sixteen and 64 by 256, so
one unit of total level is 0.75 dB and eight units of envelope.

**The operator output is fourteen bits signed.** The exponential's mantissa carries an implied
leading one and is shifted left by two before the exponent shifts it back down. An earlier version
was four times too quiet, which left every algorithm that modulates unrecognisable while the four
parallel operators of algorithm seven sounded almost right.

**A channel takes each operator as nine bits, one at a time.** Every operator that reaches the output
is added to the channel accumulator as `output >> 5`, and the accumulator saturates to
`[-256, 255]` **on each addition**, not once at the end. Summing in fourteen bits and narrowing once
gives a different answer wherever a channel is loud.

## The tables

**The sine and exponential tables are the documented formulas and need no data.** `logsin[i]` is
`round(-log2(sin((i + 0.5) * pi / 512)) * 256)` and `exp[i]` is `round((2^(i/256) - 1) * 1024)`.
Both reproduce the reference's tables entry for entry, so nothing is copied.

**Detune is computed, not looked up.** The widely published 32 entry per amount table is wrong at key
code 4 with detune 3, where it gives 3 and the part gives 2. The part builds it from eight values,
`[16, 17, 19, 20, 22, 24, 27, 29]`, a sum of the key code's block and a constant per amount, and a
shift. `Channel.detuneOf` is that computation. Every other one of the 128 entries agrees.

**The envelope's step is two tables, not one.** Below rate 48 the rate says how rarely the envelope
moves, as a power of two, and one of four eight step patterns says which of those steps count. From
48 up it moves on every step and the step itself doubles instead, through a four by four table
indexed by the low two bits of the rate and of the counter. Both were read back out of the reference
a rate at a time, with the counter recorded, so their phase is pinned and not merely their shape.

**Sustain level 15 is matched against 62.** The four bit field becomes 31 for 15 and stays itself
otherwise, and decay gives way to sustain when the envelope's top six bits **equal** that doubled,
not when they pass it. Treating 15 as 31 rather than 62 puts the knee an octave of attenuation too
early.

**An envelope is spent before it is full.** Once the top six bits are all ones, which is 1008 and
above, the part stops stepping, snaps the envelope to 1023 and moves to release. Waiting for 1023
exactly leaves a tail a few units long that the part does not have.

## The rotation

A sample is twenty four internal cycles and each one belongs to one operator of one channel. The
channel is the cycle modulo six and the turn is the cycle divided by six.

**The operator order is S1, S3, S2, S4**, the same interleave the register map uses.

**Three modulation paths arrive a whole sample late**, because the operator they feed has its turn
before the operator that feeds it: S1 into S3, S2 into S3, and S2 into S4. The other three, S1 into
S2, S1 into S4 and S3 into S4, arrive within the sample. Getting this wrong leaves the four parallel
algorithms exact and every chained one wrong, which is what it looked like before it was found.

**The envelope reaches the output a turn after it moves.** An operator speaks with the envelope as it
stood before this sample's step. Stepping first makes every note with a moving envelope one step too
far along.

**The envelope generator runs every sample.** Only the size of the step is held back to one sample in
three. Every transition, attack reaching zero, decay reaching the sustain level, a key going up, an
envelope becoming spent, is decided every single sample. A key lifted between two steps is therefore
heard on the sample it was lifted on.

**An attack too fast to hear lands on the key itself.** Where the scaled attack rate is 62 or more the
envelope goes to zero at the key down rather than at the next step.

## Keys and writes

**The key register's four bits run in operator order**, S1 to S4, and not the slot order that the
rest of the register map uses. This is the one place the interleave does not apply. Established by
keying one operator at a time with four different multiples and hearing which pitch came out.

**A channel takes all four key states at once, on its own first turn of the rotation.** That turn
belongs to operator one, which has therefore already had its turn when the change lands, so operator
one always starts and stops one sample after the other three. This is not a property of when the
write happened: it holds for every channel and every write time.

**Register writes are applied lazily**, when the rotation reaches the slot or channel the address
names, so the delay depends on which channel and which operator is being written and can be anything
up to a full rotation. This is **not yet implemented**: `Ym2612.WRITE_LATENCY` holds a write for a
fixed 26 cycles instead. It is the largest known remaining difference.

## The converter

**The converter visits channels in the order 1, 5, 3, 0, 4, 2**, one every four cycles, and holds
each for three of them. Three of the six are reached before they have handed anything on within that
sample, so **channels 1, 3 and 5 are heard one sample behind channels 0, 2 and 4**. Without this,
five of the six channels are individually exact and no two of them are exact together, which is what
made a six channel patch fail where each of its channels passed alone.

## What is not implemented

- SSG-EG, register 0x90.
- The LFO, register 0x22, and the depths in 0xB4. `Operator.tremolo` is read and ignored.
- Channel three's special mode, registers 0xA8 to 0xAC.
- CSM, and the busy bit of the status register, which `read` always answers as clear.
- The ladder effect of the discrete converter. The reference runs in YM3438 mode, which does not have
  it, so the comparison would have to gain a second mode before the behaviour could be measured.

## Traps in the measuring, not the part

**The reference harness must put standard output in binary mode on Windows.** Without it every 0x0A
byte of a sample leaves as 0x0D 0x0A, every file is longer than it should be, and the comparison is
measuring a shifted stream. This produced spikes twenty times the amplitude of the signal, once per
waveform period, which read convincingly as a hardware quirk and was not one.

**A patch driven into heavy modulation is chaotic.** Two chips one unit apart diverge completely
within a few hundred samples, so correlation on such a fixture says nothing at all. Only bit identical
agreement is worth reporting, which is what `OpnCheck` reports.

**Total level 0 on a carrier already saturates the channel.** Four operators at full level in
algorithm seven sit pinned at the accumulator's limit, so a fixture written that way measures the
saturation and not the synthesis. Several early fixtures were wrong this way and read as chip faults.

# YM2612 notes

The hardware record for `emulator/src/hx68k/md/Ym2612.hx`, `Channel.hx` and `Operator.hx`, in the
same spirit as `68000-NOTES.md` and `Z80-NOTES.md`: what the part does that no general rule predicts,
and how it was established.

Everything below was established by measurement against Nuked OPN2, which `tests/opn2/` builds as a
program of its own so that its licence never reaches this repository. A claim here means a fixture
went from disagreeing to bit identical when the behaviour was implemented, and the fixture is still
in the suite. Where something is inferred rather than measured it says so.

Two other sources sit in `vendor/`: the Sega Genesis Technical Manual's YM2612 section, which is the
part's own documentation and is quoted below where it agrees and where it does not, and the
reference's own source, which is a reverse engineering of the die. Reading the second settled in
minutes several things that fitting curves to its output did not, and where a rule below says it was
read rather than measured, that is what it means.

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
up to a full rotation. A slot register lands where `cycle % 12` is `(group low bit) * 6 + channel`,
and a channel register where `cycle % 6` is the channel; everything shared by the whole chip is taken
as soon as it is seen. `Ym2612.lands` is that rule, and `WRITE_LATENCY` is only how long the write
takes to become something the part will act on at all.

Implementing it changed no fixture on its own, since every fixture here writes its registers long
before it presses a key. What it did change is that the tolerance on `WRITE_LATENCY` collapsed: with
a flat delay a range of values gave the same samples, and with the rotation deciding only one does.

**The phase does not advance on the turn it begins again.** A turn that resets an operator's phase is
spent on the reset: the part clears the increment first and then adds it, so nothing moves. Resetting
and then stepping in the same turn looks harmless, and it is, right up until it is used to cancel out
a key press landing a sample late. Both faults together sounded exactly right on anything without
feedback and a moving envelope, and were what every remaining group was failing on.

**An operator speaks with the phase it had, and only then begins it again.** The turn a phase restarts
on is the last turn of the old one rather than the first of the new. Zeroing the phase before the
operator speaks is silent either way on a key press from nothing, since the envelope is shut, and
audible the moment something already sounding is keyed again. CSM is where that shows.

**Beginning the envelope again and beginning the phase again are different questions.** A key press
asks for both. The SSG shapes ask for one or the other: two of the eight restart the phase, six
restart the envelope, and only the two that name the reset touch the phase. Restarting the phase
whenever the envelope restarts leaves the two alternating shapes drifting by a fraction of a cycle,
which reads as a small amplitude error and is not one.

## The converter

**The converter visits channels in the order 1, 5, 3, 0, 4, 2**, one every four cycles, and holds
each for three of them. Three of the six are reached before they have handed anything on within that
sample, so **channels 1, 3 and 5 are heard one sample behind channels 0, 2 and 4**. Without this,
five of the six channels are individually exact and no two of them are exact together, which is what
made a six channel patch fail where each of its channels passed alone.

## The SSG envelope

Four bits per operator, register 0x90, and the top one turns the other three on. They invert what the
envelope is doing, turn it round each time it reaches the halfway mark, and either stop it there or
start it again.

- The envelope is spent at 512 rather than at 1008, and every step outside attack is four times as
  large.
- A key going up hands back whatever the shape was showing, as the envelope itself, so an inverted
  envelope releases from where it looked like it was rather than from where it was.
- A restart while the envelope is already attacking keeps the attack moving rather than beginning it
  again from nothing, and is timed by the attack rate whatever the envelope was doing before.
- Two of the shapes hold at the top instead of starting again, and holding also stops the envelope
  being called spent.

## Reading a chip that will not say what it is doing

Every one of the last four faults was found the same way and none of them was found by reasoning. The
reference is a program, so its internals can be printed: the phase, the operator output, the channel
accumulator and what it handed on, for one slot, every sample. Printing the same four from here and
lining them up says which of them first disagrees and on which sample, and that names the operation.

Two chips compared only at their outputs cannot tell a late key press from a wrong envelope from a
wrong phase, because each of them can hide the others. Comparing at the outputs is what a suite is
for; comparing inside is what fixing one is for.

`OpnCheck` keeps both: `--envelope` prints what the four envelopes of channel one held around the
sample the two parted, and `--inside` prints the phase, the operator output, the accumulator and what
left the chip.

## The oscillator

**The divider compares bits, not magnitudes.** The counter deciding when the oscillator's phase moves
is matched against one of `[108, 77, 71, 67, 62, 44, 8, 5]` by rate, and it steps when every bit of
that value is set in it. Counted up from nothing that is the same as counting to it, so these read as
a number of samples; the difference only shows when the rate changes while the divider is already
part way up, and it is what the part does.

**The divider runs from reset whether or not the oscillator is enabled.** Only the phase counter is
held. Enabling the oscillator therefore does not start its cycle from the beginning, and where in the
cycle it starts depends on how long the machine had been running.

**Turning the oscillator off does not turn the tremolo off.** The phase counter is held at zero, and
zero is the counter's deepest tremolo, so a channel asking for tremolo with the oscillator stopped is
attenuated by the full depth it asked for and stays there. `lfo-tremolo-stopped` covers it.

**The tremolo and the vibrato reach the operators a sample after the counter moves.** The counter
steps at the first cycle of a sample and what it is worth arrives at the first cycle of the next.

**The tremolo is a triangle of 126 down to 0 and back**, `126 - 2n` over the counter's first 64 steps
and `2(n - 64)` over the rest, shifted right by 7, 3, 1 or 0 by the depth in 0xB4 before it joins the
envelope. Those four shifts are the documented 0, 1.4, 5.9 and 11.8 dB.

**The vibrato is two shifted copies of the note's top seven bits, added and shifted again.** All 64
combinations of depth and step were read out of the reference across all 128 values of those seven
bits and fitted; `Channel.VIBRATO` is the result, packed three shifts to an entry. The sum joins the
note at twice its own width and carries no further than twelve bits, so a high note under the deepest
vibrato wraps rather than saturating.

**The manual's oscillator frequencies do not match.** It gives 3.98, 5.56, 6.02, 6.37, 6.88, 9.63,
48.1 and 72.2 Hz, and every one of those is exactly `clock / (144 * 128 * n)` at 8 MHz for `n` one
larger than the values above. The reference steps on the values above, measured directly. One of the
two is wrong by a part in a hundred and nothing here can say which, so what is implemented is what
the reference does and this is written down.

## Channel three

**Each of its four operators can play a note of its own**, through registers 0xA8 to 0xAE, and any of
the three nonzero settings of 0x27's top two bits turns that on. The manual calls two of those three
illegal.

**Which register drives which operator was measured, and the manual disagrees.** Writing one at a
time and hearing which pitch moved gives 0xA9 to the first operator, 0xAA to the second, 0xA8 to the
third, and the channel's own 0xA0 and 0xA4 to the fourth. The manual assigns 0xA8, 0xA9 and 0xAA to
operators two, three and four in that order, and the channel's own to operator one. The suite is bit
identical on the measured assignment across 66 fixtures.

**Each operator's key code follows the note it is playing**, so its rate scaling, its detune and the
scaling of its vibrato all move with it rather than with the channel's.

**The mode belongs to channel three alone.** The same registers do nothing to any other channel,
which `special-elsewhere-*` covers.

## CSM

The setting the manual calls illegal, `0b10` in the top bits of 0x27, is CSM.

**Timer A running out presses every key of channel three for one sample.** Starting the timer is
itself such a press, on the same rising edge that loads it.

**That key reaches all four operators at once**, unlike the key register, which reaches operator one a
sample after the other three. The CSM key does not pass through the key register at all, which is why
it does not inherit its timing.

**A CSM key folds each operator's own total level into its envelope**, as a bitwise or, before that
sample's envelope step is added. A channel already sounding is therefore pushed back towards silence
every time the timer runs out. This was read in the reference's source after being mistaken for a
magic constant: on the fixture that found it the total level was 10, and ten shifted left three times
is 0x50.

**Total level does not reach the output at all in CSM mode.** Channel three plays as though every
operator were at total level zero. Measured across the whole range, and confirmed in the source.

## The discrete converter

**The discrete part and the YM3438 disagree only here.** The YM3438 drives a channel's value for
three of the four cycles it holds and rests at zero for the fourth. The discrete part drives it for
one and rests at a step whose sign is the value's for the other three, and it adds one to any value
that is not negative. Each channel therefore contributes `value + 1 + 3` where it is positive and
`value - 3` where it is negative, and a channel panned away from a side still leaves four times its
step on that side. That is the ladder effect, and it is why a Model 1 crosses zero through a gap.

`Ym2612.discrete` chooses between them and is the discrete part by default, since that is the part
this machine carries. The reference has both modes and `tests/opn2/opn2.c` takes a `ladder` argument
for the second, so the `discrete-*` fixtures are rendered on one part and everything else on the
other. Forcing the ladder on for the whole suite takes it from 1032 of 1032 to 61, which is how it
was confirmed that the fixtures tell the two apart.

The reference marks its own ladder emulation as not verified against hardware. This one reproduces it
exactly and inherits that caveat.

## Writes and status

**A data write leaves the part busy for 32 of its internal cycles.** An address write does not.
Reading any of the four addresses answers the two timer flags and that busy bit, and SGDK spins on it
before every write it makes.

## Everything after the chips

The chips are held to the reference sample for sample. Nothing about that says how the machine turns
what they made into something a host can play, and four things there were wrong at once.

**The two chips have to be brought to the same loudness by hand.** The FM chip counts in ninths of a
bit and reaches 1536 either way on each side; the SN76489's four bits of attenuation are two decibels
a step and say nothing about how loud nought is. `Psg.LOUDEST` sets one of its channels level with one
FM channel, which is a choice rather than a measurement, and the whole mix then maps onto a sixteen
bit sample so the loudest the machine can be is the loudest a host can play.

**The SN76489's output is unipolar.** A channel contributes its amplitude while its output bit is set
and nothing while it is clear, so the whole mix sits off centre by however many of its channels are
sounding. The machine couples its output through a capacitor; `Sound.COUPLING` is one pole at about
twenty hertz and is what puts the mix back on zero.

**Both chips run far above any host rate.** The FM chip makes 53267 samples a second and the PSG's
squares turn at up to 112 kHz, so reading either at the moment a host sample falls due turns
everything above half the host rate into a tone that is not there. The FM is interpolated between the
two samples either side, which costs one of its own sample periods of delay, and the PSG averages
every one of its own steps between two host samples.

**The machine's clock and the sound device's are not the same clock.** Left alone, one of them is
always the faster, and that shows up as a click every few seconds at one end or a growing delay at
the other. How full the ring is bends the sample rate by up to four parts in a thousand, which is
inaudible and holds it still.

`SoundCheck` measures all of it on the sample ROM's own music: the rate samples come out at, the
offset, the peak, whether anything was dropped, how deep the ring got, and a channel panned hard left
being heard only on the left. It found all four faults above.

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

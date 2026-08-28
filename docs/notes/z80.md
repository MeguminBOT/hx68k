# Z80 behaviour the fixtures pinned down

What `SingleStepTests/z80` taught, in the order it cost time. Everything here came from running the
fixtures and reading the mismatches, not from reading another emulator. The core passes all 1,604
groups on final state, T-state count and pin log, so every rule below is load-bearing.

## The shape of a cycle

- **An opcode fetch is four T-states**: the address on the pins with nothing asserted, then RD and
  MREQ, then the refresh address carrying the byte that was fetched, then the refresh address
  again. The refresh address is `(I << 8) | R` with **R as it was before the increment**.
- **A memory read is three**: address, then RD and MREQ, then the address again carrying the byte.
- **A memory write is three**: address, then WR and MREQ carrying the byte, then the address again.
  The byte appears on the second T-state of a write and the third of a read.
- **A port access is four**: two quiet, then RD or WR with IORQ, then the address again. A read
  carries its byte on the fourth.
- **An internal operation is one T-state, with the last address still on the pins.** That is what
  makes an idle cycle's address predictable.

## The latches

- **The EI latch lasts exactly one instruction.** EI sets it and every instruction clears it. The
  fixtures give it a field of its own, and failing to clear it fails half of every group.
- **Q holds whatever the last instruction left in F**, and is empty where the instruction left F
  alone. Only the flag logic writes it, so **POP AF loads F without writing Q**: loading the flags
  wholesale is not the same as computing them.
- **A prefix byte clears Q.** DD, FD, CB and ED are each a machine cycle that leaves F alone, so an
  SCF or CCF behind a prefix sees Q empty. This alone is worth all 1,000 tests in `DD 37`.
- **P is set by LD A,I and LD A,R** and cleared by everything else. It records that the parity flag
  came from IFF2, which an interrupt arriving at that moment would undo.

## SCF and CCF

`F5` and `F3` are `(A | (F ^ Q)) & 0x28`, with Q as it was when the instruction started. If Q equals
F, meaning the previous instruction wrote flags, both bits come from A. If Q is empty they come
from A or from the flags, whichever holds them.

## BIT

`BIT n,r` takes `F5` and `F3` from the operand. **`BIT n,(HL)` takes them from the high byte of WZ**,
and the double-prefixed `BIT n,(IX+d)` from the high byte of the address it computed, which by then
is the same register.

## The block instructions

- **LDI and LDD** take `F5` from bit 1 and `F3` from bit 3 of the byte moved plus A.
- **CPI and CPD** take them from the difference minus the half carry, by the same two bits.
- **A repeating block instruction that goes round again takes `F5` and `F3` from the high byte of
  PC**, which by then points at the instruction itself, and sets WZ to PC + 1.
- **The repeating port instructions move the half carry and the parity as well**, using the byte
  they carried and the counter they were left with:

  ```
  if carry:
      if byte & 0x80:  half = (B & 0x0F) == 0x00 ; parity ^= !even((B - 1) & 7)
      else:            half = (B & 0x0F) == 0x0F ; parity ^= !even((B + 1) & 7)
  else:                                            parity ^= !even(B & 7)
  ```

  where B is the counter after its decrement. Confirmed against all 995 repeating cases in `ED B2`.

## The index registers

- A DD or FD prefix costs four T-states of its own and counts R. Reaching `(IX+d)` costs a
  displacement read and five idle T-states, and leaves WZ holding the address it computed.
- H and L name the halves of the index register, **unless the same instruction also reaches memory**,
  in which case they stay H and L.
- **In the double prefix the displacement and the opcode are ordinary reads, not fetches**, so R
  counts twice across `DD CB d op` rather than four times. The result is written back to the
  register the low three bits name as well as to memory, unless those bits are 6.

## The maskable interrupt, which the fixtures never reach

The suite covers no interrupt, so everything in this section comes from the part's documentation and
is marked inferred rather than measured.

- **Mode 1 is what this machine uses.** The bus carries no vector for the Z80 to read, so it
  restarts at `0x0038`. Accepting costs thirteen T-states; refusing costs seven.
- **An interrupt is refused while the EI latch is still set**, so one cannot land between an `EI`
  and the instruction after it. That is what lets a driver enable interrupts and return without
  being re-entered immediately.
- **HALT ends only when the interrupt is accepted.** A halted processor with `IFF1` clear stays
  halted. The program counter is already past the `HALT`, so the address pushed is the instruction
  after it.
- **R counts on** for the interrupt acknowledge, as it does for any opcode fetch.

On the Mega Drive the Z80 takes this once a frame, as the beam leaves the display. A sound driver
built around it does all its work there. Without it, the driver initialises and then waits forever,
which looks like a machine with no sound rather than like a fault.

### The interrupt line is held down, not pulsed

The VDP does not hand the Z80 an interrupt at a single instant. It pulls the line down and holds it
for about a scanline. This matters because the Z80 only checks the line between instructions, and a
sound driver spends much of its time between a `DI` and its `EI`. A pulse is lost whenever it lands
inside one of those. A held line is taken on the `EI` instead.

Measured on Sonic 2 over 900 frames, before and after modelling the hold:

| | raised | taken | dropped |
| --- | --- | --- | --- |
| pulsed at the instant the beam leaves the display | 900 | 685 | **203, 22.6%** |
| held down for one scanline | 900 | 789 | 111, 12.3% |

All 111 remaining drops fall in the first 600 frames, which is the boot and the SEGA screen. Across
2700 frames only four more are dropped. The effect is audible as the driver's tempo: a dropped
interrupt is a dropped tempo tick, and which ones get dropped depends on where the driver happens to
be, so the wander is not even periodic.

The hold is one scanline, `Vdp.MASTER_PER_LINE`. That length is **inferred from documentation rather
than measured**, since the suite reaches no interrupt at all. What is measured is that holding for a
scanline sounds right and pulsing sounds wrong.

# Z80 behaviour the fixtures pinned down

What `SingleStepTests/z80` taught, in the order it cost time. Everything here was established by
running the fixtures and reading the mismatches, not by reading another emulator. The core passes
all 1,604 groups on final state, T-state count and pin log, so every rule below is load-bearing.

## The shape of a cycle

- **An opcode fetch is four T-states**: the address on the pins with nothing asserted, then RD and
  MREQ, then the refresh address carrying the byte that was fetched, then the refresh address
  again. The refresh address is `(I << 8) | R` with **R as it was before the increment**.
- **A memory read is three**: address, then RD and MREQ, then the address again carrying the byte.
- **A memory write is three**: address, then WR and MREQ carrying the byte, then the address again.
  The byte appears on the second T-state of a write and the third of a read.
- **A port access is four**: two quiet, then RD or WR with IORQ, then the address again. A read
  carries its byte on the fourth.
- **An internal operation is one T-state each with the last address still on the pins**, which is
  what makes the address of an idle predictable at all.

## The latches

- **The EI latch lasts exactly one instruction.** Every instruction clears it and EI sets it. It is
  a field of its own in the fixtures, and not clearing it fails half of every group.
- **Q is what the last instruction left in F**, and nothing where the instruction left F alone. Only
  the flag logic writes it: **POP AF loads F without writing Q**, since loading the flags wholesale
  is not the flag logic writing them.
- **A prefix byte clears Q.** DD, FD, CB and ED are each their own machine cycle that leaves F
  alone, so an SCF or CCF behind a prefix reads Q as empty. This is worth 1,000 of the 1,000 tests
  in `DD 37`.
- **P is set by LD A,I and LD A,R** and cleared by everything else. It records that the parity flag
  came from IFF2, which an interrupt arriving there would undo.

## SCF and CCF

`F5` and `F3` are `(A | (F ^ Q)) & 0x28`, where Q is what it was when the instruction started. With
Q equal to F, which is to say the instruction before wrote flags, the two bits come from A alone;
with Q empty they come from A or from the flags, whichever has them.

## BIT

`BIT n,r` takes `F5` and `F3` from the operand. **`BIT n,(HL)` takes them from the high byte of WZ**,
and the double-prefixed `BIT n,(IX+d)` from the high byte of the address it computed, which is the
same register by then.

## The block instructions

- **LDI and LDD** take `F5` from bit 1 and `F3` from bit 3 of the byte moved plus A.
- **CPI and CPD** take them from the difference minus the half carry, by the same two bits.
- **A repeating block instruction that goes round again takes `F5` and `F3` from the high byte of
  PC**, which by then points at the instruction itself, and sets WZ to PC + 1.
- **The repeating port instructions move the half carry and the parity as well**, by the byte they
  carried and the counter they were left with:

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
  counts twice across `DD CB d op` rather than four times. The result of the operation is written
  back to the register the low three bits name as well as to memory, unless those bits are 6.

## The maskable interrupt, which the fixtures never reach

The suite covers no interrupt, so this is written from the part's documentation and marked here as
inferred rather than measured.

- **Mode 1 is what this machine uses.** The bus carries no vector the Z80 reads, so the processor
  restarts at `0x0038`. It costs thirteen states where a refused interrupt costs seven.
- **An interrupt is refused while the latch EI leaves behind is still set**, so one cannot land
  between an `EI` and the instruction after it. That is what lets a driver enable interrupts and
  return without being re-entered on the spot.
- **HALT ends only where the interrupt is accepted.** A halted processor with `IFF1` clear stays
  halted. The program counter is already past the `HALT` when it is taken, so the address pushed is
  the instruction after it.
- **R counts on** for the interrupt acknowledge, as it does for any opcode fetch.

On the Mega Drive the Z80 takes this once a frame, as the beam leaves the display. A sound driver
written around it does all its work there: without it, such a driver initialises and then waits
forever, which looks exactly like a machine with no sound rather than like a fault.

package hx68k.cpu.m68k;

import haxe.ds.Vector;
import hx68k.cpu.m68k.Addressing.*;
import hx68k.cpu.m68k.Flags.*;

class Exceptions {
	public static inline final VEC_ILLEGAL = 4;

	public static inline final VEC_DIVIDE_BY_ZERO = 5;

	static inline final VEC_CHK = 6;

	static inline final VEC_TRAPV = 7;

	static inline final VEC_PRIVILEGE = 8;

	static inline final VEC_LINE_A = 10;

	static inline final VEC_LINE_F = 11;

	static inline function supervisor(c:M68000):Bool {
		if (c.s) return true;
		c.exception(VEC_PRIVILEGE, (c.pcAtStart - 4) | 0, 4);
		return false;
	}

	static inline function statusTail(c:M68000):Void {
		c.bus.read((c.pc - 2) & 0xFFFFFE, c.progFc(), true, true);
		c.prefetch();
	}

	public static function traps(t:Vector<M68000->Void>):Void {
		for (n in 0...16) {
			final vector = 32 + n;
			t[0x4E40 | n] = function(c:M68000) {
				c.exception(vector, (c.pcAtStart - 2) | 0, 4);
			}
		}

		t[0x4E76] = function(c:M68000) {
			if (!c.vf) {
				c.prefetch();
				return;
			}
			final oldSr = c.getSr();
			c.setS(true);
			c.t = false;
			c.prefetch();
			c.exception(VEC_TRAPV, (c.pcAtStart - 2) | 0, 0, oldSr);
		}

		t[0x4AFC] = function(c:M68000) {
			c.exception(VEC_ILLEGAL, (c.pcAtStart - 4) | 0, 4);
		}

		for (op in 0xA000...0xB000) {
			t[op] = function(c:M68000) {
				c.exception(VEC_LINE_A, (c.pcAtStart - 4) | 0, 4);
			}
		}

		for (op in 0xF000...0x10000) {
			t[op] = function(c:M68000) {
				c.exception(VEC_LINE_F, (c.pcAtStart - 4) | 0, 4);
			}
		}
	}

	public static function check(t:Vector<M68000->Void>):Void {
		for (dreg in 0...8) for (m in 0...8) for (r in 0...8) {
			if (m == 1 || (m == 7 && r > 4)) continue;

			final mode = m, reg = r, d = dreg;
			final back = extWords(m, r, 2) << 1;

			t[0x4180 | (dreg << 9) | (m << 3) | r] = function(c:M68000) {
				final bound = signExt16(readEa(c, mode, reg, 2, 0));
				if (c.faulted) return;

				final v = signExt16(c.d[d] & 0xFFFF);
				c.zf = v == 0;
				c.vf = false;
				c.cf = false;
				c.nf = v < 0;

				if (v >= 0 && v <= bound) {
					c.idle(6);
					c.prefetch();
					return;
				}

				final diff = (v - bound) & 0xFFFF;
				final slow = v < 0 && ((diff & 0x8000) != 0 || diff == 0);
				c.exception(VEC_CHK, (c.pcAtStart - 2 + back) | 0, slow ? 10 : 8);
			}
		}
	}

	public static function statusRegister(t:Vector<M68000->Void>):Void {
		for (m in 0...8) for (r in 0...8) {
			final mode = m, reg = r;

			if (dataAlterable(m, r)) {
				t[0x40C0 | (m << 3) | r] = function(c:M68000) {
					if (mode == 0) {
						c.d[reg] = (c.d[reg] & 0xFFFF0000) | c.getSr();
						c.prefetch();
						c.idle(2);
						return;
					}

					final addr = eaAddr(c, mode, reg, 2);
					if (c.faulted) return;
					operandFaultPc(c, mode, reg, 2, 0);
					c.readWord(addr, c.dataFc());
					if (c.faulted) return;
					c.prefetch();
					c.writeWord(addr, c.dataFc(), c.getSr());
				}
			}

			if (m == 1 || (m == 7 && r > 4)) continue;

			t[0x44C0 | (m << 3) | r] = function(c:M68000) {
				final v = readEa(c, mode, reg, 2, 0);
				if (c.faulted) return;
				c.idle(4);
				c.setCcr(v);
				statusTail(c);
			}

			t[0x46C0 | (m << 3) | r] = function(c:M68000) {
				if (!supervisor(c)) return;
				final v = readEa(c, mode, reg, 2, 0);
				if (c.faulted) return;
				c.idle(4);
				c.setSr(v);
				statusTail(c);
			}
		}
	}

	public static function statusImmediate(t:Vector<M68000->Void>):Void {
		final bases = [0x0000, 0x0200, 0x0A00];
		final kinds = [Arithmetic.OP_OR, Arithmetic.OP_AND, Arithmetic.OP_EOR];

		for (i in 0...bases.length) {
			final base = bases[i];
			final kind = kinds[i];

			t[base | 0x3C] = function(c:M68000) {
				final imm = c.fetchExt() & 0xFF;
				c.idle(8);
				final v = c.getCcr();
				c.setCcr(switch (kind) {
					case Arithmetic.OP_OR: v | imm;
					case Arithmetic.OP_AND: v & imm;
					default: v ^ imm;
				});
				statusTail(c);
			}

			t[base | 0x7C] = function(c:M68000) {
				if (!supervisor(c)) return;
				final imm = c.fetchExt() & 0xFFFF;
				c.idle(8);
				final v = c.getSr();
				c.setSr(switch (kind) {
					case Arithmetic.OP_OR: v | imm;
					case Arithmetic.OP_AND: v & imm;
					default: v ^ imm;
				});
				statusTail(c);
			}
		}
	}

	public static function supervisorOnly(t:Vector<M68000->Void>):Void {
		t[0x4E70] = function(c:M68000) {
			if (!supervisor(c)) return;
			c.idle(128);
			c.prefetch();
		}

		t[0x4E72] = function(c:M68000) {
			if (!supervisor(c)) return;
			final v = c.irc;
			c.idle(4);
			c.setSr(v);
		}

		t[0x4E73] = function(c:M68000) {
			if (!supervisor(c)) return;
			final sp = c.a[7] | 0;
			final sr = c.readWord(sp, c.dataFc());
			if (c.faulted) return;
			final target = c.readLong((sp + 2) | 0, c.dataFc());
			if (c.faulted) return;
			c.a[7] = (sp + 6) | 0;
			c.setSr(sr);
			c.jump(target);
		}

		for (reg in 0...8) {
			final r = reg;

			t[0x4E60 | reg] = function(c:M68000) {
				if (!supervisor(c)) return;
				c.inactiveSp = c.a[r] | 0;
				c.prefetch();
			}

			t[0x4E68 | reg] = function(c:M68000) {
				if (!supervisor(c)) return;
				c.a[r] = c.inactiveSp | 0;
				c.prefetch();
			}
		}
	}
}

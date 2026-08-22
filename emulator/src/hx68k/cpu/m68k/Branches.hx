package hx68k.cpu.m68k;

import haxe.ds.Vector;
import hx68k.cpu.m68k.Addressing.*;
import hx68k.cpu.m68k.Flags.*;

class Branches {
	public static function branches(t:Vector<M68000->Void>):Void {
		for (cc in 0...16) for (disp in 0...256) {
			final code = cc, d8 = signExt8(disp);
			final word = disp == 0;
			final call = cc == 1;

			t[0x6000 | (cc << 8) | disp] = function(c:M68000) {
				final base = (c.pcAtStart - 2) | 0;
				final target = word ? (base + signExt16(c.irc)) | 0 : (base + d8) | 0;

				if (call) {
					c.idle(2);
					push32(c, word ? (c.pc | 0) : ((c.pc - 2) | 0));
					if (c.faulted) return;
					c.faultPc = target;
					c.jump(target);
					return;
				}

				if (condition(c, code)) {
					c.idle(2);
					c.jump(target);
					return;
				}

				c.idle(4);
				if (word) c.fetchExt();
				c.prefetch();
			}
		}
	}

	public static function dbcc(t:Vector<M68000->Void>):Void {
		for (cc in 0...16) for (reg in 0...8) {
			final code = cc, r = reg;

			t[0x50C8 | (cc << 8) | reg] = function(c:M68000) {
				if (condition(c, code)) {
					c.idle(4);
					c.fetchExt();
					c.prefetch();
					return;
				}

				final counter = ((c.d[r] & 0xFFFF) - 1) & 0xFFFF;

				if (counter == 0xFFFF) {
					c.d[r] = (c.d[r] & 0xFFFF0000) | counter;
					c.idle(2);
					c.fetchExt();
					c.prefetch();
					c.idle(4);
					return;
				}

				final target = ((c.pcAtStart - 2) + signExt16(c.irc)) | 0;
				c.idle(2);

				if ((target & 1) != 0) {
					c.faultPc = c.pcAtStart;
					c.jump(target);
					return;
				}

				c.d[r] = (c.d[r] & 0xFFFF0000) | counter;
				c.jump(target);
			}
		}
	}

	public static function scc(t:Vector<M68000->Void>):Void {
		for (cc in 0...16) for (m in 0...8) for (r in 0...8) {
			if (!dataAlterable(m, r)) continue;

			final code = cc, mode = m, reg = r;

			t[0x50C0 | (cc << 8) | (m << 3) | r] = function(c:M68000) {
				final set = condition(c, code);

				if (mode == 0) {
					c.d[reg] = (c.d[reg] & 0xFFFFFF00) | (set ? 0xFF : 0);
					c.prefetch();
					if (set) c.idle(2);
					return;
				}

				final addr = eaAddr(c, mode, reg, 1);
				c.readByte(addr, c.dataFc());
				c.prefetch();
				c.writeByte(addr, c.dataFc(), set ? 0xFF : 0);
			}
		}
	}

	public static function jumps(t:Vector<M68000->Void>):Void {
		for (m in 0...8) for (r in 0...8) {
			if (!control(m, r)) continue;

			final mode = m, reg = r;
			final ret = controlExt(m, r);

			t[0x4EC0 | (m << 3) | r] = function(c:M68000) {
				c.jump(jumpTarget(c, mode, reg));
			}

			t[0x4E80 | (m << 3) | r] = function(c:M68000) {
				final target = jumpTarget(c, mode, reg);
				final back = (c.pcAtStart - 4 + 2 + (ret << 1)) | 0;
				c.faultPc = (c.pcAtStart - 2 + (ret << 1)) | 0;

				if ((target & 1) != 0) {
					c.jump(target);
					return;
				}

				c.pc = target;
				c.ird = c.bus.read(c.pc & 0xFFFFFE, c.progFc(), true, true) & 0xFFFF;
				c.faultIr = c.ird;
				c.pc = (c.pc + 2) | 0;

				push32(c, back);
				if (c.faulted) return;

				c.irc = c.bus.read(c.pc & 0xFFFFFE, c.progFc(), true, true) & 0xFFFF;
				c.pc = (c.pc + 2) | 0;
			}
		}
	}

	public static function returns(t:Vector<M68000->Void>):Void {
		t[0x4E75] = function(c:M68000) {
			final sp = c.a[7] | 0;
			final target = c.readLong(sp, c.dataFc());
			if (c.faulted) return;
			c.a[7] = (sp + 4) | 0;
			c.jump(target);
		}

		t[0x4E77] = function(c:M68000) {
			final sp = c.a[7] | 0;
			final ccr = c.readWord(sp, c.dataFc());
			if (c.faulted) return;
			final target = c.readLong((sp + 2) | 0, c.dataFc());
			if (c.faulted) return;
			c.setCcr(ccr);
			c.a[7] = (sp + 6) | 0;
			c.jump(target);
		}
	}
}

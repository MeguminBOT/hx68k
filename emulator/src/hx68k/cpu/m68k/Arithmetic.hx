package hx68k.cpu.m68k;

import haxe.ds.Vector;
import hx68k.cpu.m68k.Addressing.*;
import hx68k.cpu.m68k.Flags.*;

class Arithmetic {
	public static inline final OP_OR = 0;

	public static inline final OP_AND = 1;

	public static inline final OP_SUB = 2;

	public static inline final OP_ADD = 3;

	public static inline final OP_EOR = 4;

	public static inline final OP_CMP = 5;

	public static inline final NOT = 0;

	public static inline final NEG = 1;

	public static inline final NEGX = 2;

	public static inline final EX_ABCD = 0;

	public static inline final EX_SBCD = 1;

	public static inline final EX_ADDX = 2;

	public static inline final EX_SUBX = 3;

	static function aluOp(c:M68000, kind:Int, dst:Int, src:Int, size:Int):Int {
		final m = mask(size);
		final top = msb(size);

		switch (kind) {
			case OP_OR:
				final r = (dst | src) & m;
				setLogicFlags(c, r, size);
				return r;
			case OP_AND:
				final r = (dst & src) & m;
				setLogicFlags(c, r, size);
				return r;
			case OP_EOR:
				final r = (dst ^ src) & m;
				setLogicFlags(c, r, size);
				return r;
			case OP_ADD:
				final r = (dst + src) & m;
				c.vf = ((src ^ r) & (dst ^ r) & top) != 0;
				c.cf = (((src & dst) | (~r & (src | dst))) & top) != 0;
				c.xf = c.cf;
				setNz(c, r, size);
				return r;
			default:
				final r = (dst - src) & m;
				c.vf = ((src ^ dst) & (dst ^ r) & top) != 0;
				c.cf = (((src & ~dst) | (r & (src | ~dst))) & top) != 0;
				if (kind == OP_SUB) c.xf = c.cf;
				setNz(c, r, size);
				return r;
		}
	}

	public static function aluEaToReg(t:Vector<M68000->Void>, base:Int, kind:Int):Void {
		for (szBits in 0...3) {
			final sz = szBits == 0 ? 1 : (szBits == 1 ? 2 : 4);
			for (dreg in 0...8) for (m in 0...8) for (r in 0...8) {
				if (m == 7 && r > 4) continue;
				if (m == 1 && (sz == 1 || kind == OP_AND || kind == OP_OR)) continue;

				final mode = m, reg = r, size = sz, k = kind, d = dreg;
				final srcMem = m >= 2 && !(m == 7 && r == 4);
				final tail = sz != 4 ? 0 : (kind == OP_CMP ? 2 : (srcMem ? 2 : 4));

				t[base | (dreg << 9) | (szBits << 6) | (m << 3) | r] = function(c:M68000) {
					final v = readEa(c, mode, reg, size, 0);
					if (c.faulted) return;
					final res = aluOp(c, k, c.d[d] & mask(size), v, size);
					if (k != OP_CMP) writeReg(c, d, size, res);
					c.prefetch();
					c.idle(tail);
				}
			}
		}
	}

	public static function aluRegToEa(t:Vector<M68000->Void>, base:Int, kind:Int):Void {
		for (szBits in 0...3) {
			final sz = szBits == 0 ? 1 : (szBits == 1 ? 2 : 4);
			for (sreg in 0...8) for (m in 0...8) for (r in 0...8) {
				if (kind == OP_EOR ? !dataAlterable(m, r) : !memAlterable(m, r)) continue;

				final mode = m, reg = r, size = sz, k = kind, s = sreg;

				t[base | (sreg << 9) | ((szBits + 4) << 6) | (m << 3) | r] = function(c:M68000) {
					final src = c.d[s] & mask(size);

					if (mode == 0) {
						final res = aluOp(c, k, c.d[reg] & mask(size), src, size);
						writeReg(c, reg, size, res);
						c.prefetch();
						if (size == 4) c.idle(4);
						return;
					}

					final addr = eaAddr(c, mode, reg, size);
					if (c.faulted) return;
					operandFaultPc(c, mode, reg, size, 0);

					final v = readMem(c, addr, size);
					if (c.faulted) return;

					final res = aluOp(c, k, v, src, size);
					c.prefetch();
					writeBack(c, addr, size, res);
				}
			}
		}
	}

	public static function aluAddress(t:Vector<M68000->Void>, base:Int, kind:Int):Void {
		for (long in 0...2) {
			final sz = long == 0 ? 2 : 4;
			final opmode = long == 0 ? 3 : 7;
			for (areg in 0...8) for (m in 0...8) for (r in 0...8) {
				if (m == 7 && r > 4) continue;

				final mode = m, reg = r, size = sz, k = kind, a = areg;
				final srcMem = m >= 2 && !(m == 7 && r == 4);
				final tail = kind == OP_CMP ? 2 : (sz == 2 ? 4 : (srcMem ? 2 : 4));

				t[base | (areg << 9) | (opmode << 6) | (m << 3) | r] = function(c:M68000) {
					final raw = readEa(c, mode, reg, size, 0);
					if (c.faulted) return;
					final v = size == 2 ? signExt16(raw) : (raw | 0);

					if (k == OP_CMP) aluOp(c, OP_CMP, c.a[a] | 0, v, 4);
					else c.a[a] = (k == OP_ADD ? (c.a[a] + v) : (c.a[a] - v)) | 0;

					c.prefetch();
					c.idle(tail);
				}
			}
		}
	}

	public static function aluImmediate(t:Vector<M68000->Void>, base:Int, kind:Int):Void {
		for (szBits in 0...3) {
			final sz = szBits == 0 ? 1 : (szBits == 1 ? 2 : 4);
			for (m in 0...8) for (r in 0...8) {
				if (!dataAlterable(m, r)) continue;

				final mode = m, reg = r, size = sz, k = kind;
				final immExt = sz == 4 ? 2 : 1;

				t[base | (szBits << 6) | (m << 3) | r] = function(c:M68000) {
					var imm:Int;
					if (size == 4) {
						final hi = c.fetchExt();
						final lo = c.fetchExt();
						imm = (hi << 16) | lo;
					} else {
						final w = c.fetchExt();
						imm = size == 1 ? (w & 0xFF) : (w & 0xFFFF);
					}

					if (mode == 0) {
						final res = aluOp(c, k, c.d[reg] & mask(size), imm, size);
						if (k != OP_CMP) writeReg(c, reg, size, res);
						c.prefetch();
						if (size == 4) c.idle(k == OP_CMP ? 2 : 4);
						return;
					}

					final addr = eaAddr(c, mode, reg, size);
					if (c.faulted) return;
					operandFaultPc(c, mode, reg, size, immExt);

					final v = readMem(c, addr, size);
					if (c.faulted) return;

					final res = aluOp(c, k, v, imm, size);
					c.prefetch();
					if (k != OP_CMP) writeBack(c, addr, size, res);
				}
			}
		}
	}

	public static function quick(t:Vector<M68000->Void>):Void {
		for (sub in 0...2) for (data in 0...8) for (szBits in 0...3) {
			final sz = szBits == 0 ? 1 : (szBits == 1 ? 2 : 4);
			final value = data == 0 ? 8 : data;
			for (m in 0...8) for (r in 0...8) {
				if (m == 1 ? sz == 1 : (m != 0 && !memAlterable(m, r))) continue;

				final mode = m, reg = r, size = sz, v = value;
				final k = sub == 0 ? OP_ADD : OP_SUB;

				t[0x5000 | (data << 9) | (sub << 8) | (szBits << 6) | (m << 3) | r] = function(c:M68000) {
					if (mode == 1) {
						c.a[reg] = (k == OP_ADD ? (c.a[reg] + v) : (c.a[reg] - v)) | 0;
						c.prefetch();
						c.idle(4);
						return;
					}

					if (mode == 0) {
						final res = aluOp(c, k, c.d[reg] & mask(size), v, size);
						writeReg(c, reg, size, res);
						c.prefetch();
						if (size == 4) c.idle(4);
						return;
					}

					final addr = eaAddr(c, mode, reg, size);
					if (c.faulted) return;
					operandFaultPc(c, mode, reg, size, 0);

					final cur = readMem(c, addr, size);
					if (c.faulted) return;

					final res = aluOp(c, k, cur, v, size);
					c.prefetch();
					writeBack(c, addr, size, res);
				}
			}
		}
	}

	static inline function cmpmStep(c:M68000, reg:Int, size:Int, source:Bool):Int {
		final addr = c.a[reg] | 0;
		final odd = size != 1 && (addr & 1) != 0;
		if (odd && !source) return addr;
		final step = (odd && size == 4) ? 2 : ((reg == 7 && size == 1) ? 2 : size);
		c.a[reg] = (addr + step) | 0;
		return addr;
	}

	public static function cmpm(t:Vector<M68000->Void>):Void {
		for (szBits in 0...3) {
			final sz = szBits == 0 ? 1 : (szBits == 1 ? 2 : 4);
			for (ax in 0...8) for (ay in 0...8) {
				final dst = ax, src = ay, size = sz;

				t[0xB108 | (ax << 9) | (szBits << 6) | ay] = function(c:M68000) {
					final sa = cmpmStep(c, src, size, true);
					c.faultPc = c.pcAtStart;
					final s = readMem(c, sa, size);
					if (c.faulted) return;

					final da = cmpmStep(c, dst, size, false);
					c.faultPc = c.pcAtStart;
					final d = readMem(c, da, size);
					if (c.faulted) return;

					aluOp(c, OP_CMP, d, s, size);
					c.prefetch();
				}
			}
		}
	}

	static function unaryResult(c:M68000, kind:Int, v:Int, size:Int):Int {
		final m = mask(size);
		final top = msb(size);

		switch (kind) {
			case NEG:
				final r = (0 - v) & m;
				c.nf = (r & top) != 0;
				c.zf = r == 0;
				c.vf = (v & r & top) != 0;
				c.cf = r != 0;
				c.xf = c.cf;
				return r;
			case NEGX:
				final x = c.xf ? 1 : 0;
				final r = (0 - v - x) & m;
				c.nf = (r & top) != 0;
				if (r != 0) c.zf = false;
				c.vf = (v & r & top) != 0;
				c.cf = v != 0 || x != 0;
				c.xf = c.cf;
				return r;
			default:
				final r = (~v) & m;
				setLogicFlags(c, r, size);
				return r;
		}
	}

	public static function unary(t:Vector<M68000->Void>, base:Int, kind:Int):Void {
		for (szBits in 0...3) {
			final sz = szBits == 0 ? 1 : (szBits == 1 ? 2 : 4);
			for (m in 0...8) for (r in 0...8) {
				if (!dataAlterable(m, r)) continue;
				final mode = m, reg = r, size = sz, k = kind;
				t[base | (szBits << 6) | (m << 3) | r] = function(c:M68000) {
					if (mode == 0) {
						final res = unaryResult(c, k, c.d[reg] & mask(size), size);
						writeReg(c, reg, size, res);
						c.prefetch();
						if (size == 4) c.idle(2);
						return;
					}

					final addr = eaAddr(c, mode, reg, size);
					if (c.faulted) return;
					operandFaultPc(c, mode, reg, size, 0);

					final v = readMem(c, addr, size);
					if (c.faulted) return;

					final res = unaryResult(c, k, v, size);

					c.prefetch();
					writeBack(c, addr, size, res);
				}
			}
		}
	}

	public static function tst(t:Vector<M68000->Void>):Void {
		for (szBits in 0...3) {
			final sz = szBits == 0 ? 1 : (szBits == 1 ? 2 : 4);
			for (m in 0...8) for (r in 0...8) {
				if (!dataAlterable(m, r)) continue;
				final mode = m, reg = r, size = sz;
				t[0x4A00 | (szBits << 6) | (m << 3) | r] = function(c:M68000) {
					final v = readEa(c, mode, reg, size, 0);
					if (c.faulted) return;
					setLogicFlags(c, v, size);
					c.prefetch();
				}
			}
		}
	}

	public static function clr(t:Vector<M68000->Void>):Void {
		for (szBits in 0...3) {
			final sz = szBits == 0 ? 1 : (szBits == 1 ? 2 : 4);
			for (m in 0...8) for (r in 0...8) {
				if (!dataAlterable(m, r)) continue;
				final mode = m, reg = r, size = sz;
				t[0x4200 | (szBits << 6) | (m << 3) | r] = function(c:M68000) {
					if (mode == 0) {
						writeReg(c, reg, size, 0);
						c.nf = false;
						c.zf = true;
						c.vf = false;
						c.cf = false;
						c.prefetch();
						if (size == 4) c.idle(2);
						return;
					}

					final addr = eaAddr(c, mode, reg, size);
					if (c.faulted) return;
					operandFaultPc(c, mode, reg, size, 0);

					readMem(c, addr, size);
					if (c.faulted) return;

					c.nf = false;
					c.zf = true;
					c.vf = false;
					c.cf = false;

					c.prefetch();
					writeBack(c, addr, size, 0);
				}
			}
		}
	}

	static function bcdAdd(c:M68000, dst:Int, src:Int):Int {
		final x = c.xf ? 1 : 0;
		final bin = dst + src + x;

		final lowFix = ((dst ^ src ^ bin) & 0x10) != 0 || (bin & 0x0F) > 9;
		final lo = lowFix ? bin + 6 : bin;
		final highFix = (bin & 0x1F0) > 0x90 || (lo & 0x1F0) > 0x90;
		final res = (highFix ? lo + 0x60 : lo) & 0xFF;

		c.cf = highFix;
		c.xf = highFix;
		c.vf = (~bin & res & 0x80) != 0;
		c.nf = (res & 0x80) != 0;
		if (res != 0) c.zf = false;
		return res;
	}

	static function bcdSub(c:M68000, dst:Int, src:Int):Int {
		final x = c.xf ? 1 : 0;
		final bin = dst - src - x;

		final lowFix = ((dst ^ src ^ bin) & 0x10) != 0;
		final lo = lowFix ? bin - 6 : bin;
		final borrow = (bin & 0x100) != 0;
		final res = (borrow ? lo - 0x60 : lo) & 0xFF;

		final carry = borrow || (lo & 0x100) != 0;
		c.cf = carry;
		c.xf = carry;
		c.vf = (bin & ~res & 0x80) != 0;
		c.nf = (res & 0x80) != 0;
		if (res != 0) c.zf = false;
		return res;
	}

	static function extendedOp(c:M68000, dst:Int, src:Int, size:Int, sub:Bool):Int {
		final m = mask(size);
		final top = msb(size);
		final x = c.xf ? 1 : 0;
		final r = (sub ? (dst - src - x) : (dst + src + x)) & m;

		if (sub) {
			c.vf = ((src ^ dst) & (dst ^ r) & top) != 0;
			c.cf = (((src & ~dst) | (r & (src | ~dst))) & top) != 0;
		} else {
			c.vf = ((src ^ r) & (dst ^ r) & top) != 0;
			c.cf = (((src & dst) | (~r & (src | dst))) & top) != 0;
		}

		c.xf = c.cf;
		c.nf = (r & top) != 0;
		if (r != 0) c.zf = false;
		return r;
	}

	static inline function extendedAddr(c:M68000, reg:Int, size:Int):Int {
		final step = (reg == 7 && size == 1) ? 2 : size;
		final addr = (c.a[reg] - step) | 0;
		if (size != 4 || (addr & 1) == 0) c.a[reg] = addr;
		return addr;
	}

	public static function extended(t:Vector<M68000->Void>, base:Int, kind:Int):Void {
		final sizes = kind < 2 ? [1] : [1, 2, 4];

		for (size in sizes) {
			final szBits = size == 1 ? 0 : (size == 2 ? 1 : 2);
			for (rx in 0...8) for (rm in 0...2) for (ry in 0...8) {
				final dst = rx, src = ry, sz = size, k = kind;
				final memory = rm == 1;
				final op = base | (rx << 9) | (kind < 2 ? 0 : (szBits << 6)) | (rm << 3) | ry;

				t[op] = function(c:M68000) {
					if (!memory) {
						final a = c.d[dst] & mask(sz);
						final b = c.d[src] & mask(sz);
						final res = switch (k) {
							case 0: bcdAdd(c, a, b);
							case 1: bcdSub(c, a, b);
							case 2: extendedOp(c, a, b, sz, false);
							default: extendedOp(c, a, b, sz, true);
						}
						writeReg(c, dst, sz, res);
						c.prefetch();
						c.idle(k < 2 ? 2 : (sz == 4 ? 4 : 0));
						return;
					}

					c.idle(2);

					final sa = extendedAddr(c, src, sz);
					c.faultPc = c.pcAtStart;
					final b = sz == 4 ? c.readLongLowFirst(sa, c.dataFc()) : readMem(c, sa, sz);
					if (c.faulted) return;

					final da = extendedAddr(c, dst, sz);
					c.faultPc = c.pcAtStart;
					final a = sz == 4 ? c.readLongLowFirst(da, c.dataFc()) : readMem(c, da, sz);
					if (c.faulted) return;

					final res = switch (k) {
						case 0: bcdAdd(c, a, b);
						case 1: bcdSub(c, a, b);
						case 2: extendedOp(c, a, b, sz, false);
						default: extendedOp(c, a, b, sz, true);
					}

					if (sz != 4) {
						c.prefetch();
						writeBack(c, da, sz, res);
						return;
					}

					c.writeWord((da + 2) | 0, c.dataFc(), res & 0xFFFF);
					if (c.faulted) return;
					c.prefetch();
					c.writeWord(da, c.dataFc(), (res >>> 16) & 0xFFFF);
				}
			}
		}
	}

	public static function nbcd(t:Vector<M68000->Void>):Void {
		for (m in 0...8) for (r in 0...8) {
			if (!dataAlterable(m, r)) continue;

			final mode = m, reg = r;

			t[0x4800 | (m << 3) | r] = function(c:M68000) {
				if (mode == 0) {
					writeReg(c, reg, 1, bcdSub(c, 0, c.d[reg] & 0xFF));
					c.prefetch();
					c.idle(2);
					return;
				}

				final addr = eaAddr(c, mode, reg, 1);
				final v = c.readByte(addr, c.dataFc());
				final res = bcdSub(c, 0, v);
				c.prefetch();
				c.writeByte(addr, c.dataFc(), res);
			}
		}
	}
}

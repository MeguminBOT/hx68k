package hx68k.cpu.m68k;

import haxe.ds.Vector;
import hx68k.cpu.m68k.Addressing.*;
import hx68k.cpu.m68k.Flags.*;

class Shifts {
	static inline final SH_AS = 0;

	static inline final SH_LS = 1;

	static inline final SH_ROX = 2;

	static inline final SH_RO = 3;

	static function shiftOp(c:M68000, type:Int, left:Bool, v0:Int, count:Int, size:Int):Int {
		final m = mask(size);
		final top = msb(size);
		final bits = size << 3;
		final v = v0 & m;

		if (type == SH_ROX) {
			var x = c.xf;
			var r = v;
			final n = count % (bits + 1);
			if (left) {
				for (_ in 0...n) {
					final out = (r & top) != 0;
					r = ((r << 1) | (x ? 1 : 0)) & m;
					x = out;
				}
			} else {
				for (_ in 0...n) {
					final out = (r & 1) != 0;
					r = ((r >>> 1) | (x ? top : 0)) & m;
					x = out;
				}
			}
			c.xf = x;
			c.cf = x;
			c.vf = false;
			setNz(c, r, size);
			return r;
		}

		if (type == SH_RO) {
			final n = count % bits;
			var r = v;
			if (n != 0) r = left ? (((v << n) | (v >>> (bits - n))) & m) : (((v >>> n) | (v << (bits - n))) & m);
			c.cf = count == 0 ? false : (left ? (r & 1) != 0 : (r & top) != 0);
			c.vf = false;
			setNz(c, r, size);
			return r;
		}

		if (count == 0) {
			c.cf = false;
			c.vf = false;
			setNz(c, v, size);
			return v;
		}

		var r:Int;
		var carry:Bool;

		if (left) {
			r = count >= bits ? 0 : ((v << count) & m);
			carry = count > bits ? false : (count == bits ? (v & 1) != 0 : ((v >>> (bits - count)) & 1) != 0);
			if (type == SH_AS) {
				if (count >= bits) {
					c.vf = v != 0;
				} else {
					final keep = (m << (bits - count - 1)) & m;
					final masked = v & keep;
					c.vf = masked != 0 && masked != keep;
				}
			} else {
				c.vf = false;
			}
		} else {
			if (type == SH_AS) {
				final neg = (v & top) != 0;
				r = count >= bits ? (neg ? m : 0) : (((v >>> count) | (neg ? ((m << (bits - count)) & m) : 0)) & m);
				carry = count >= bits ? neg : ((v >>> (count - 1)) & 1) != 0;
			} else {
				r = count >= bits ? 0 : (v >>> count);
				carry = count > bits ? false : ((v >>> (count - 1)) & 1) != 0;
			}
			c.vf = false;
		}

		c.cf = carry;
		c.xf = carry;
		setNz(c, r, size);
		return r;
	}

	public static function shiftsReg(t:Vector<M68000->Void>):Void {
		for (type in 0...4) for (dr in 0...2) for (szBits in 0...3) for (ir in 0...2) for (cnt in 0...8) for (reg in 0...8) {
			final sz = szBits == 0 ? 1 : (szBits == 1 ? 2 : 4);
			final ty = type, left = dr == 1, size = sz, r = reg;
			final byReg = ir == 1;
			final fixed = cnt == 0 ? 8 : cnt;
			final countReg = cnt;
			final head = sz == 4 ? 4 : 2;

			t[0xE000 | (cnt << 9) | (dr << 8) | (szBits << 6) | (ir << 5) | (type << 3) | reg] = function(c:M68000) {
				final n = byReg ? (c.d[countReg] & 63) : fixed;
				final res = shiftOp(c, ty, left, c.d[r] & mask(size), n, size);
				writeReg(c, r, size, res);
				c.prefetch();
				c.idle(head + (n << 1));
			}
		}
	}

	public static function shiftsMem(t:Vector<M68000->Void>):Void {
		for (type in 0...4) for (dr in 0...2) for (m in 0...8) for (r in 0...8) {
			if (!memAlterable(m, r)) continue;

			final ty = type, left = dr == 1, mode = m, reg = r;

			t[0xE0C0 | (type << 9) | (dr << 8) | (m << 3) | r] = function(c:M68000) {
				final addr = eaAddr(c, mode, reg, 2);
				if (c.faulted) return;
				operandFaultPc(c, mode, reg, 2, 0);

				final v = readMem(c, addr, 2);
				if (c.faulted) return;

				final res = shiftOp(c, ty, left, v, 1, 2);
				c.prefetch();
				writeBack(c, addr, 2, res);
			}
		}
	}

	public static function bitOps(t:Vector<M68000->Void>):Void {
		for (type in 0...4) for (dyn in 0...2) for (breg in 0...8) {
			if (dyn == 0 && breg != 0) continue;

			for (m in 0...8) for (r in 0...8) {
				final legal = if (type == 0) (m == 0 || (m >= 2 && (m != 7 || r <= (dyn == 1 ? 4 : 3)))) else
					dataAlterable(m, r);
				if (!legal) continue;

				final ty = type, mode = m, reg = r, bitReg = breg;
				final fromReg = dyn == 1;
				final head = type == 2 ? 4 : 2;

				final op = fromReg ? (0x0100 | (breg << 9) | (type << 6) | (m << 3) | r) : (0x0800 | (type << 6) | (m << 3) | r);

				t[op] = function(c:M68000) {
					final bitNum = fromReg ? (c.d[bitReg] & 63) : (c.fetchExt() & 63);

					if (mode == 0) {
						final b = bitNum & 31;
						final bit = 1 << b;
						final v = c.d[reg];
						c.zf = (v & bit) == 0;
						switch (ty) {
							case 1: c.d[reg] = v ^ bit;
							case 2: c.d[reg] = v & ~bit;
							case 3: c.d[reg] = v | bit;
							default:
						}
						c.prefetch();
						c.idle(ty == 0 ? 2 : (b < 16 ? head : head + 2));
						return;
					}

					final bit = 1 << (bitNum & 7);

					if (ty == 0) {
						final v = readEa(c, mode, reg, 1, fromReg ? 0 : 1);
						if (c.faulted) return;
						c.zf = (v & bit) == 0;
						c.prefetch();
						if (mode == 7 && reg == 4) c.idle(2);
						return;
					}

					final addr = eaAddr(c, mode, reg, 1);
					final v = c.readByte(addr, c.dataFc());
					c.zf = (v & bit) == 0;
					c.prefetch();
					c.writeByte(addr, c.dataFc(), switch (ty) {
						case 1: v ^ bit;
						case 2: v & ~bit;
						default: v | bit;
					});
				}
			}
		}
	}

	public static function tas(t:Vector<M68000->Void>):Void {
		for (m in 0...8) for (r in 0...8) {
			if (!dataAlterable(m, r)) continue;

			final mode = m, reg = r;

			t[0x4AC0 | (m << 3) | r] = function(c:M68000) {
				if (mode == 0) {
					final v = c.d[reg] & 0xFF;
					setLogicFlags(c, v, 1);
					c.d[reg] = (c.d[reg] & 0xFFFFFF00) | (v | 0x80);
					c.prefetch();
					return;
				}

				final addr = eaAddr(c, mode, reg, 1);
				final v = c.readByte(addr, c.dataFc());
				setLogicFlags(c, v, 1);
				c.idle(2);
				c.writeByte(addr, c.dataFc(), v | 0x80);
				c.prefetch();
			}
		}
	}
}

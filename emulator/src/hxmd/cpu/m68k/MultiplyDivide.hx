package hxmd.cpu.m68k;

import haxe.ds.Vector;
import hxmd.cpu.m68k.Addressing.*;
import hxmd.cpu.m68k.Flags.*;

class MultiplyDivide {
	static inline function mulUnsigned(a:Int, b:Int):Int {
		return (((a * ((b >> 8) & 0xFF)) << 8) + (a * (b & 0xFF))) | 0;
	}

	static inline function mulResult(a:Int, b:Int, signed:Bool):Int {
		var r = mulUnsigned(a & 0xFFFF, b & 0xFFFF);
		if (signed) {
			if ((a & 0x8000) != 0) r = (r - ((b & 0xFFFF) << 16)) | 0;
			if ((b & 0x8000) != 0) r = (r - ((a & 0xFFFF) << 16)) | 0;
		}
		return r;
	}

	static function mulSteps(src:Int, signed:Bool):Int {
		var n = 0;
		if (!signed) {
			for (i in 0...16) if ((src & (1 << i)) != 0) n++;
			return n;
		}
		final v = (src & 0xFFFF) << 1;
		for (i in 0...16) if (((v >> i) & 1) != ((v >> (i + 1)) & 1)) n++;
		return n;
	}

	public static function multiply(t:Vector<M68000->Void>):Void {
		for (signed in 0...2) for (dreg in 0...8) for (m in 0...8) for (r in 0...8) {
			if (m == 1 || (m == 7 && r > 4)) continue;

			final mode = m, reg = r, d = dreg;
			final sign = signed == 1;

			t[0xC0C0 | (signed << 8) | (dreg << 9) | (m << 3) | r] = function(c:M68000) {
				final src = readEa(c, mode, reg, 2, 0);
				if (c.faulted) return;

				final res = mulResult(src, c.d[d] & 0xFFFF, sign);
				c.d[d] = res;
				setLogicFlags(c, res, 4);
				c.prefetch();
				c.idle(34 + (mulSteps(src, sign) << 1));
			}
		}
	}

	static function divideResult(hi:Int, lo:Int, divisor:Int):Int {
		var rem = hi & 0xFFFF;
		var quo = 0;

		for (i in 0...16) {
			final top = (rem & 0x8000) != 0;
			rem = ((rem << 1) | ((lo >> (15 - i)) & 1)) & 0x1FFFF;
			final sub = top || rem >= divisor;
			if (sub) rem = (rem - divisor) & 0x1FFFF;
			quo = ((quo << 1) | (sub ? 1 : 0)) & 0xFFFF;
		}

		return (quo << 16) | (rem & 0xFFFF);
	}

	static function divideCounts(hi:Int, lo:Int, divisor:Int):Int {
		var rem = hi & 0xFFFF;
		var taken = 0;
		var carried = 0;

		for (i in 0...15) {
			final top = (rem & 0x8000) != 0;
			if (top) carried++;
			rem = ((rem << 1) | ((lo >> (15 - i)) & 1)) & 0x1FFFF;
			if (top || rem >= divisor) {
				rem = (rem - divisor) & 0x1FFFF;
				taken++;
			}
		}

		return (taken << 8) | carried;
	}

	static inline function overflowFlags(c:M68000):Void {
		c.nf = true;
		c.zf = false;
		c.vf = true;
		c.cf = false;
	}

	public static function divide(t:Vector<M68000->Void>):Void {
		for (signed in 0...2) for (dreg in 0...8) for (m in 0...8) for (r in 0...8) {
			if (m == 1 || (m == 7 && r > 4)) continue;

			final mode = m, reg = r, d = dreg;
			final sign = signed == 1;
			final back = extWords(m, r, 2) << 1;

			t[0x80C0 | (signed << 8) | (dreg << 9) | (m << 3) | r] = function(c:M68000) {
				final divisorRaw = readEa(c, mode, reg, 2, 0) & 0xFFFF;
				if (c.faulted) return;

				if (divisorRaw == 0) {
					c.exception(Exceptions.VEC_DIVIDE_BY_ZERO, (c.pcAtStart - 2 + back) | 0, 4);
					return;
				}

				final dividend = c.d[d];

				if (!sign) {
					final hi = (dividend >>> 16) & 0xFFFF;
					if (hi >= divisorRaw) {
						overflowFlags(c);
						c.idle(6);
						c.prefetch();
						return;
					}

					final counts = divideCounts(hi, dividend & 0xFFFF, divisorRaw);
					final packed = divideResult(hi, dividend & 0xFFFF, divisorRaw);
					final quotient = (packed >>> 16) & 0xFFFF;

					c.d[d] = ((packed & 0xFFFF) << 16) | quotient;
					c.nf = (quotient & 0x8000) != 0;
					c.zf = quotient == 0;
					c.vf = false;
					c.cf = false;

					c.idle(132 - ((counts >> 8) << 1) - ((counts & 0xFF) << 1));
					c.prefetch();
					return;
				}

				final divisor = signExt16(divisorRaw);
				final absDivisor = divisor < 0 ? -divisor : divisor;
				final negDividend = dividend < 0;
				final absDividend = negDividend ? (-dividend) | 0 : dividend;
				final hi = (absDividend >>> 16) & 0xFFFF;

				if (hi >= absDivisor) {
					overflowFlags(c);
					c.idle(negDividend ? 14 : 12);
					c.prefetch();
					return;
				}

				final counts = divideCounts(hi, absDividend & 0xFFFF, absDivisor);
				final base = negDividend ? (divisor < 0 ? 150 : 152) : (divisor < 0 ? 148 : 146);
				final packed = divideResult(hi, absDividend & 0xFFFF, absDivisor);

				final magnitude = (packed >>> 16) & 0xFFFF;
				final negQuotient = negDividend != (divisor < 0);
				final limit = negQuotient ? 0x8000 : 0x7FFF;

				c.idle(base - ((counts >> 8) << 1) - ((counts & 0xFF) << 1));

				if (magnitude > limit) {
					overflowFlags(c);
					c.prefetch();
					return;
				}

				final quotient = (negQuotient ? -magnitude : magnitude) & 0xFFFF;
				final remainder = negDividend ? ((-(packed & 0xFFFF)) & 0xFFFF) : (packed & 0xFFFF);

				c.d[d] = (remainder << 16) | quotient;
				c.nf = (quotient & 0x8000) != 0;
				c.zf = quotient == 0;
				c.vf = false;
				c.cf = false;
				c.prefetch();
			}
		}
	}
}

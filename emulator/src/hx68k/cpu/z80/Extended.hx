package hx68k.cpu.z80;

import haxe.ds.Vector;

class Extended {
	static var table:Null<Vector<Z80->Void>> = null;

	public static function execute(c:Z80):Void {
		if (table == null) table = build();
		c.previousQ = 0;
		final handler = table[c.fetch()];
		if (handler != null) handler(c);
	}

	static function build():Vector<Z80->Void> {
		final t = new Vector<Z80->Void>(256);
		for (i in 0...256) t[i] = null;

		for (index in 0...4) {
			final which = index;

			t[0x40 | (index << 4)] = function(c:Z80) input(c, (which << 1) | 0);
			t[0x48 | (index << 4)] = function(c:Z80) input(c, (which << 1) | 1);
			t[0x41 | (index << 4)] = function(c:Z80) output(c, (which << 1) | 0);
			t[0x49 | (index << 4)] = function(c:Z80) output(c, (which << 1) | 1);

			t[0x42 | (index << 4)] = function(c:Z80) {
				c.wz = (c.hl() + 1) & 0xFFFF;
				c.idle(7);
				c.setHl(subtractWord(c, c.hl(), c.pair(which)));
			}

			t[0x4A | (index << 4)] = function(c:Z80) {
				c.wz = (c.hl() + 1) & 0xFFFF;
				c.idle(7);
				c.setHl(addWord(c, c.hl(), c.pair(which)));
			}

			t[0x43 | (index << 4)] = function(c:Z80) {
				final at = c.immediateWord();
				final value = c.pair(which);
				c.write(at, value & 0xFF);
				c.write((at + 1) & 0xFFFF, (value >> 8) & 0xFF);
				c.wz = (at + 1) & 0xFFFF;
			}

			t[0x4B | (index << 4)] = function(c:Z80) {
				final at = c.immediateWord();
				final low = c.read(at);
				final high = c.read((at + 1) & 0xFFFF);
				c.setPair(which, low | (high << 8));
				c.wz = (at + 1) & 0xFFFF;
			}

			t[0x44 | (index << 4)] = function(c:Z80) negate(c);
			t[0x4C | (index << 4)] = function(c:Z80) negate(c);
			t[0x45 | (index << 4)] = function(c:Z80) returnFrom(c);
			t[0x4D | (index << 4)] = function(c:Z80) returnFrom(c);
		}

		t[0x46] = function(c:Z80) c.im = 0;
		t[0x4E] = function(c:Z80) c.im = 0;
		t[0x66] = function(c:Z80) c.im = 0;
		t[0x6E] = function(c:Z80) c.im = 0;
		t[0x56] = function(c:Z80) c.im = 1;
		t[0x76] = function(c:Z80) c.im = 1;
		t[0x5E] = function(c:Z80) c.im = 2;
		t[0x7E] = function(c:Z80) c.im = 2;

		t[0x47] = function(c:Z80) {
			c.idle(1);
			c.i = c.a;
		}
		t[0x4F] = function(c:Z80) {
			c.idle(1);
			c.r = c.a;
		}
		t[0x57] = function(c:Z80) {
			c.idle(1);
			c.a = c.i;
			special(c, c.a);
		}
		t[0x5F] = function(c:Z80) {
			c.idle(1);
			c.a = c.r;
			special(c, c.a);
		}

		t[0x67] = function(c:Z80) digits(c, false);
		t[0x6F] = function(c:Z80) digits(c, true);

		blocks(t);
		return t;
	}

	static function input(c:Z80, target:Int):Void {
		final at = c.bc();
		final value = c.bus.input(at);
		c.wz = (at + 1) & 0xFFFF;

		if (target != 6) c.setRegister(target, value);
		c.setF((c.f & Z80.CARRY) | (value & Z80.SIGN) | (value == 0 ? Z80.ZERO : 0) | c.bits(value)
			| (Z80.parity(value) ? Z80.PARITY : 0));
	}

	static function output(c:Z80, source:Int):Void {
		final at = c.bc();
		c.bus.output(at, source == 6 ? 0 : c.register(source));
		c.wz = (at + 1) & 0xFFFF;
	}

	static function addWord(c:Z80, left:Int, right:Int):Int {
		final carry = c.f & Z80.CARRY;
		final total = left + right + carry;
		final result = total & 0xFFFF;
		final half = (left & 0x0FFF) + (right & 0x0FFF) + carry;
		final overflow = (~(left ^ right) & (left ^ result) & 0x8000) != 0;

		c.setF(((result >> 8) & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result >> 8)
			| (half > 0x0FFF ? Z80.HALF : 0) | (overflow ? Z80.PARITY : 0)
			| (total > 0xFFFF ? Z80.CARRY : 0));
		return result;
	}

	static function subtractWord(c:Z80, left:Int, right:Int):Int {
		final carry = c.f & Z80.CARRY;
		final total = left - right - carry;
		final result = total & 0xFFFF;
		final half = (left & 0x0FFF) - (right & 0x0FFF) - carry;
		final overflow = ((left ^ right) & (left ^ result) & 0x8000) != 0;

		c.setF(((result >> 8) & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result >> 8)
			| (half < 0 ? Z80.HALF : 0) | (overflow ? Z80.PARITY : 0) | Z80.SUBTRACT
			| (total < 0 ? Z80.CARRY : 0));
		return result;
	}

	static function negate(c:Z80):Void {
		final value = c.a;
		c.a = 0;
		Arithmetic.subtract(c, value, 0);
	}

	static function returnFrom(c:Z80):Void {
		c.pc = c.pop();
		c.wz = c.pc;
		c.iff1 = c.iff2;
	}

	static function special(c:Z80, value:Int):Void {
		c.p = 1;
		c.setF((c.f & Z80.CARRY) | (value & Z80.SIGN) | (value == 0 ? Z80.ZERO : 0) | c.bits(value)
			| (c.iff2 ? Z80.PARITY : 0));
	}

	static function digits(c:Z80, left:Bool):Void {
		final at = c.hl();
		final value = c.read(at);
		c.idle(4);

		final written = left
			? ((value << 4) | (c.a & 0x0F)) & 0xFF
			: ((value >> 4) | ((c.a & 0x0F) << 4)) & 0xFF;
		c.a = left
			? (c.a & 0xF0) | ((value >> 4) & 0x0F)
			: (c.a & 0xF0) | (value & 0x0F);

		c.write(at, written);
		c.wz = (at + 1) & 0xFFFF;

		c.setF((c.f & Z80.CARRY) | (c.a & Z80.SIGN) | (c.a == 0 ? Z80.ZERO : 0) | c.bits(c.a)
			| (Z80.parity(c.a) ? Z80.PARITY : 0));
	}

	static function blocks(t:Vector<Z80->Void>):Void {
		for (index in 0...4) {
			final forward = (index & 1) == 0;
			final repeats = index >= 2;

			t[0xA0 | (index << 3)] = function(c:Z80) move(c, forward, repeats);
			t[0xA1 | (index << 3)] = function(c:Z80) search(c, forward, repeats);
			t[0xA2 | (index << 3)] = function(c:Z80) readPort(c, forward, repeats);
			t[0xA3 | (index << 3)] = function(c:Z80) writePort(c, forward, repeats);
		}
	}

	static function move(c:Z80, forward:Bool, repeats:Bool):Void {
		final value = c.read(c.hl());
		c.write(c.de(), value);
		c.idle(2);

		c.setHl((c.hl() + (forward ? 1 : -1)) & 0xFFFF);
		c.setDe((c.de() + (forward ? 1 : -1)) & 0xFFFF);
		c.setBc((c.bc() - 1) & 0xFFFF);

		final loose = (value + c.a) & 0xFF;
		c.setF((c.f & (Z80.SIGN | Z80.ZERO | Z80.CARRY))
			| ((loose & 0x02) != 0 ? Z80.Y : 0) | ((loose & 0x08) != 0 ? Z80.X : 0)
			| (c.bc() != 0 ? Z80.PARITY : 0));

		if (repeats && c.bc() != 0) {
			c.idle(5);
			c.pc = (c.pc - 2) & 0xFFFF;
			c.wz = (c.pc + 1) & 0xFFFF;
			again(c);
		}
	}

	static function search(c:Z80, forward:Bool, repeats:Bool):Void {
		final value = c.read(c.hl());
		c.idle(5);

		final result = (c.a - value) & 0xFF;
		final half = (c.a & 0x0F) - (value & 0x0F) < 0;
		final loose = (result - (half ? 1 : 0)) & 0xFF;

		c.setHl((c.hl() + (forward ? 1 : -1)) & 0xFFFF);
		c.setBc((c.bc() - 1) & 0xFFFF);

		c.setF((c.f & Z80.CARRY) | (result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0)
			| (half ? Z80.HALF : 0) | ((loose & 0x02) != 0 ? Z80.Y : 0)
			| ((loose & 0x08) != 0 ? Z80.X : 0) | (c.bc() != 0 ? Z80.PARITY : 0) | Z80.SUBTRACT);

		c.wz = (c.wz + (forward ? 1 : -1)) & 0xFFFF;

		if (repeats && c.bc() != 0 && result != 0) {
			c.idle(5);
			c.pc = (c.pc - 2) & 0xFFFF;
			c.wz = (c.pc + 1) & 0xFFFF;
			again(c);
		}
	}

	static function readPort(c:Z80, forward:Bool, repeats:Bool):Void {
		c.idle(1);
		final at = c.bc();
		final value = c.bus.input(at);
		c.write(c.hl(), value);

		c.b = (c.b - 1) & 0xFF;
		c.wz = (at + (forward ? 1 : -1)) & 0xFFFF;
		c.setHl((c.hl() + (forward ? 1 : -1)) & 0xFFFF);

		portFlags(c, value, (c.c + (forward ? 1 : -1)) & 0xFF);
		if (repeats && c.b != 0) repeated(c, value);
	}

	static function writePort(c:Z80, forward:Bool, repeats:Bool):Void {
		c.idle(1);
		final value = c.read(c.hl());

		c.b = (c.b - 1) & 0xFF;
		final at = c.bc();
		c.bus.output(at, value);

		c.setHl((c.hl() + (forward ? 1 : -1)) & 0xFFFF);
		c.wz = (at + (forward ? 1 : -1)) & 0xFFFF;

		portFlags(c, value, c.l);
		if (repeats && c.b != 0) repeated(c, value);
	}

	static function repeated(c:Z80, value:Int):Void {
		c.idle(5);
		c.pc = (c.pc - 2) & 0xFFFF;
		c.wz = (c.pc + 1) & 0xFFFF;

		var half = (c.f & Z80.HALF) != 0;
		var even = (c.f & Z80.PARITY) != 0;

		if ((c.f & Z80.CARRY) != 0) {
			if ((value & 0x80) != 0) {
				half = (c.b & 0x0F) == 0x00;
				even = even != !Z80.parity((c.b - 1) & 7);
			} else {
				half = (c.b & 0x0F) == 0x0F;
				even = even != !Z80.parity((c.b + 1) & 7);
			}
		} else {
			even = even != !Z80.parity(c.b & 7);
		}

		c.setF((c.f & ~(Z80.HALF | Z80.PARITY | Z80.Y | Z80.X)) | (half ? Z80.HALF : 0)
			| (even ? Z80.PARITY : 0) | ((c.pc >> 8) & (Z80.Y | Z80.X)));
	}

	static function again(c:Z80):Void {
		c.setF((c.f & ~(Z80.Y | Z80.X)) | ((c.pc >> 8) & (Z80.Y | Z80.X)));
	}

	static function portFlags(c:Z80, value:Int, other:Int):Void {
		final total = value + other;

		c.setF((c.b & Z80.SIGN) | (c.b == 0 ? Z80.ZERO : 0) | c.bits(c.b)
			| (total > 0xFF ? (Z80.HALF | Z80.CARRY) : 0)
			| (Z80.parity((total & 7) ^ c.b) ? Z80.PARITY : 0)
			| ((value & 0x80) != 0 ? Z80.SUBTRACT : 0));
	}
}

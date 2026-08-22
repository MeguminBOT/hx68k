package hx68k.cpu.z80;

import haxe.ds.Vector;

class Bits {
	static var table:Null<Vector<Z80->Void>> = null;

	public static function execute(c:Z80):Void {
		if (table == null) table = build();
		c.previousQ = 0;
		table[c.fetch()](c);
	}

	static function build():Vector<Z80->Void> {
		final t = new Vector<Z80->Void>(256);

		for (op in 0...0x40) {
			final kind = (op >> 3) & 7;
			final target = op & 7;

			t[op] = function(c:Z80) {
				if (target == 6) {
					final at = c.hl();
					final value = c.read(at);
					c.idle(1);
					c.write(at, rotate(c, kind, value));
				} else {
					c.setRegister(target, rotate(c, kind, c.register(target)));
				}
			}
		}

		for (op in 0x40...0x80) {
			final bit = (op >> 3) & 7;
			final target = op & 7;

			t[op] = function(c:Z80) {
				var value:Int;
				var loose:Int;

				if (target == 6) {
					value = c.read(c.hl());
					c.idle(1);
					loose = (c.wz >> 8) & (Z80.Y | Z80.X);
				} else {
					value = c.register(target);
					loose = value & (Z80.Y | Z80.X);
				}

				final set = (value & (1 << bit)) != 0;
				c.setF((c.f & Z80.CARRY) | Z80.HALF | loose
					| (set ? 0 : (Z80.ZERO | Z80.PARITY))
					| (set && bit == 7 ? Z80.SIGN : 0));
			}
		}

		for (op in 0x80...0x100) {
			final mask = 1 << ((op >> 3) & 7);
			final target = op & 7;
			final set = op >= 0xC0;

			t[op] = function(c:Z80) {
				if (target == 6) {
					final at = c.hl();
					final value = c.read(at);
					c.idle(1);
					c.write(at, set ? value | mask : value & ~mask);
				} else {
					final value = c.register(target);
					c.setRegister(target, set ? value | mask : value & ~mask);
				}
			}
		}

		return t;
	}

	public static function rotate(c:Z80, kind:Int, value:Int):Int {
		final carry = switch (kind) {
			case 0, 2, 4, 6: (value >> 7) & 1;
			case _: value & 1;
		}

		final result = switch (kind) {
			case 0: ((value << 1) | carry) & 0xFF;
			case 1: ((value >> 1) | (carry << 7)) & 0xFF;
			case 2: ((value << 1) | (c.f & Z80.CARRY)) & 0xFF;
			case 3: ((value >> 1) | ((c.f & Z80.CARRY) << 7)) & 0xFF;
			case 4: (value << 1) & 0xFF;
			case 5: ((value >> 1) | (value & 0x80)) & 0xFF;
			case 6: ((value << 1) | 1) & 0xFF;
			case _: (value >> 1) & 0xFF;
		}

		c.setF((result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result)
			| (Z80.parity(result) ? Z80.PARITY : 0) | carry);
		return result;
	}
}

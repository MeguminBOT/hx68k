package hx68k.cpu.z80;

import haxe.ds.Vector;

class Decoder {
	static var shared:Null<Vector<Z80->Void>> = null;

	public static function run(c:Z80, op:Int):Void {
		if (shared == null) shared = build();
		final handler = shared[op];
		if (handler != null) handler(c);
	}

	public static function build():Vector<Z80->Void> {
		if (shared != null) return shared;
		final t = new Vector<Z80->Void>(256);
		for (i in 0...256) t[i] = null;

		t[0x00] = function(c:Z80) {};
		t[0x76] = function(c:Z80) c.halted = true;
		t[0xCB] = function(c:Z80) Bits.execute(c);
		t[0xED] = function(c:Z80) Extended.execute(c);
		t[0xDD] = function(c:Z80) Indexed.execute(c, 0);
		t[0xFD] = function(c:Z80) Indexed.execute(c, 1);

		loads(t);
		arithmetic(t);
		counters(t);
		words(t);
		jumps(t);
		stack(t);
		exchanges(t);
		accumulator(t);
		ports(t);

		return t;
	}

	static function loads(t:Vector<Z80->Void>):Void {
		for (op in 0x40...0x80) {
			if (op == 0x76) continue;
			final to = (op >> 3) & 7;
			final from = op & 7;
			t[op] = function(c:Z80) c.setRegister(to, c.register(from));
		}

		for (index in 0...8) {
			final to = index;
			t[0x06 | (index << 3)] = function(c:Z80) c.setRegister(to, c.immediate());
		}

		t[0x0A] = function(c:Z80) {
			c.a = c.read(c.bc());
			c.wz = (c.bc() + 1) & 0xFFFF;
		}
		t[0x1A] = function(c:Z80) {
			c.a = c.read(c.de());
			c.wz = (c.de() + 1) & 0xFFFF;
		}
		t[0x02] = function(c:Z80) {
			c.write(c.bc(), c.a);
			c.wz = ((c.a << 8) | ((c.bc() + 1) & 0xFF)) & 0xFFFF;
		}
		t[0x12] = function(c:Z80) {
			c.write(c.de(), c.a);
			c.wz = ((c.a << 8) | ((c.de() + 1) & 0xFF)) & 0xFFFF;
		}

		t[0x3A] = function(c:Z80) {
			final at = c.immediateWord();
			c.a = c.read(at);
			c.wz = (at + 1) & 0xFFFF;
		}
		t[0x32] = function(c:Z80) {
			final at = c.immediateWord();
			c.write(at, c.a);
			c.wz = ((c.a << 8) | ((at + 1) & 0xFF)) & 0xFFFF;
		}

		t[0x2A] = function(c:Z80) {
			final at = c.immediateWord();
			c.l = c.read(at);
			c.h = c.read((at + 1) & 0xFFFF);
			c.wz = (at + 1) & 0xFFFF;
		}
		t[0x22] = function(c:Z80) {
			final at = c.immediateWord();
			c.write(at, c.l);
			c.write((at + 1) & 0xFFFF, c.h);
			c.wz = (at + 1) & 0xFFFF;
		}
	}

	static function arithmetic(t:Vector<Z80->Void>):Void {
		for (op in 0x80...0xC0) {
			final kind = (op >> 3) & 7;
			final from = op & 7;
			t[op] = function(c:Z80) apply(c, kind, c.register(from));
		}

		for (kind in 0...8) {
			final which = kind;
			t[0xC6 | (kind << 3)] = function(c:Z80) apply(c, which, c.immediate());
		}
	}

	public static function apply(c:Z80, kind:Int, value:Int):Void {
		switch (kind) {
			case 0: Arithmetic.add(c, value, 0);
			case 1: Arithmetic.add(c, value, c.f & Z80.CARRY);
			case 2: Arithmetic.subtract(c, value, 0);
			case 3: Arithmetic.subtract(c, value, c.f & Z80.CARRY);
			case 4: Arithmetic.and(c, value);
			case 5: Arithmetic.xor(c, value);
			case 6: Arithmetic.or(c, value);
			case _: Arithmetic.compare(c, value);
		}
	}

	static function counters(t:Vector<Z80->Void>):Void {
		for (index in 0...8) {
			final which = index;

			t[0x04 | (index << 3)] = function(c:Z80) {
				if (which == 6) {
					final at = c.hl();
					final value = c.read(at);
					c.idle(1);
					c.write(at, Arithmetic.increment(c, value));
				} else {
					c.setRegister(which, Arithmetic.increment(c, c.register(which)));
				}
			}

			t[0x05 | (index << 3)] = function(c:Z80) {
				if (which == 6) {
					final at = c.hl();
					final value = c.read(at);
					c.idle(1);
					c.write(at, Arithmetic.decrement(c, value));
				} else {
					c.setRegister(which, Arithmetic.decrement(c, c.register(which)));
				}
			}
		}
	}

	static function words(t:Vector<Z80->Void>):Void {
		for (index in 0...4) {
			final which = index;

			t[0x01 | (index << 4)] = function(c:Z80) c.setPair(which, c.immediateWord());

			t[0x03 | (index << 4)] = function(c:Z80) {
				c.idle(2);
				c.setPair(which, (c.pair(which) + 1) & 0xFFFF);
			}

			t[0x0B | (index << 4)] = function(c:Z80) {
				c.idle(2);
				c.setPair(which, (c.pair(which) - 1) & 0xFFFF);
			}

			t[0x09 | (index << 4)] = function(c:Z80) {
				c.wz = (c.hl() + 1) & 0xFFFF;
				c.idle(7);
				c.setHl(Arithmetic.addWord(c, c.hl(), c.pair(which)));
			}
		}
	}

	static function jumps(t:Vector<Z80->Void>):Void {
		t[0xC3] = function(c:Z80) {
			final at = c.immediateWord();
			c.pc = at;
			c.wz = at;
		}

		for (index in 0...8) {
			final which = index;
			t[0xC2 | (index << 3)] = function(c:Z80) {
				final at = c.immediateWord();
				c.wz = at;
				if (c.condition(which)) c.pc = at;
			}
		}

		t[0x18] = function(c:Z80) {
			final step = signed(c.immediate());
			c.idle(5);
			c.pc = (c.pc + step) & 0xFFFF;
			c.wz = c.pc;
		}

		for (index in 0...4) {
			final which = index;
			t[0x20 | (index << 3)] = function(c:Z80) {
				final step = signed(c.immediate());
				if (!c.condition(which)) return;
				c.idle(5);
				c.pc = (c.pc + step) & 0xFFFF;
				c.wz = c.pc;
			}
		}

		t[0x10] = function(c:Z80) {
			c.idle(1);
			final step = signed(c.immediate());
			c.b = (c.b - 1) & 0xFF;
			if (c.b == 0) return;
			c.idle(5);
			c.pc = (c.pc + step) & 0xFFFF;
			c.wz = c.pc;
		}

		t[0xE9] = function(c:Z80) c.pc = c.hl();

		t[0xCD] = function(c:Z80) {
			final at = c.immediateWord();
			c.wz = at;
			c.idle(1);
			c.push(c.pc);
			c.pc = at;
		}

		for (index in 0...8) {
			final which = index;
			t[0xC4 | (index << 3)] = function(c:Z80) {
				final at = c.immediateWord();
				c.wz = at;
				if (!c.condition(which)) return;
				c.idle(1);
				c.push(c.pc);
				c.pc = at;
			}
		}

		t[0xC9] = function(c:Z80) {
			c.pc = c.pop();
			c.wz = c.pc;
		}

		for (index in 0...8) {
			final which = index;
			t[0xC0 | (index << 3)] = function(c:Z80) {
				c.idle(1);
				if (!c.condition(which)) return;
				c.pc = c.pop();
				c.wz = c.pc;
			}
		}

		for (index in 0...8) {
			final target = index * 8;
			t[0xC7 | (index << 3)] = function(c:Z80) {
				c.idle(1);
				c.push(c.pc);
				c.pc = target;
				c.wz = target;
			}
		}
	}

	static function stack(t:Vector<Z80->Void>):Void {
		for (index in 0...4) {
			final which = index;

			t[0xC5 | (index << 4)] = function(c:Z80) {
				c.idle(1);
				c.push(which == 3 ? c.af() : c.pair(which));
			}

			t[0xC1 | (index << 4)] = function(c:Z80) {
				final value = c.pop();
				if (which == 3) c.setAf(value) else c.setPair(which, value);
			}
		}
	}

	static function exchanges(t:Vector<Z80->Void>):Void {
		t[0xEB] = function(c:Z80) {
			final held = c.de();
			c.setDe(c.hl());
			c.setHl(held);
		}

		t[0x08] = function(c:Z80) {
			final held = c.af();
			c.setAf(c.af2);
			c.af2 = held;
		}

		t[0xD9] = function(c:Z80) {
			var held = c.bc();
			c.setBc(c.bc2);
			c.bc2 = held;

			held = c.de();
			c.setDe(c.de2);
			c.de2 = held;

			held = c.hl();
			c.setHl(c.hl2);
			c.hl2 = held;
		}

		t[0xE3] = function(c:Z80) {
			final low = c.read(c.sp);
			final high = c.read((c.sp + 1) & 0xFFFF);
			c.idle(1);
			c.write((c.sp + 1) & 0xFFFF, c.h);
			c.write(c.sp, c.l);
			c.idle(2);
			c.setHl(low | (high << 8));
			c.wz = c.hl();
		}

		t[0xF9] = function(c:Z80) {
			c.idle(2);
			c.sp = c.hl();
		}
	}

	static function accumulator(t:Vector<Z80->Void>):Void {
		t[0x07] = function(c:Z80) Arithmetic.rotateLeftCircular(c);
		t[0x0F] = function(c:Z80) Arithmetic.rotateRightCircular(c);
		t[0x17] = function(c:Z80) Arithmetic.rotateLeft(c);
		t[0x1F] = function(c:Z80) Arithmetic.rotateRight(c);
		t[0x27] = function(c:Z80) Arithmetic.decimal(c);
		t[0x2F] = function(c:Z80) Arithmetic.complement(c);
		t[0x37] = function(c:Z80) Arithmetic.setCarry(c);
		t[0x3F] = function(c:Z80) Arithmetic.complementCarry(c);

		t[0xF3] = function(c:Z80) {
			c.iff1 = false;
			c.iff2 = false;
		}

		t[0xFB] = function(c:Z80) {
			c.iff1 = true;
			c.iff2 = true;
			c.ei = true;
		}
	}

	static function ports(t:Vector<Z80->Void>):Void {
		t[0xDB] = function(c:Z80) {
			final port = c.immediate();
			final at = (c.a << 8) | port;
			c.a = c.bus.input(at);
			c.wz = (at + 1) & 0xFFFF;
		}

		t[0xD3] = function(c:Z80) {
			final port = c.immediate();
			final at = (c.a << 8) | port;
			c.bus.output(at, c.a);
			c.wz = ((c.a << 8) | ((port + 1) & 0xFF)) & 0xFFFF;
		}
	}

	static inline function signed(value:Int):Int {
		return value >= 0x80 ? value - 0x100 : value;
	}
}

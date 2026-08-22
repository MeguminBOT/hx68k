package hx68k.cpu.z80;

class Indexed {
	public static function execute(c:Z80, which:Int):Void {
		c.previousQ = 0;
		final op = c.fetch();

		switch (op) {
			case 0xDD: execute(c, 0);
			case 0xFD: execute(c, 1);
			case 0xED: Extended.execute(c);
			case 0xCB: page(c, which);
			case _: one(c, which, op);
		}
	}

	static function one(c:Z80, which:Int, op:Int):Void {
		if (op >= 0x40 && op < 0x80 && op != 0x76) {
			final to = (op >> 3) & 7;
			final from = op & 7;

			if (to == 6) {
				c.write(address(c, which), c.register(from));
			} else if (from == 6) {
				c.setRegister(to, c.read(address(c, which)));
			} else {
				write(c, which, to, read(c, which, from));
			}
			return;
		}

		if (op >= 0x80 && op < 0xC0) {
			final kind = (op >> 3) & 7;
			final from = op & 7;
			Decoder.apply(c, kind, from == 6 ? c.read(address(c, which)) : read(c, which, from));
			return;
		}

		switch (op) {
			case 0x09, 0x19, 0x29, 0x39: {
				final index = (op >> 4) & 3;
				c.wz = (value(c, which) + 1) & 0xFFFF;
				c.idle(7);
				setValue(c, which, Arithmetic.addWord(c, value(c, which),
					index == 2 ? value(c, which) : c.pair(index)));
			}

			case 0x21: setValue(c, which, c.immediateWord());

			case 0x22: {
				final at = c.immediateWord();
				c.write(at, low(c, which));
				c.write((at + 1) & 0xFFFF, high(c, which));
				c.wz = (at + 1) & 0xFFFF;
			}

			case 0x2A: {
				final at = c.immediateWord();
				final held = c.read(at) | (c.read((at + 1) & 0xFFFF) << 8);
				setValue(c, which, held);
				c.wz = (at + 1) & 0xFFFF;
			}

			case 0x23: {
				c.idle(2);
				setValue(c, which, (value(c, which) + 1) & 0xFFFF);
			}

			case 0x2B: {
				c.idle(2);
				setValue(c, which, (value(c, which) - 1) & 0xFFFF);
			}

			case 0x24, 0x2C: {
				final half = (op >> 3) & 7;
				write(c, which, half, Arithmetic.increment(c, read(c, which, half)));
			}

			case 0x25, 0x2D: {
				final half = (op >> 3) & 7;
				write(c, which, half, Arithmetic.decrement(c, read(c, which, half)));
			}

			case 0x26, 0x2E: write(c, which, (op >> 3) & 7, c.immediate());

			case 0x34: {
				final at = address(c, which);
				final held = c.read(at);
				c.idle(1);
				c.write(at, Arithmetic.increment(c, held));
			}

			case 0x35: {
				final at = address(c, which);
				final held = c.read(at);
				c.idle(1);
				c.write(at, Arithmetic.decrement(c, held));
			}

			case 0x36: {
				final step = signed(c.immediate());
				final held = c.immediate();
				c.idle(2);
				final at = (value(c, which) + step) & 0xFFFF;
				c.wz = at;
				c.write(at, held);
			}

			case 0xE1: setValue(c, which, c.pop());

			case 0xE5: {
				c.idle(1);
				c.push(value(c, which));
			}

			case 0xE3: {
				final low = c.read(c.sp);
				final high = c.read((c.sp + 1) & 0xFFFF);
				c.idle(1);
				c.write((c.sp + 1) & 0xFFFF, (value(c, which) >> 8) & 0xFF);
				c.write(c.sp, value(c, which) & 0xFF);
				c.idle(2);
				setValue(c, which, low | (high << 8));
				c.wz = value(c, which);
			}

			case 0xE9: c.pc = value(c, which);

			case 0xF9: {
				c.idle(2);
				c.sp = value(c, which);
			}

			case _: Decoder.run(c, op);
		}
	}

	static function page(c:Z80, which:Int):Void {
		final step = signed(c.immediate());
		final op = c.immediate();
		c.idle(2);

		final at = (value(c, which) + step) & 0xFFFF;
		c.wz = at;

		final kind = op >> 6;
		final bit = (op >> 3) & 7;
		final target = op & 7;
		final held = c.read(at);

		if (kind == 1) {
			c.idle(1);
			final set = (held & (1 << bit)) != 0;
			c.setF((c.f & Z80.CARRY) | Z80.HALF | ((at >> 8) & (Z80.Y | Z80.X))
				| (set ? 0 : (Z80.ZERO | Z80.PARITY)) | (set && bit == 7 ? Z80.SIGN : 0));
			return;
		}

		c.idle(1);
		final result = switch (kind) {
			case 0: Bits.rotate(c, (op >> 3) & 7, held);
			case 2: held & ~(1 << bit);
			case _: held | (1 << bit);
		}

		c.write(at, result);
		if (target != 6) c.setRegister(target, result);
	}

	static function address(c:Z80, which:Int):Int {
		final step = signed(c.immediate());
		c.idle(5);
		final at = (value(c, which) + step) & 0xFFFF;
		c.wz = at;
		return at;
	}

	static inline function value(c:Z80, which:Int):Int {
		return which == 0 ? c.ix : c.iy;
	}

	static inline function setValue(c:Z80, which:Int, held:Int):Void {
		if (which == 0) c.ix = held & 0xFFFF else c.iy = held & 0xFFFF;
	}

	static inline function high(c:Z80, which:Int):Int {
		return (value(c, which) >> 8) & 0xFF;
	}

	static inline function low(c:Z80, which:Int):Int {
		return value(c, which) & 0xFF;
	}

	static function read(c:Z80, which:Int, index:Int):Int {
		return switch (index) {
			case 4: high(c, which);
			case 5: low(c, which);
			case _: c.register(index);
		}
	}

	static function write(c:Z80, which:Int, index:Int, held:Int):Void {
		switch (index) {
			case 4: setValue(c, which, ((held & 0xFF) << 8) | low(c, which));
			case 5: setValue(c, which, (high(c, which) << 8) | (held & 0xFF));
			case _: c.setRegister(index, held);
		}
	}

	static inline function signed(held:Int):Int {
		return held >= 0x80 ? held - 0x100 : held;
	}
}

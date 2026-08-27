package hx68k.cpu.m68k;

class Addressing {
	public static inline function signExt8(value:Int):Int {
		return (value & 0x80) != 0 ? value | 0xFFFFFF00 : value & 0xFF;
	}

	public static inline function signExt16(value:Int):Int {
		return (value & 0x8000) != 0 ? value | 0xFFFF0000 : value & 0xFFFF;
	}

	public static inline function mask(size:Int):Int {
		return size == 1 ? 0xFF : (size == 2 ? 0xFFFF : -1);
	}

	public static inline function msb(size:Int):Int {
		return size == 1 ? 0x80 : (size == 2 ? 0x8000 : 0x80000000);
	}

	public static inline function dataAlterable(m:Int, r:Int):Bool {
		if (m == 1) return false;
		if (m == 7) return r <= 1;
		return true;
	}

	public static inline function memAlterable(m:Int, r:Int):Bool {
		if (m < 2) return false;
		if (m == 7) return r <= 1;
		return true;
	}

	public static inline function control(m:Int, r:Int):Bool {
		if (m == 2 || m == 5 || m == 6) return true;
		return m == 7 && r <= 3;
	}

	public static inline function controlExt(m:Int, r:Int):Int {
		if (m == 2) return 0;
		return (m == 7 && r == 1) ? 2 : 1;
	}

	public static function eaAddr(c:M68000, mode:Int, reg:Int, size:Int):Int {
		switch (mode) {
			case 2:
				return c.a[reg] | 0;
			case 3:
				final addr = c.a[reg];
				if (size == 4 && (addr & 1) != 0) return addr | 0;
				final step = (reg == 7 && size == 1) ? 2 : size;
				c.a[reg] = (addr + step) | 0;
				return addr | 0;
			case 4:
				c.idle(2);
				final step = (reg == 7 && size == 1) ? 2 : size;
				c.a[reg] = (c.a[reg] - step) | 0;
				return c.a[reg] | 0;
			case 5:
				final base = c.a[reg];
				return (base + signExt16(c.fetchExt())) | 0;
			case 6:
				final base = c.a[reg];
				c.idle(2);
				return (base + brief(c, c.fetchExt())) | 0;
			case 7:
				switch (reg) {
					case 0:
						return signExt16(c.fetchExt()) | 0;
					case 1:
						final hi = c.fetchExt();
						final lo = c.fetchExt();
						return ((hi << 16) | lo) | 0;
					case 2:
						final base = c.extAddr();
						return (base + signExt16(c.fetchExt())) | 0;
					case 3:
						final base = c.extAddr();
						c.idle(2);
						return (base + brief(c, c.fetchExt())) | 0;
					default:
						return 0;
				}
			default:
				return 0;
		}
	}

	public static inline function brief(c:M68000, ext:Int):Int {
		final r = (ext >> 12) & 7;
		var index = ((ext & 0x8000) != 0) ? c.a[r] : c.d[r];
		if ((ext & 0x0800) == 0) index = signExt16(index & 0xFFFF);
		return index + signExt8(ext & 0xFF);
	}

	public static inline function extWords(mode:Int, reg:Int, size:Int):Int {
		if (mode == 5 || mode == 6) return 1;
		if (mode != 7) return 0;
		return switch (reg) {
			case 0, 2, 3: 1;
			case 1: 2;
			case 4: size == 4 ? 2 : 1;
			default: 0;
		}
	}

	public static inline function operandFaultPc(c:M68000, mode:Int, reg:Int, size:Int, pre:Int):Void {
		final p = (c.pcAtStart + (pre << 1)) | 0;
		c.faultPc = if (mode == 7) (reg == 0 ? p : (reg == 1 ? (p + 2) | 0 : (p - 2) | 0)) else if (mode == 4
			&& size != 4) p else (p - 2) | 0;
	}

	public static function readEa(c:M68000, mode:Int, reg:Int, size:Int, pre:Int):Int {
		switch (mode) {
			case 0:
				return c.d[reg] & mask(size);
			case 1:
				return size == 2 ? (c.a[reg] & 0xFFFF) : (c.a[reg] & mask(size));
			case 7 if (reg == 4):
				if (size == 4) {
					final hi = c.fetchExt();
					final lo = c.fetchExt();
					return (hi << 16) | lo;
				}
				final value = c.fetchExt();
				return size == 1 ? (value & 0xFF) : (value & 0xFFFF);
			default:
				final addr = eaAddr(c, mode, reg, size);
				if (c.faulted) return 0;
				operandFaultPc(c, mode, reg, size, pre);
				final fc = (mode == 7 && reg >= 2) ? c.progFc() : c.dataFc();
				return switch (size) {
					case 1: c.readByte(addr, fc);
					case 2: c.readWord(addr, fc);
					default: c.readLong(addr, fc);
				}
		}
	}

	public static inline function readMem(c:M68000, addr:Int, size:Int):Int {
		return switch (size) {
			case 1: c.readByte(addr, c.dataFc());
			case 2: c.readWord(addr, c.dataFc());
			default: c.readLong(addr, c.dataFc());
		}
	}

	public static function writeMem(c:M68000, addr:Int, size:Int, value:Int):Void {
		switch (size) {
			case 1: c.writeByte(addr, c.dataFc(), value);
			case 2: c.writeWord(addr, c.dataFc(), value);
			default: c.writeLong(addr, c.dataFc(), value);
		}
	}

	public static inline function writeBack(c:M68000, addr:Int, size:Int, value:Int):Void {
		switch (size) {
			case 1: c.writeByte(addr, c.dataFc(), value);
			case 2: c.writeWord(addr, c.dataFc(), value);
			default: c.writeLongLowFirst(addr, c.dataFc(), value);
		}
	}

	public static function writeReg(c:M68000, reg:Int, size:Int, value:Int):Void {
		switch (size) {
			case 1: c.d[reg] = (c.d[reg] & 0xFFFFFF00) | (value & 0xFF);
			case 2: c.d[reg] = (c.d[reg] & 0xFFFF0000) | (value & 0xFFFF);
			default: c.d[reg] = value | 0;
		}
	}

	public static function jumpTarget(c:M68000, mode:Int, reg:Int):Int {
		switch (mode) {
			case 2:
				return c.a[reg] | 0;
			case 5:
				c.idle(2);
				return (c.a[reg] + signExt16(c.irc)) | 0;
			case 6:
				c.idle(6);
				return (c.a[reg] + brief(c, c.irc)) | 0;
			default:
				switch (reg) {
					case 0:
						c.idle(2);
						return signExt16(c.irc) | 0;
					case 1:
						final hi = c.irc;
						final lo = c.bus.read(c.pc & 0xFFFFFE, c.progFc(), true, true) & 0xFFFF;
						c.pc = (c.pc + 2) | 0;
						return ((hi << 16) | lo) | 0;
					case 2:
						c.idle(2);
						return (c.extAddr() + signExt16(c.irc)) | 0;
					default:
						c.idle(6);
						return (c.extAddr() + brief(c, c.irc)) | 0;
				}
		}
	}

	public static inline function push32(c:M68000, value:Int):Void {
		final sp = (c.a[7] - 4) | 0;
		c.a[7] = sp;
		c.writeWord(sp, c.dataFc(), (value >>> 16) & 0xFFFF);
		if (c.faulted) return;
		c.writeWord((sp + 2) | 0, c.dataFc(), value & 0xFFFF);
	}
}

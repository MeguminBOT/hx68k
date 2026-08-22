package hx68k.cpu.z80;

import haxe.ds.Vector;

class Z80 {
	public static inline final SIGN = 0x80;
	public static inline final ZERO = 0x40;
	public static inline final Y = 0x20;
	public static inline final HALF = 0x10;
	public static inline final X = 0x08;
	public static inline final PARITY = 0x04;
	public static inline final SUBTRACT = 0x02;
	public static inline final CARRY = 0x01;

	public var a:Int = 0;
	public var f:Int = 0;
	public var b:Int = 0;
	public var c:Int = 0;
	public var d:Int = 0;
	public var e:Int = 0;
	public var h:Int = 0;
	public var l:Int = 0;

	public var af2:Int = 0;
	public var bc2:Int = 0;
	public var de2:Int = 0;
	public var hl2:Int = 0;

	public var ix:Int = 0;
	public var iy:Int = 0;
	public var sp:Int = 0;
	public var pc:Int = 0;
	public var wz:Int = 0;

	public var i:Int = 0;
	public var r:Int = 0;

	public var iff1:Bool = false;
	public var iff2:Bool = false;
	public var im:Int = 0;
	public var ei:Bool = false;
	public var halted:Bool = false;

	public var q:Int = 0;

	public var p:Int = 0;

	public var previousQ:Int = 0;

	public var bus:Bus;

	static var table:Null<Vector<Z80->Void>> = null;

	public function new(bus:Bus) {
		this.bus = bus;
		if (table == null) table = Decoder.build();
	}

	public function step():Void {
		p = 0;
		previousQ = q;
		q = 0;
		ei = false;

		final opcode = fetch();
		final handler = table[opcode];
		if (handler == null) throw 'unimplemented opcode ${StringTools.hex(opcode, 2)}';
		handler(this);
	}

	public function isImplemented(opcode:Int):Bool {
		if (table == null) table = Decoder.build();
		return table[opcode & 0xFF] != null;
	}

	public inline function setF(value:Int):Void {
		f = value & 0xFF;
		q = f;
	}

	public function fetch():Int {
		final value = bus.fetch(pc, (i << 8) | r);
		pc = (pc + 1) & 0xFFFF;
		r = (r & 0x80) | ((r + 1) & 0x7F);
		return value;
	}

	public inline function read(address:Int):Int {
		return bus.read(address & 0xFFFF);
	}

	public inline function write(address:Int, value:Int):Void {
		bus.write(address & 0xFFFF, value & 0xFF);
	}

	public inline function idle(states:Int):Void {
		bus.idle(states);
	}

	public function immediate():Int {
		final value = read(pc);
		pc = (pc + 1) & 0xFFFF;
		return value;
	}

	public function immediateWord():Int {
		final low = immediate();
		return low | (immediate() << 8);
	}

	public inline function bc():Int return (b << 8) | c;
	public inline function de():Int return (d << 8) | e;
	public inline function hl():Int return (h << 8) | l;
	public inline function af():Int return (a << 8) | f;

	public inline function setBc(value:Int):Void {
		b = (value >> 8) & 0xFF;
		c = value & 0xFF;
	}

	public inline function setDe(value:Int):Void {
		d = (value >> 8) & 0xFF;
		e = value & 0xFF;
	}

	public inline function setHl(value:Int):Void {
		h = (value >> 8) & 0xFF;
		l = value & 0xFF;
	}

	public inline function setAf(value:Int):Void {
		a = (value >> 8) & 0xFF;
		f = value & 0xFF;
	}

	public function register(index:Int):Int {
		return switch (index) {
			case 0: b;
			case 1: c;
			case 2: d;
			case 3: e;
			case 4: h;
			case 5: l;
			case 6: read(hl());
			case _: a;
		}
	}

	public function setRegister(index:Int, value:Int):Void {
		final byte = value & 0xFF;
		switch (index) {
			case 0: b = byte;
			case 1: c = byte;
			case 2: d = byte;
			case 3: e = byte;
			case 4: h = byte;
			case 5: l = byte;
			case 6: write(hl(), byte);
			case _: a = byte;
		}
	}

	public function pair(index:Int):Int {
		return switch (index) {
			case 0: bc();
			case 1: de();
			case 2: hl();
			case _: sp;
		}
	}

	public function setPair(index:Int, value:Int):Void {
		switch (index) {
			case 0: setBc(value);
			case 1: setDe(value);
			case 2: setHl(value);
			case _: sp = value & 0xFFFF;
		}
	}

	public function condition(index:Int):Bool {
		return switch (index) {
			case 0: (f & ZERO) == 0;
			case 1: (f & ZERO) != 0;
			case 2: (f & CARRY) == 0;
			case 3: (f & CARRY) != 0;
			case 4: (f & PARITY) == 0;
			case 5: (f & PARITY) != 0;
			case 6: (f & SIGN) == 0;
			case _: (f & SIGN) != 0;
		}
	}

	public function push(value:Int):Void {
		sp = (sp - 1) & 0xFFFF;
		write(sp, (value >> 8) & 0xFF);
		sp = (sp - 1) & 0xFFFF;
		write(sp, value & 0xFF);
	}

	public function pop():Int {
		final low = read(sp);
		sp = (sp + 1) & 0xFFFF;
		final high = read(sp);
		sp = (sp + 1) & 0xFFFF;
		return low | (high << 8);
	}

	public static inline function parity(value:Int):Bool {
		var bits = value & 0xFF;
		bits ^= bits >> 4;
		bits ^= bits >> 2;
		bits ^= bits >> 1;
		return (bits & 1) == 0;
	}

	public inline function bits(value:Int):Int {
		return value & (Y | X);
	}
}

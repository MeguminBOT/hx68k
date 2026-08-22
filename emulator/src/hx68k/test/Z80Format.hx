package hx68k.test;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;

class Z80State {
	public var pc:Int = 0;
	public var sp:Int = 0;
	public var ix:Int = 0;
	public var iy:Int = 0;
	public var wz:Int = 0;
	public var af2:Int = 0;
	public var bc2:Int = 0;
	public var de2:Int = 0;
	public var hl2:Int = 0;

	public var a:Int = 0;
	public var b:Int = 0;
	public var c:Int = 0;
	public var d:Int = 0;
	public var e:Int = 0;
	public var f:Int = 0;
	public var h:Int = 0;
	public var l:Int = 0;
	public var i:Int = 0;
	public var r:Int = 0;

	public var im:Int = 0;
	public var p:Int = 0;
	public var q:Int = 0;
	public var iff1:Int = 0;
	public var iff2:Int = 0;
	public var ei:Int = 0;

	public var ram:Array<{addr:Int, value:Int}> = [];

	public function new() {}
}

class Z80Cycle {
	public static inline final READ = 1;
	public static inline final WRITE = 2;
	public static inline final MEMORY = 4;
	public static inline final PORT = 8;
	public static inline final HAS_ADDRESS = 16;
	public static inline final HAS_VALUE = 32;

	public var address:Int = 0;
	public var value:Int = 0;
	public var pins:Int = 0;

	public function new() {}

	public function toString():String {
		final lines = ((pins & READ) != 0 ? "r" : "-") + ((pins & WRITE) != 0 ? "w" : "-")
			+ ((pins & MEMORY) != 0 ? "m" : "-") + ((pins & PORT) != 0 ? "i" : "-");
		final where = (pins & HAS_ADDRESS) != 0 ? StringTools.hex(address, 4) : "----";
		final what = (pins & HAS_VALUE) != 0 ? StringTools.hex(value, 2) : "--";
		return where + " " + what + " " + lines;
	}
}

class Z80Port {
	public var address:Int = 0;
	public var value:Int = 0;
	public var write:Bool = false;

	public function new() {}
}

class Z80Test {
	public var name:String = "";
	public var initial:Z80State = new Z80State();
	public var expected:Z80State = new Z80State();
	public var cycles:Array<Z80Cycle> = [];
	public var ports:Array<Z80Port> = [];

	public function new() {}
}

class Z80Format {
	public static inline final MAGIC = 0x5A383042;

	public static function write(tests:Array<Z80Test>):Bytes {
		final out = new BytesBuffer();
		out.addInt32(MAGIC);
		out.addInt32(tests.length);

		for (test in tests) {
			final name = Bytes.ofString(test.name);
			out.addByte(name.length);
			out.add(name);

			state(out, test.initial);
			state(out, test.expected);

			out.addInt32(test.cycles.length);
			for (cycle in test.cycles) {
				out.addInt32(cycle.address);
				out.addByte(cycle.value & 0xFF);
				out.addByte(cycle.pins);
			}

			out.addByte(test.ports.length);
			for (port in test.ports) {
				out.addInt32(port.address);
				out.addByte(port.value & 0xFF);
				out.addByte(port.write ? 1 : 0);
			}
		}

		return out.getBytes();
	}

	static function state(out:BytesBuffer, s:Z80State):Void {
		for (value in [s.pc, s.sp, s.ix, s.iy, s.wz, s.af2, s.bc2, s.de2, s.hl2]) out.addInt32(value);
		for (value in [s.a, s.b, s.c, s.d, s.e, s.f, s.h, s.l, s.i, s.r,
			s.im, s.p, s.q, s.iff1, s.iff2, s.ei]) out.addByte(value & 0xFF);

		out.addInt32(s.ram.length);
		for (cell in s.ram) {
			out.addInt32(cell.addr);
			out.addByte(cell.value & 0xFF);
		}
	}

	public static function read(path:String):Array<Z80Test> {
		final bytes = sys.io.File.getBytes(path);
		final input = new haxe.io.BytesInput(bytes);
		input.bigEndian = false;

		if (input.readInt32() != MAGIC) throw path + " is not a converted z80 fixture";
		final count = input.readInt32();

		final tests = [];
		for (i in 0...count) {
			final test = new Z80Test();
			test.name = input.readString(input.readByte());
			test.initial = readState(input);
			test.expected = readState(input);

			final cycles = input.readInt32();
			for (c in 0...cycles) {
				final cycle = new Z80Cycle();
				cycle.address = input.readInt32();
				cycle.value = input.readByte();
				cycle.pins = input.readByte();
				test.cycles.push(cycle);
			}

			final ports = input.readByte();
			for (p in 0...ports) {
				final port = new Z80Port();
				port.address = input.readInt32();
				port.value = input.readByte();
				port.write = input.readByte() != 0;
				test.ports.push(port);
			}

			tests.push(test);
		}

		return tests;
	}

	static function readState(input:haxe.io.BytesInput):Z80State {
		final s = new Z80State();
		s.pc = input.readInt32();
		s.sp = input.readInt32();
		s.ix = input.readInt32();
		s.iy = input.readInt32();
		s.wz = input.readInt32();
		s.af2 = input.readInt32();
		s.bc2 = input.readInt32();
		s.de2 = input.readInt32();
		s.hl2 = input.readInt32();

		s.a = input.readByte();
		s.b = input.readByte();
		s.c = input.readByte();
		s.d = input.readByte();
		s.e = input.readByte();
		s.f = input.readByte();
		s.h = input.readByte();
		s.l = input.readByte();
		s.i = input.readByte();
		s.r = input.readByte();

		s.im = input.readByte();
		s.p = input.readByte();
		s.q = input.readByte();
		s.iff1 = input.readByte();
		s.iff2 = input.readByte();
		s.ei = input.readByte();

		final cells = input.readInt32();
		for (i in 0...cells) s.ram.push({addr: input.readInt32(), value: input.readByte()});

		return s;
	}
}

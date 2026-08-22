package hx68k.test;

import haxe.io.Bytes;

enum abstract SstKind(Int) from Int to Int {
	var Idle = 0;
	var Write = 1;
	var Read = 2;
	var Tas = 3;
	var ReadAddressError = 4;
	var WriteAddressError = 5;

	public function toString():String {
		return switch (cast this : SstKind) {
			case Idle: "n";
			case Write: "w";
			case Read: "r";
			case Tas: "t";
			case ReadAddressError: "re";
			case WriteAddressError: "we";
		}
	}
}

class SstTransaction {
	public var kind:SstKind;
	public var cycles:Int;
	public var fc:Int;
	public var addr:Int;
	public var data:Int;
	public var uds:Int;
	public var lds:Int;

	public function new() {}

	public inline function isWord():Bool {
		return uds + lds == 2;
	}

	public function toString():String {
		if (kind == Idle) return 'n(${cycles})';
		return '${kind.toString()}(${cycles}) fc=${fc} @${StringTools.hex(addr, 6)}'
			+ ' d=${StringTools.hex(data & 0xFFFF, 4)} uds=${uds} lds=${lds}';
	}
}

class SstState {
	public var d:Array<Int>;
	public var a:Array<Int>;
	public var usp:Int;
	public var ssp:Int;
	public var sr:Int;
	public var pc:Int;
	public var prefetch:Array<Int>;

	public var ram:Array<{addr:Int, value:Int}>;

	public function new() {
		d = [];
		a = [];
		prefetch = [];
		ram = [];
	}
}

class SstTest {
	public var name:String;
	public var initial:SstState;
	public var expected:SstState;
	public var transactions:Array<SstTransaction>;
	public var cycles:Int;

	public function new() {
		transactions = [];
	}
}

class SstReader {
	static inline final MAGIC_FILE = 0x1A3F5D71;
	static inline final MAGIC_TEST = 0xABC12367;
	static inline final MAGIC_NAME = 0x89ABCDEF;
	static inline final MAGIC_STATE = 0x01234567;
	static inline final MAGIC_TRANS = 0x456789AB;

	var b:Bytes;
	var p:Int;

	public function new(bytes:Bytes) {
		b = bytes;
		p = 0;
	}

	public static function readFile(path:String):Array<SstTest> {
		return new SstReader(sys.io.File.getBytes(path)).parse();
	}

	inline function u8():Int {
		return b.get(p++);
	}

	inline function u16():Int {
		final v = b.getUInt16(p);
		p += 2;
		return v;
	}

	inline function i32():Int {
		final v = b.getInt32(p);
		p += 4;
		return v;
	}

	inline function expect(magic:Int, what:String):Void {
		final size = i32();
		final got = i32();
		if (got != magic) {
			throw 'bad $what magic at ${p - 4}: got ${StringTools.hex(got, 8)},'
				+ ' expected ${StringTools.hex(magic, 8)} (size field ${size})';
		}
	}

	public function parse():Array<SstTest> {
		final magic = i32();
		if (magic != MAGIC_FILE)
			throw 'not a SingleStepTests container (magic ${StringTools.hex(magic, 8)})';

		final count = i32();
		final out = new Array<SstTest>();

		for (_ in 0...count)
			out.push(readTest());

		return out;
	}

	function readTest():SstTest {
		expect(MAGIC_TEST, "test");

		final t = new SstTest();
		t.name = readName();
		t.initial = readState();
		t.expected = readState();

		expect(MAGIC_TRANS, "transactions");
		t.cycles = i32();

		final n = i32();
		for (_ in 0...n) {
			final tr = new SstTransaction();
			tr.kind = u8();
			tr.cycles = i32();

			if (tr.kind != Idle) {
				tr.fc = i32();
				tr.addr = i32();
				tr.data = i32();
				tr.uds = i32();
				tr.lds = i32();
			}

			t.transactions.push(tr);
		}

		return t;
	}

	function readName():String {
		expect(MAGIC_NAME, "name");
		final len = i32();
		final s = b.getString(p, len);
		p += len;
		return s;
	}

	function readState():SstState {
		expect(MAGIC_STATE, "state");

		final s = new SstState();
		for (_ in 0...8) s.d.push(i32());
		for (_ in 0...7) s.a.push(i32());
		s.usp = i32();
		s.ssp = i32();
		s.sr = i32();
		s.pc = i32();
		s.prefetch.push(i32());
		s.prefetch.push(i32());

		final n = i32();
		for (_ in 0...n) {
			final addr = i32();
			final value = u16();
			s.ram.push({addr: addr, value: value});
		}

		return s;
	}
}

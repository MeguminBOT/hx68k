package hx68k.cpu.m68k;

import haxe.ds.Vector;
import hx68k.cpu.m68k.Bus.FunctionCode;

class M68000 {
	public var d:Vector<Int>;
	public var a:Vector<Int>;
	public var inactiveSp:Int;

	public var pc:Int;
	public var ird:Int;
	public var irc:Int;

	public var xf:Bool;
	public var nf:Bool;
	public var zf:Bool;
	public var vf:Bool;
	public var cf:Bool;

	public var t:Bool;
	public var s:Bool;
	public var imask:Int;

	public var bus:Bus;

	public var faulted:Bool;

	public var pcAtStart:Int;

	public var opcode:Int;

	public var faultIr:Int;

	public var faultPc:Int;

	static var table:Vector<M68000->Void>;

	public function new(bus:Bus) {
		this.bus = bus;
		d = new Vector<Int>(8);
		a = new Vector<Int>(8);
		for (i in 0...8) {
			d[i] = 0;
			a[i] = 0;
		}
		if (table == null) table = Decoder.build();
	}

	public function getSr():Int {
		return (t ? 0x8000 : 0) | (s ? 0x2000 : 0) | ((imask & 7) << 8) | getCcr();
	}

	public inline function getCcr():Int {
		return (xf ? 0x10 : 0) | (nf ? 0x08 : 0) | (zf ? 0x04 : 0) | (vf ? 0x02 : 0) | (cf ? 0x01 : 0);
	}

	public function setSr(v:Int):Void {
		setS((v & 0x2000) != 0);
		t = (v & 0x8000) != 0;
		imask = (v >> 8) & 7;
		setCcr(v);
	}

	public inline function setCcr(v:Int):Void {
		xf = (v & 0x10) != 0;
		nf = (v & 0x08) != 0;
		zf = (v & 0x04) != 0;
		vf = (v & 0x02) != 0;
		cf = (v & 0x01) != 0;
	}

	public function setS(v:Bool):Void {
		if (v == s) return;
		final tmp = a[7];
		a[7] = inactiveSp;
		inactiveSp = tmp;
		s = v;
	}

	public inline function dataFc():Int {
		return s ? FunctionCode.SUPER_DATA : FunctionCode.USER_DATA;
	}

	public inline function progFc():Int {
		return s ? FunctionCode.SUPER_PROGRAM : FunctionCode.USER_PROGRAM;
	}

	public inline function idle(n:Int):Void {
		if (n > 0) bus.idle(n);
	}

	public function readByte(addr:Int, fc:Int):Int {
		addr &= 0xFFFFFF;
		final odd = (addr & 1) != 0;
		final v = bus.read(addr & 0xFFFFFE, fc, !odd, odd);
		return odd ? (v & 0xFF) : ((v >> 8) & 0xFF);
	}

	public function readWord(addr:Int, fc:Int):Int {
		if ((addr & 1) != 0) {
			addressError(addr, fc, true, 0);
			return 0;
		}
		return bus.read(addr & 0xFFFFFF, fc, true, true) & 0xFFFF;
	}

	public function readLong(addr:Int, fc:Int):Int {
		if ((addr & 1) != 0) {
			addressError(addr, fc, true, 0);
			return 0;
		}
		final hi = bus.read(addr & 0xFFFFFF, fc, true, true) & 0xFFFF;
		if (faulted) return 0;
		final lo = bus.read((addr + 2) & 0xFFFFFF, fc, true, true) & 0xFFFF;
		return (hi << 16) | lo;
	}

	public function writeByte(addr:Int, fc:Int, v:Int):Void {
		addr &= 0xFFFFFF;
		v &= 0xFF;
		final odd = (addr & 1) != 0;
		bus.write(addr & 0xFFFFFE, fc, odd ? v : (v << 8), !odd, odd);
	}

	public function writeWord(addr:Int, fc:Int, v:Int):Void {
		if ((addr & 1) != 0) {
			addressError(addr, fc, false, v);
			return;
		}
		bus.write(addr & 0xFFFFFF, fc, v & 0xFFFF, true, true);
	}

	public function writeLong(addr:Int, fc:Int, v:Int):Void {
		if ((addr & 1) != 0) {
			addressError(addr, fc, false, (v >>> 16) & 0xFFFF);
			return;
		}
		bus.write(addr & 0xFFFFFF, fc, (v >>> 16) & 0xFFFF, true, true);
		if (faulted) return;
		bus.write((addr + 2) & 0xFFFFFF, fc, v & 0xFFFF, true, true);
	}

	public function writeLongLowFirst(addr:Int, fc:Int, v:Int):Void {
		if ((addr & 1) != 0) {
			addressError((addr + 2) | 0, fc, false, v & 0xFFFF);
			return;
		}
		bus.write((addr + 2) & 0xFFFFFF, fc, v & 0xFFFF, true, true);
		if (faulted) return;
		bus.write(addr & 0xFFFFFF, fc, (v >>> 16) & 0xFFFF, true, true);
	}

	public function readLongLowFirst(addr:Int, fc:Int):Int {
		if ((addr & 1) != 0) {
			addressError((addr + 2) | 0, fc, true, 0);
			return 0;
		}
		final lo = bus.read((addr + 2) & 0xFFFFFF, fc, true, true) & 0xFFFF;
		if (faulted) return 0;
		final hi = bus.read(addr & 0xFFFFFF, fc, true, true) & 0xFFFF;
		return (hi << 16) | lo;
	}

	public function jump(target:Int):Void {
		if ((target & 1) != 0) {
			addressError(target, progFc(), true, 0);
			return;
		}

		pc = target | 0;
		ird = bus.read(pc & 0xFFFFFE, progFc(), true, true) & 0xFFFF;
		faultIr = ird;
		pc = (pc + 2) | 0;
		irc = bus.read(pc & 0xFFFFFE, progFc(), true, true) & 0xFFFF;
		pc = (pc + 2) | 0;
	}

	public inline function prefetch():Void {
		ird = irc;
		faultIr = ird;
		irc = bus.read(pc & 0xFFFFFE, progFc(), true, true) & 0xFFFF;
		pc = (pc + 2) | 0;
	}

	public inline function fetchExt():Int {
		final v = irc;
		irc = bus.read(pc & 0xFFFFFE, progFc(), true, true) & 0xFFFF;
		pc = (pc + 2) | 0;
		return v;
	}

	public inline function extAddr():Int {
		return (pc - 2) | 0;
	}

	public static inline final VEC_ADDRESS_ERROR = 3;

	inline function rawRead(addr:Int, fc:Int):Int {
		return bus.read(addr & 0xFFFFFE, fc, true, true) & 0xFFFF;
	}

	inline function rawWrite(addr:Int, fc:Int, v:Int):Void {
		bus.write(addr & 0xFFFFFE, fc, v & 0xFFFF, true, true);
	}

	public function addressError(addr:Int, fc:Int, read:Bool, data:Int):Void {
		faulted = true;

		bus.faultAccess(read, addr & 0xFFFFFE, fc, data);
		idle(8);

		final oldSr = getSr();
		final stackPc = faultPc;
		final ssw = (faultIr & 0xFFE0) | (read ? 0x10 : 0) | (fc & 7);

		setS(true);
		t = false;

		final sp = a[7];
		final dfc = dataFc();

		rawWrite(sp - 2, dfc, stackPc & 0xFFFF);
		rawWrite(sp - 6, dfc, oldSr);
		rawWrite(sp - 4, dfc, (stackPc >>> 16) & 0xFFFF);
		rawWrite(sp - 8, dfc, faultIr);
		rawWrite(sp - 10, dfc, addr & 0xFFFF);
		rawWrite(sp - 14, dfc, ssw);
		rawWrite(sp - 12, dfc, (addr >>> 16) & 0xFFFF);

		a[7] = (sp - 14) | 0;

		final vecAddr = VEC_ADDRESS_ERROR * 4;
		final hi = rawRead(vecAddr, dfc);
		final lo = rawRead(vecAddr + 2, dfc);
		pc = ((hi << 16) | lo) | 0;

		ird = rawRead(pc, progFc());
		pc = (pc + 2) | 0;
		idle(2);
		irc = rawRead(pc, progFc());
		pc = (pc + 2) | 0;
	}

	public function exception(vector:Int, stackedPc:Int, lead:Int, stackedSr:Int = -1):Void {
		idle(lead);

		final oldSr = stackedSr < 0 ? getSr() : stackedSr;
		setS(true);
		t = false;

		final sp = a[7];
		final dfc = dataFc();

		rawWrite(sp - 2, dfc, stackedPc & 0xFFFF);
		rawWrite(sp - 6, dfc, oldSr);
		rawWrite(sp - 4, dfc, (stackedPc >>> 16) & 0xFFFF);

		a[7] = (sp - 6) | 0;

		final vecAddr = vector * 4;
		final hi = rawRead(vecAddr, dfc);
		final lo = rawRead(vecAddr + 2, dfc);
		pc = ((hi << 16) | lo) | 0;

		ird = rawRead(pc, progFc());
		faultIr = ird;
		pc = (pc + 2) | 0;
		idle(2);
		irc = rawRead(pc, progFc());
		pc = (pc + 2) | 0;

		faulted = true;
	}

	public function reset():Void {
		faulted = false;
		setS(true);
		t = false;
		imask = 7;
		xf = false;
		nf = false;
		zf = false;
		vf = false;
		cf = false;

		final dfc = dataFc();
		a[7] = ((rawRead(0, dfc) << 16) | rawRead(2, dfc)) | 0;
		pc = ((rawRead(4, dfc) << 16) | rawRead(6, dfc)) | 0;

		ird = rawRead(pc, progFc());
		faultIr = ird;
		pc = (pc + 2) | 0;
		irc = rawRead(pc, progFc());
		pc = (pc + 2) | 0;
	}

	public function interrupt(level:Int):Void {
		final oldSr = getSr();
		final target = (pc - 4) | 0;

		idle(6);
		rawRead(0xFFFFF0 | (level << 1), FunctionCode.CPU_SPACE);

		setS(true);
		t = false;
		imask = level;
		exception(24 + level, target, 6, oldSr);
	}

	public function step():Void {
		faulted = false;
		pcAtStart = pc;
		faultPc = (pc - 2) | 0;
		final op = ird;
		opcode = op;
		faultIr = op;
		final h = table[op];
		if (h == null) throw 'unimplemented opcode ${StringTools.hex(op, 4)}';
		h(this);
	}

	public function isImplemented(op:Int):Bool {
		if (table == null) table = Decoder.build();
		return table[op & 0xFFFF] != null;
	}
}

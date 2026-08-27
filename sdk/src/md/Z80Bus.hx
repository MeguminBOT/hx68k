package md;

import md.hw.Z80 as Ports;

class Z80Bus {
	public static inline final RAM = 0xA00000;

	public static inline final SIZE = 0x2000;

	public static inline final BANK = 0xA06000;

	public static inline final COMMAND = 0xA00100;

	public static inline final STATUS = 0xA00102;

	public static inline final PARAMETERS = 0xA00104;

	public static inline final READY = 0x80;

	public static inline final NO_DRIVER = -1;

	static var driver:Int16 = NO_DRIVER;

	static var protection:UInt16 = 0;

	public static inline function request():Void {
		Ports.hold();
	}

	public static inline function release():Void {
		Ports.release();
	}

	public static inline function taken():Bool {
		return Ports.held();
	}

	public static function requestAndReport():Bool {
		if (Ports.held()) return true;
		Ports.hold();
		return false;
	}

	public static inline function startReset():Void {
		Ports.reset(true);
	}

	public static inline function endReset():Void {
		Ports.reset(false);
	}

	public static function reset():Void {
		Ports.reset(true);
		settle();
		Ports.reset(false);
	}

	public static inline function loadedDriver():Int16 {
		return driver;
	}

	public static function driverReady():Bool {
		final was:Bool = requestAndReport();
		final ready:Bool = (Memory.readU8(STATUS) & READY) != 0;
		if (!was) Ports.release();
		return ready;
	}

	public static function loadDriver(which:Int16, from:Int, count:UInt16):Void {
		Ports.hold();

		Psg.reset();
		Fm.reset();

		var i:Int = 0;
		while (i < SIZE) {
			Memory.writeU8(RAM + i, 0);
			i++;
		}

		final source:Int = from;
		final size:Int = count;
		i = 0;
		while (i < size) {
			Memory.writeU8(RAM + i, Memory.loadU8(source + i));
			i++;
		}

		protection = 0;
		Ports.reset(true);
		Ports.release();
		settle();
		Ports.reset(false);

		driver = which;
	}

	public static inline function usesProtection(at:UInt16):Void {
		protection = at;
	}

	public static function setProtection(on:Bool):Void {
		if (protection == 0) return;

		final was:Bool = requestAndReport();
		Memory.writeU8(RAM + (protection : Int), on ? 1 : 0);
		if (!was) Ports.release();
	}

	public static inline function readByte(at:UInt16):UInt8 {
		return Memory.readU8(RAM + (at : Int));
	}

	public static inline function writeByte(at:UInt16, value:UInt8):Void {
		Memory.writeU8(RAM + (at : Int), value);
	}

	public static function upload(to:UInt16, from:Vector<UInt8>, count:UInt16):Void {
		final was:Bool = requestAndReport();

		final at:Int = to;
		var i:Int = 0;
		while (i < count) {
			Memory.writeU8(RAM + at + i, from[i]);
			i++;
		}

		if (!was) Ports.release();
	}

	public static function download(from:UInt16, into:Vector<UInt8>, count:UInt16):Void {
		final was:Bool = requestAndReport();

		final at:Int = from;
		var i:Int = 0;
		while (i < count) {
			into[i] = Memory.readU8(RAM + at + i);
			i++;
		}

		if (!was) Ports.release();
	}

	public static function clear():Void {
		final was:Bool = requestAndReport();

		var i:Int = 0;
		while (i < SIZE) {
			Memory.writeU8(RAM + i, 0);
			i++;
		}

		if (!was) Ports.release();
	}

	public static inline function setBank(bank:UInt16):Void {
		final which:Int = bank;
		var bit:Int = 0;

		while (bit < 9) {
			Memory.writeU8(BANK, (which >> bit) & 1);
			bit++;
		}
	}

	@:md.body("	register u16 count __asm__(\"d0\") = loops;

	__asm__ __volatile__ (
		\"1:\\n\\t\"
		\"moveq	#7,%%d1\\n\\t\"
		\"2:\\n\\t\"
		\"dbra	%%d1,2b\\n\\t\"
		\"subq.w	#1,%0\\n\\t\"
		\"bne.s	1b\\n\"
		: \"+d\"(count) : : \"d1\", \"cc\");
")
	static function spin(loops:UInt16):Void {}

	public static inline function linger():Void {
		spin(1);
	}

	static inline function settle():Void {
		spin(50);
	}
}

package md;

import md.hw.Z80 as Port;

class Z80Bus {
	public static inline final RAM = 0xA00000;

	public static inline final SIZE = 0x2000;

	public static inline final BANK = 0xA06000;

	public static inline function request():Void {
		Port.hold();
	}

	public static inline function release():Void {
		Port.release();
	}

	public static inline function taken():Bool {
		return Port.held();
	}

	public static function reset():Void {
		Port.reset(true);
		var spin = 0;
		while (spin < 32) spin++;
		Port.reset(false);
	}

	public static inline function readByte(at:UInt16):UInt8 {
		return Memory.readU8(RAM + (at : Int));
	}

	public static inline function writeByte(at:UInt16, value:UInt8):Void {
		Memory.writeU8(RAM + (at : Int), value);
	}

	public static function upload(to:UInt16, from:Vector<UInt8>, count:UInt16):Void {
		Port.hold();

		final at:Int = to;
		var i:Int = 0;
		while (i < count) {
			Memory.writeU8(RAM + at + i, from[i]);
			i++;
		}

		Port.release();
	}

	public static function download(from:UInt16, into:Vector<UInt8>, count:UInt16):Void {
		Port.hold();

		final at:Int = from;
		var i:Int = 0;
		while (i < count) {
			into[i] = Memory.readU8(RAM + at + i);
			i++;
		}

		Port.release();
	}

	public static function clear():Void {
		Port.hold();

		var i:Int = 0;
		while (i < SIZE) {
			Memory.writeU8(RAM + i, 0);
			i++;
		}

		Port.release();
	}

	public static inline function setBank(bank:UInt16):Void {
		final which:Int = bank;
		var bit:Int = 0;

		while (bit < 9) {
			Memory.writeU8(BANK, (which >> bit) & 1);
			bit++;
		}
	}
}

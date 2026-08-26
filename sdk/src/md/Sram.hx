package md;

class Sram {
	public static inline final CONTROL = 0xA130F1;

	public static inline final BASE = 0x200001;

	public static inline function enable():Void {
		Memory.writeU8(CONTROL, 1);
	}

	public static inline function enableReadOnly():Void {
		Memory.writeU8(CONTROL, 3);
	}

	public static inline function disable():Void {
		Memory.writeU8(CONTROL, 0);
	}

	public static inline function readByte(offset:UInt32):UInt8 {
		return Memory.readU8(BASE + (offset : Int) * 2);
	}

	public static inline function writeByte(offset:UInt32, value:UInt8):Void {
		Memory.writeU8(BASE + (offset : Int) * 2, value);
	}

	public static function readWord(offset:UInt32):UInt16 {
		final at:Int = offset;
		final high:Int = readByte(at);
		final low:Int = readByte(at + 1);
		return (high << 8) | low;
	}

	public static function writeWord(offset:UInt32, value:UInt16):Void {
		final at:Int = offset;
		final word:Int = value;
		writeByte(at, (word >> 8) & 0xFF);
		writeByte(at + 1, word & 0xFF);
	}

	public static function readLong(offset:UInt32):UInt32 {
		final at:Int = offset;
		final high:Int = readWord(at);
		final low:Int = readWord(at + 2);
		return (high << 16) | low;
	}

	public static function writeLong(offset:UInt32, value:UInt32):Void {
		final at:Int = offset;
		final long:Int = value;
		writeWord(at, (long >> 16) & 0xFFFF);
		writeWord(at + 2, long & 0xFFFF);
	}
}

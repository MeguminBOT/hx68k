package md;

class System {
	public static inline final VERSION = 0xA10001;

	public static inline final PAL = 0x40;

	public static inline final EXPANSION = 0x20;

	public static inline final HEADER_CHECKSUM = 0x18E;

	public static inline final CHECKED_FROM = 0x200;

	public static inline function version():UInt8 {
		return Memory.readU8(VERSION);
	}

	public static inline function isPal():Bool {
		return (Memory.readU8(VERSION) & PAL) != 0;
	}

	public static inline function isNtsc():Bool {
		return (Memory.readU8(VERSION) & PAL) == 0;
	}

	public static inline function hasExpansion():Bool {
		return (Memory.readU8(VERSION) & EXPANSION) == 0;
	}

	public static inline function headerChecksum():UInt16 {
		return Memory.readU16(HEADER_CHECKSUM);
	}

	static var masked:Int16 = 0;

	public static function disableInterrupts():Void {
		if (masked == 0) md.hw.Cpu.disableInterrupts();
		masked = masked + 1;
	}

	public static function enableInterrupts():Void {
		if (masked > 0) masked = masked - 1;
		if (masked == 0) md.hw.Cpu.enableInterrupts();
	}

	public static function doVBlankProcess():Void {
		Vdp.waitFrame();
		Dma.flush();
	}

	public static function computeChecksum(length:UInt32):UInt16 {
		final end:Int = length;
		var total:Int = 0;
		var at:Int = CHECKED_FROM;

		while (at < end) {
			total = (total + Memory.readU16(at)) & 0xFFFF;
			at += 2;
		}

		return total;
	}
}

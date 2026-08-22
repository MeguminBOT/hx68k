package md.hw;

import md.Memory;

class Ym2612 {
	static inline final PORT = 0xA04000;

	public static inline function busy():Bool {
		return (Memory.readU8(PORT) & 0x80) != 0;
	}

	public static function write(bank:Int, register:Int, value:Int):Void {
		final at = PORT + (bank & 1) * 2;

		while (busy()) {}
		Memory.writeU8(at, register & 0xFF);

		while (busy()) {}
		Memory.writeU8(at + 1, value & 0xFF);
	}
}

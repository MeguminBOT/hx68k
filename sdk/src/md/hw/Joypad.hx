package md.hw;

import md.Memory;

class Joypad {
	public static inline final UP = 0x01;
	public static inline final DOWN = 0x02;
	public static inline final LEFT = 0x04;
	public static inline final RIGHT = 0x08;
	public static inline final B = 0x10;
	public static inline final C = 0x20;
	public static inline final A = 0x40;
	public static inline final START = 0x80;

	static inline final DATA = 0xA10003;
	static inline final CONTROL = 0xA10009;

	public static inline function open(port:Int):Void {
		Memory.writeU8(CONTROL + port * 2, 0x40);
	}

	public static function read(port:Int):Int {
		final at = DATA + port * 2;

		Memory.writeU8(at, 0x40);
		settle(at);
		final high = Memory.readU8(at);

		Memory.writeU8(at, 0x00);
		settle(at);
		final low = Memory.readU8(at);

		Memory.writeU8(at, 0x40);

		return (~high & 0x3F) | (((~low >> 4) & 0x03) << 6);
	}

	static inline function settle(at:Int):Void {
		Memory.readU8(at);
		Memory.readU8(at);
	}
}

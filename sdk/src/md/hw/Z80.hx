package md.hw;

import md.Memory;

class Z80 {
	public static inline final RAM = 0xA00000;

	static inline final REQUEST = 0xA11100;
	static inline final RESET = 0xA11200;

	public static inline function request():Void {
		Memory.writeU16(REQUEST, 0x0100);
	}

	public static inline function release():Void {
		Memory.writeU16(REQUEST, 0x0000);
	}

	public static inline function held():Bool {
		return (Memory.readU16(REQUEST) & 0x0100) == 0;
	}

	public static inline function hold():Void {
		request();
		while (!held()) {}
	}

	public static inline function reset(asserted:Bool):Void {
		Memory.writeU16(RESET, asserted ? 0x0000 : 0x0100);
	}
}

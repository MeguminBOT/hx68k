package md.hw;

import md.Memory;

class Psg {
	static inline final PORT = 0xC00011;

	public static inline function write(value:Int):Void {
		Memory.writeU8(PORT, value & 0xFF);
	}
}

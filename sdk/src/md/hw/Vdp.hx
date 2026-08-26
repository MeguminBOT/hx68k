package md.hw;

import md.Memory;

class Vdp {
	public static inline final DATA = 0xC00000;
	public static inline final CONTROL = 0xC00004;
	public static inline final COUNTER = 0xC00008;

	public static inline final VRAM_READ = 0;
	public static inline final VRAM_WRITE = 1;
	public static inline final VSRAM_READ = 4;
	public static inline final VSRAM_WRITE = 5;
	public static inline final CRAM_READ = 8;
	public static inline final CRAM_WRITE = 3;

	public static inline function register(index:Int, value:Int):Void {
		Memory.writeU16(CONTROL, 0x8000 | ((index & 0x1F) << 8) | (value & 0xFF));
	}

	public static inline function address(code:Int, at:Int):Void {
		Memory.writeU16(CONTROL, ((code & 3) << 14) | (at & 0x3FFF));
		Memory.writeU16(CONTROL, ((code >> 2) << 4) | ((at >> 14) & 3));
	}

	public static inline function write(value:Int):Void {
		Memory.writeU16(DATA, value);
	}

	public static inline function read():Int {
		return Memory.readU16(DATA);
	}

	public static inline function status():Int {
		return Memory.readU16(CONTROL);
	}

	public static inline function counter():Int {
		return Memory.readU16(COUNTER);
	}

	public static inline function autoIncrement(step:Int):Void {
		register(15, step);
	}

	public static inline function colour(index:Int, value:Int):Void {
		address(CRAM_WRITE, index * 2);
		write(value);
	}

	public static inline function tilemap(at:Int, value:Int):Void {
		address(VRAM_WRITE, at);
		write(value);
	}

	public static inline function inVblank():Bool {
		return (status() & 0x0008) != 0;
	}
}

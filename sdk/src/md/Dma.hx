package md;

import md.hw.Vdp as Ports;

class Dma {
	public static inline final DEPTH = 64;

	public static inline final LONGS = 4;

	public static inline final BANK = 0x20000;

	@:md.size(256) static var pending:Vector<UInt32>;

	static var waiting:UInt16 = 0;

	public static inline function queued():UInt16 {
		return waiting;
	}

	public static inline function room():Bool {
		return waiting < DEPTH;
	}

	public static inline function discard():Void {
		waiting = 0;
	}

	public static function wait():Void {
		while ((Ports.status() & Ports.DMA_BUSY) != 0) {}
	}

	static inline function command(to:DmaTarget, at:UInt16):Int {
		final where:Int = at;

		switch (to) {
			case DmaTarget.Cram:
				return ((0xC000 | (where & 0x7F)) << 16) | 0x80;

			case DmaTarget.Vsram:
				return ((0x4000 | (where & 0x7F)) << 16) | 0x90;

			case _:
				return ((0x4000 | (where & 0x3FFF)) << 16) | (0x80 | ((where >> 14) & 3));
		}
	}

	static inline function setup(source:Int, words:Int, step:Int):Void {
		Ports.register(15, step);
		Ports.register(19, words & 0xFF);
		Ports.register(20, (words >> 8) & 0xFF);
		Ports.register(21, source & 0xFF);
		Ports.register(22, (source >> 8) & 0xFF);
		Ports.register(23, (source >> 16) & 0x7F);
	}

	static inline function issue(to:DmaTarget, from:Int, at:UInt16, words:Int, step:UInt16):Void {
		setup(from >> 1, words, step);
		Memory.writeU32(Ports.CONTROL, command(to, at));
	}

	public static function transfer(to:DmaTarget, from:Int, at:UInt16, length:UInt16,
			step:UInt16):Void {
		final reach:Int = BANK - (from & (BANK - 1));
		final fits:Int = reach >> 1;
		var words:Int = length;

		if (words > fits) {
			issue(to, from + reach, at + fits * step, words - fits, step);
			words = fits;
		}

		issue(to, from, at, words, step);
	}

	public static inline function transferFrom<T>(to:DmaTarget, from:Vector<T>, at:UInt16,
			length:UInt16, step:UInt16):Void {
		transfer(to, Memory.addressOf(from), at, length, step);
	}

	public static function fillVram(at:UInt16, length:UInt16, value:UInt8, step:UInt16):Void {
		final where:Int = at;
		final many:Int = length;
		final counted:Int = many == 0 ? 0
			: ((where & 1) != 0 ? (many < 3 ? 1 : many - 2) : (many < 2 ? 1 : many - 1));

		Ports.register(15, step);
		Ports.register(19, counted & 0xFF);
		Ports.register(20, (counted >> 8) & 0xFF);
		Ports.register(23, 0x80);

		Memory.writeU32(Ports.CONTROL, ((0x4000 | (where & 0x3FFF)) << 16)
			| (0x80 | ((where >> 14) & 3)));

		final byte:Int = value;
		Ports.write((byte << 8) | byte);
	}

	public static function copyVram(from:UInt16, to:UInt16, length:UInt16, step:UInt16):Void {
		final source:Int = from;
		final where:Int = to;
		final many:Int = length;

		Ports.register(15, step);
		Ports.register(19, many & 0xFF);
		Ports.register(20, (many >> 8) & 0xFF);
		Ports.register(21, source & 0xFF);
		Ports.register(22, (source >> 8) & 0xFF);
		Ports.register(23, 0xC0);

		Memory.writeU32(Ports.CONTROL, ((0x4000 | (where & 0x3FFF)) << 16)
			| (0xC0 | ((where >> 14) & 3)));
	}

	public static function queue(to:DmaTarget, from:Int, at:UInt16, length:UInt16,
			step:UInt16):Bool {
		final reach:Int = BANK - (from & (BANK - 1));
		final fits:Int = reach >> 1;

		if (length > fits) {
			if (!append(to, from + reach, at + fits * step, length - fits, step)) return false;
			return append(to, from, at, fits, step);
		}

		return append(to, from, at, length, step);
	}

	static function append(to:DmaTarget, from:Int, at:UInt16, length:Int, step:UInt16):Bool {
		if (waiting >= DEPTH) return false;

		final source:Int = from >> 1;
		final words:Int = length;
		final slot:Int = waiting * LONGS;

		pending[slot] = ((0x8F00 | (step & 0xFF)) << 16) | (0x9300 | (words & 0xFF));
		pending[slot + 1] = ((0x9400 | ((words >> 8) & 0xFF)) << 16) | (0x9500 | (source & 0xFF));
		pending[slot + 2] = ((0x9600 | ((source >> 8) & 0xFF)) << 16)
			| (0x9700 | ((source >> 16) & 0x7F));
		pending[slot + 3] = command(to, at);

		waiting = waiting + 1;
		return true;
	}

	public static inline function queueFrom<T>(to:DmaTarget, from:Vector<T>, at:UInt16,
			length:UInt16, step:UInt16):Bool {
		return queue(to, Memory.addressOf(from), at, length, step);
	}

	public static function flush():Void {
		final total:Int = waiting * LONGS;
		var i:Int = 0;

		while (i < total) {
			Memory.writeU32(Ports.CONTROL, pending[i]);
			Memory.writeU32(Ports.CONTROL, pending[i + 1]);
			Memory.writeU32(Ports.CONTROL, pending[i + 2]);
			Memory.writeU32(Ports.CONTROL, pending[i + 3]);
			i += LONGS;
		}

		waiting = 0;
	}
}

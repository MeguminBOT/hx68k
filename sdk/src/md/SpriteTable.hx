package md;

import md.hw.Vdp as Ports;

class SpriteTable {
	public static inline final ENTRIES = 80;

	public static inline final ENTRIES_H32 = 64;

	public static inline final BYTES = 8;

	public static inline final ORIGIN = 0x80;

	public static inline final DEFAULT_AT = 0xF400;

	public static inline final PRIORITY = 0x8000;

	public static inline final FLIP_VERTICAL = 0x1000;

	public static inline final FLIP_HORIZONTAL = 0x0800;

	public static inline final INDEX = 0x07FF;

	@:md.size(160) static var cache:Vector<UInt32>;

	static var at:UInt16 = DEFAULT_AT;

	public static inline function size(width:UInt16, height:UInt16):UInt16 {
		return ((width - 1) << 2) | (height - 1);
	}

	public static inline function attribute(index:UInt16, palette:UInt16, priority:Bool,
			flipHorizontal:Bool, flipVertical:Bool):UInt16 {
		return (index & INDEX)
			| ((palette & 3) << 13)
			| (priority ? PRIORITY : 0)
			| (flipVertical ? FLIP_VERTICAL : 0)
			| (flipHorizontal ? FLIP_HORIZONTAL : 0);
	}

	static inline function slot(index:UInt16):Int {
		return Memory.addressOf(cache) + index * BYTES;
	}

	public static function setBase(where:UInt16):Void {
		at = where;
		Ports.register(5, where >> 9);
	}

	public static inline function base():UInt16 {
		return at;
	}

	public static function set(index:UInt16, x:Int16, y:Int16, shape:UInt16, what:UInt16,
			next:UInt16):Void {
		final where:Int = slot(index);

		Memory.writeU16(where, y + ORIGIN);
		Memory.writeU16(where + 2, (shape << 8) | next);
		Memory.writeU16(where + 4, what);
		Memory.writeU16(where + 6, x + ORIGIN);
	}

	public static inline function setPosition(index:UInt16, x:Int16, y:Int16):Void {
		final where:Int = slot(index);

		Memory.writeU16(where, y + ORIGIN);
		Memory.writeU16(where + 6, x + ORIGIN);
	}

	public static inline function setShape(index:UInt16, shape:UInt16):Void {
		final where:Int = slot(index) + 2;
		Memory.writeU16(where, (shape << 8) | (Memory.readU16(where) & 0x7F));
	}

	public static inline function setAttribute(index:UInt16, what:UInt16):Void {
		Memory.writeU16(slot(index) + 4, what);
	}

	public static inline function setNext(index:UInt16, next:UInt16):Void {
		final where:Int = slot(index) + 2;
		Memory.writeU16(where, (Memory.readU16(where) & 0xFF00) | (next & 0x7F));
	}

	public static inline function entry(index:UInt16, word:UInt16):UInt16 {
		return Memory.readU16(slot(index) + word * 2);
	}

	public static function chain(index:UInt16, count:UInt16):Void {
		var where:Int = slot(index) + 2;
		var next:Int = index + 1;
		var left:Int = count;

		while (left > 1) {
			Memory.writeU16(where, (Memory.readU16(where) & 0xFF00) | (next & 0x7F));
			where += BYTES;
			next++;
			left--;
		}

		Memory.writeU16(where, Memory.readU16(where) & 0xFF00);
	}

	public static inline function hide(index:UInt16):Void {
		Memory.writeU16(slot(index), 0);
	}

	public static function clear():Void {
		cache[0] = 0;
	}

	public static function update(count:UInt16):Void {
		var many:Int = count;

		if (many == 0) {
			clear();
			many = 1;
		}

		Ports.autoIncrement(2);
		Ports.address(Ports.VRAM_WRITE, at);

		final total:Int = many << 1;
		var i:Int = 0;

		while (i + 8 <= total) {
			Memory.writeU32(Ports.DATA, cache[i]);
			Memory.writeU32(Ports.DATA, cache[i + 1]);
			Memory.writeU32(Ports.DATA, cache[i + 2]);
			Memory.writeU32(Ports.DATA, cache[i + 3]);
			Memory.writeU32(Ports.DATA, cache[i + 4]);
			Memory.writeU32(Ports.DATA, cache[i + 5]);
			Memory.writeU32(Ports.DATA, cache[i + 6]);
			Memory.writeU32(Ports.DATA, cache[i + 7]);
			i += 8;
		}

		while (i < total) {
			Memory.writeU32(Ports.DATA, cache[i]);
			i++;
		}
	}
}

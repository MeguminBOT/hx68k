package md;

import md.hw.Vdp as Ports;

class Patterns {
	public static inline final BYTES = 32;

	public static inline final LONGS = 8;

	public static inline function address(index:UInt16):UInt16 {
		return index * BYTES;
	}

	public static function set(index:UInt16, from:Vector<UInt32>, count:UInt16):Void {
		Ports.autoIncrement(2);
		Ports.address(Ports.VRAM_WRITE, address(index));

		var i:Int = 0;
		var left:Int = count;

		while (left > 0) {
			Memory.writeU32(Ports.DATA, from[i]);
			Memory.writeU32(Ports.DATA, from[i + 1]);
			Memory.writeU32(Ports.DATA, from[i + 2]);
			Memory.writeU32(Ports.DATA, from[i + 3]);
			Memory.writeU32(Ports.DATA, from[i + 4]);
			Memory.writeU32(Ports.DATA, from[i + 5]);
			Memory.writeU32(Ports.DATA, from[i + 6]);
			Memory.writeU32(Ports.DATA, from[i + 7]);
			i += LONGS;
			left--;
		}
	}

	public static function fill(index:UInt16, value:UInt8, count:UInt16):Void {
		Ports.autoIncrement(2);
		Ports.address(Ports.VRAM_WRITE, address(index));

		final byte:Int = value;
		final word:Int = (byte << 8) | byte;
		final pair:Int = (word << 16) | word;
		final total:Int = count * LONGS;
		var i:Int = 0;

		while (i < total) {
			Memory.writeU32(Ports.DATA, pair);
			i++;
		}
	}

	public static function setFromResource(index:UInt16, from:md.res.TileSet):Bool {
		if (from.compression != 0) return false;

		set(index, from.data, from.count);
		return true;
	}
}

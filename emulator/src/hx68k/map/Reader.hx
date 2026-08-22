package hx68k.map;

import haxe.io.Bytes;

class Reader {
	public var position:Int;

	final bytes:Bytes;

	public function new(bytes:Bytes, position:Int = 0) {
		this.bytes = bytes;
		this.position = position;
	}

	public inline function u8():Int {
		return bytes.get(position++);
	}

	public function s8():Int {
		final value = u8();
		return value >= 0x80 ? value - 0x100 : value;
	}

	public inline function u16():Int {
		position += 2;
		return (bytes.get(position - 2) << 8) | bytes.get(position - 1);
	}

	public inline function u32():Int {
		position += 4;
		return (bytes.get(position - 4) << 24) | (bytes.get(position - 3) << 16)
			| (bytes.get(position - 2) << 8) | bytes.get(position - 1);
	}

	public function uleb():Int {
		var result = 0;
		var shift = 0;
		while (true) {
			final byte = u8();
			result |= (byte & 0x7F) << shift;
			if (byte < 0x80) return result;
			shift += 7;
		}
	}

	public function sleb():Int {
		var result = 0;
		var shift = 0;
		while (true) {
			final byte = u8();
			result |= (byte & 0x7F) << shift;
			shift += 7;
			if (byte < 0x80) {
				if (shift < 32 && (byte & 0x40) != 0) result |= -(1 << shift);
				return result;
			}
		}
	}

	public function string():String {
		final start = position;
		while (bytes.get(position) != 0) position++;
		final value = bytes.getString(start, position - start);
		position++;
		return value;
	}
}

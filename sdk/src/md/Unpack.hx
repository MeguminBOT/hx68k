package md;

class Unpack {
	static var source:Int = 0;
	static var tag:Int = 0;
	static var left:Int = 0;

	public static function aplib(from:Int, into:Int):Int {
		source = from;
		tag = 0;
		left = 0;

		var out:Int = into;
		var lwm:Int = 2;
		var last:Int = 0;

		Memory.storeU8(out, Memory.loadU8(source++));
		out++;

		while (true) {
			if (bit() == 0) {
				Memory.storeU8(out, Memory.loadU8(source++));
				out++;
				lwm = 2;
				continue;
			}

			if (bit() == 0) {
				var length:Int = gamma() - lwm;
				var offset:Int;

				if (length == 0) {
					offset = last;
					length = gamma();
				} else {
					offset = ((length - 1) << 8) | Memory.loadU8(source++);
					length = gamma();
					if (offset >= 32000) length += 2;
					else if (offset >= 1280) length += 1;
					else if (offset < 128) length += 2;
					last = offset;
				}

				out = repeat(out, offset, length);
				lwm = 1;
				continue;
			}

			if (bit() == 0) {
				final held:Int = Memory.loadU8(source++);
				final offset:Int = held >> 1;
				if (offset == 0) break;

				out = repeat(out, offset, 2 + (held & 1));
				last = offset;
				lwm = 1;
				continue;
			}

			var offset:Int = 0;
			var taken:Int = 4;
			while (taken-- > 0) offset = (offset << 1) | bit();

			if (offset == 0) {
				Memory.storeU8(out, 0);
			} else {
				final value:Int = Memory.loadU8(out - offset);
				Memory.storeU8(out, value);
			}

			out++;
			lwm = 2;
		}

		return out - into;
	}

	public static function lz4w(from:Int, into:Int):Int {
		var at:Int = from;
		var out:Int = into;

		while (true) {
			final header:Int = Memory.loadU16(at);
			at += 2;

			final literals:Int = (header >> 12) & 0xF;
			final matched:Int = (header >> 8) & 0xF;
			final low:Int = header & 0xFF;

			if (literals == 0 && matched == 0 && low == 0) {
				final tail:Int = Memory.loadU16(at);
				if ((tail & 0x8000) != 0) {
					Memory.storeU8(out, tail & 0xFF);
					out++;
				}
				return out - into;
			}

			var run:Int = literals;
			while (run-- > 0) {
				Memory.storeU16(out, Memory.loadU16(at));
				out += 2;
				at += 2;
			}

			if (matched != 0) {
				out = repeatWords(out, (low + 1) * 2, matched + 1);
				continue;
			}

			if (low == 0) continue;

			final far:Int = Memory.loadU16(at);
			at += 2;

			out = repeatWords(out, (((-far) & 0x7FFF) + 1) * 2, low + 2);
		}

		return out - into;
	}

	static function repeat(out:Int, offset:Int, length:Int):Int {
		var to:Int = out;
		var back:Int = out - offset;
		var run:Int = length;

		while (run-- > 0) {
			final value:Int = Memory.loadU8(back);
			Memory.storeU8(to, value);
			back++;
			to++;
		}

		return to;
	}

	static function repeatWords(out:Int, offset:Int, words:Int):Int {
		var to:Int = out;
		var back:Int = out - offset;
		var run:Int = words;

		while (run-- > 0) {
			final value:Int = Memory.loadU16(back);
			Memory.storeU16(to, value);
			back += 2;
			to += 2;
		}

		return to;
	}

	static function bit():Int {
		if (left == 0) {
			tag = Memory.loadU8(source++);
			left = 8;
		}
		left--;
		return (tag >> left) & 1;
	}

	static function gamma():Int {
		var value:Int = 1;
		var more:Int = 1;

		while (more == 1) {
			value = (value << 1) | bit();
			more = bit();
		}

		return value;
	}
}

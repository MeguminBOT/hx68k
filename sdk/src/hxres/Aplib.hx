package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

private class Bits {
	final held:Array<Int> = [];

	var at:Int = -1;
	var tag:Int = 0;
	var left:Int = 0;

	public function new() {}

	public function bit(value:Int):Void {
		if (left-- == 0) {
			if (at != -1) held[at] = tag;
			at = held.length;
			held.push(0);
			tag = 0;
			left = 7;
		}
		tag |= (value & 1) << left;
	}

	public inline function byte(value:Int):Void {
		held.push(value & 0xFF);
	}

	public function bytes():Bytes {
		if (at != -1) held[at] = tag;

		final made = Bytes.alloc(held.length);
		for (i in 0...held.length) made.set(i, held[i] & 0xFF);
		return made;
	}
}

private class Match {
	public var offset:Int;
	public var length:Int;

	final data:Bytes;

	var index:Int;
	var rawCost:Int = -1;
	var cost:Int = -1;
	var saved:Int = -1;

	public function new(data:Bytes, index:Int, offset:Int, length:Int) {
		this.data = data;
		this.index = index;
		this.offset = offset;
		this.length = length;
	}

	public function lengthen(by:Int):Void {
		index -= by;
		length += by;
		rawCost = -1;
		cost = -1;
		saved = -1;
	}

	public function shortOrLong():Bool {
		if (length >= 2 && length <= 3 && offset > 0 && offset < 128) return true;
		return length >= 3;
	}

	public function raw():Int {
		if (rawCost == -1) {
			var total = 0;
			for (i in index...index + length) total += data.get(i) == 0 ? 7 : 9;
			rawCost = total;
		}
		return rawCost;
	}

	public function priced(wasMatch:Bool, lastOffset:Int):Int {
		if (cost == -1) cost = compute(wasMatch, lastOffset);
		return cost;
	}

	public function worth(wasMatch:Bool, lastOffset:Int):Int {
		if (saved == -1) saved = raw() - priced(wasMatch, lastOffset);
		return saved;
	}

	function compute(wasMatch:Bool, lastOffset:Int):Int {
		if (length == 1 && offset > 0 && offset < 16) return 3 + 4;
		if (length >= 2 && length <= 3 && offset > 0 && offset < 128) return 3 + 8;

		if ((length >= 2 && offset >= 0x80 && offset < 0x500)
				|| (length >= 3 && offset >= 0x500 && offset < 0x7D00)
				|| length >= 4) {
			var total = 2;

			if (!wasMatch && lastOffset == offset) {
				total += 2;
			} else {
				total += (Aplib.highBit(offset >> 8) * 2) + 2;
				total += 8;
			}

			total += Aplib.highBit(length) * 2;
			return total;
		}

		return raw();
	}
}

class Tally {
	public var literals:Int = 0;
	public var zeroes:Int = 0;
	public var tinies:Int = 0;
	public var shorts:Int = 0;
	public var longs:Int = 0;
	public var repeats:Int = 0;

	public function new() {}

	public function toString():String {
		return literals + "L " + zeroes + "z " + tinies + "t " + shorts + "s " + longs + "n " + repeats + "r";
	}
}

private class Reader {
	final data:Bytes;

	var at:Int;
	var tag:Int = 0;
	var left:Int = 0;

	public function new(data:Bytes, at:Int) {
		this.data = data;
		this.at = at;
	}

	public function bit():Int {
		if (left == 0) {
			tag = data.get(at++);
			left = 8;
		}
		left--;
		return (tag >> left) & 1;
	}

	public inline function byte():Int {
		return data.get(at++);
	}

	public function gamma():Int {
		var value = 1;
		do {
			value = (value << 1) | bit();
		} while (bit() == 1);
		return value;
	}
}

class Aplib {
	static var wasMatch:Bool = false;
	static var lastOffset:Int = -1;

	public static function unpack(packed:Bytes, ?tally:Tally):Bytes {
		final out = new BytesBuffer();
		final into = new Array<Int>();
		final read = new Reader(packed, 1);

		into.push(packed.get(0));
		if (tally != null) tally.literals++;

		var lwm = 2;
		var last = 0;

		while (true) {
			if (read.bit() == 0) {
				into.push(read.byte());
				if (tally != null) tally.literals++;
				lwm = 2;
				continue;
			}

			if (read.bit() == 0) {
				var length = read.gamma() - lwm;
				var offset;

				if (length == 0) {
					offset = last;
					length = read.gamma();
					if (tally != null) tally.repeats++;
				} else {
					offset = ((length - 1) << 8) | read.byte();
					length = read.gamma();
					if (offset >= 32000) length += 2
					else if (offset >= 1280) length += 1
					else if (offset < 128) length += 2;
					last = offset;
					if (tally != null) tally.longs++;
				}

				copy(into, offset, length);
				lwm = 1;
				continue;
			}

			if (read.bit() == 0) {
				final held = read.byte();
				final offset = held >> 1;
				if (offset == 0) break;

				copy(into, offset, 2 + (held & 1));
				last = offset;
				lwm = 1;
				if (tally != null) tally.shorts++;
				continue;
			}

			var offset = 0;
			for (_ in 0...4) offset = (offset << 1) | read.bit();

			if (offset == 0) {
				into.push(0);
				if (tally != null) tally.zeroes++;
			} else {
				into.push(into[into.length - offset]);
				if (tally != null) tally.tinies++;
			}
			lwm = 2;
		}

		for (value in into) out.addByte(value & 0xFF);
		return out.getBytes();
	}

	static function copy(into:Array<Int>, offset:Int, length:Int):Void {
		if (offset <= 0 || offset > into.length)
			throw new haxe.Exception("A match reaches " + offset + " back from " + into.length
				+ " bytes of output, which is outside it.");

		final from = into.length - offset;
		for (i in 0...length) into.push(into[from + i]);
	}

	public static function pack(data:Bytes):Bytes {
		if (data.length < 2) return data;

		final runs = new Array<Array<{offset:Int, repeat:Int}>>();
		for (_ in 0...0x100) runs.push([]);

		var at = 0;
		while (at < data.length) {
			final from = at;
			final value = data.get(at++);

			var repeat = 0;
			while (at < data.length && data.get(at) == value) {
				repeat++;
				at++;
			}

			runs[value].push({offset: from, repeat: repeat});
		}

		wasMatch = false;
		lastOffset = -1;

		final matches = new Array<Null<Match>>();
		for (_ in 0...data.length) matches.push(null);

		var i = 1;
		while (i < matches.length) {
			final match = best(runs, data, i);
			matches[i] = match;

			if (match != null) {
				i += match.length;
				if (match.shortOrLong()) {
					lastOffset = match.offset;
					wasMatch = true;
				} else {
					wasMatch = false;
				}
			} else {
				i++;
				wasMatch = false;
			}
		}

		lastOffset = 0;
		wasMatch = false;

		final out = new Bits();
		out.byte(data.get(0));

		var ind = 1;
		while (ind < matches.length) {
			var done = false;
			final match = matches[ind];

			if (match != null) {
				final offset = match.offset;
				final length = match.length;
				done = true;

				if (length == 1 && offset > 0 && offset < 16) tiny(out, offset)
				else if (length >= 2 && length <= 3 && offset > 0 && offset < 0x80) short(out, offset, length)
				else if (length >= 2 && offset >= 0x80 && offset < 0x500) long(out, offset, length)
				else if (length >= 3 && offset >= 0x500 && offset < 0x7D00) long(out, offset, length)
				else if (length >= 4) long(out, offset, length)
				else done = false;

				if (done) ind += length;
			}

			if (!done) {
				final value = data.get(ind++);
				if (value == 0) tiny(out, 0) else literal(out, value);
			}
		}

		ending(out);
		return out.bytes();
	}

	static function best(runs:Array<Array<{offset:Int, repeat:Int}>>, data:Bytes, ind:Int):Null<Match> {
		if (ind < 1) return null;

		final list = runs[data.get(ind)];
		final here = repeatAt(data, ind);

		var found:Null<Match> = null;
		var saved = 1;

		for (run in list) {
			var offset = run.offset;
			if (offset >= ind) break;

			var repeat = run.repeat;

			if (repeat < here) {
				final match = new Match(data, ind, ind - offset, repeat + 1);
				if (match.worth(wasMatch, lastOffset) >= saved) {
					found = match;
					saved = match.worth(wasMatch, lastOffset);
				}
			} else {
				if (repeat > here) {
					var delta = repeat - here;
					if (offset + delta >= ind) delta = (ind - offset) - 1;
					offset += delta;
					repeat -= delta;
				}

				var match:Match;

				if (repeat > 0) {
					if (offset + repeat >= ind) repeat = (ind - offset) - 1;
					match = matching(data, offset + repeat, ind + repeat);
					match.lengthen(repeat);
				} else {
					match = matching(data, offset, ind);
				}

				if (match.worth(wasMatch, lastOffset) >= saved) {
					found = match;
					saved = match.worth(wasMatch, lastOffset);
				}
			}
		}

		return found;
	}

	static function matching(data:Bytes, from:Int, ind:Int):Match {
		var reference = from;
		var current = ind;
		var length = 0;

		while (current < data.length && data.get(reference++) == data.get(current++)) length++;

		return new Match(data, ind, ind - from, length);
	}

	static function repeatAt(data:Bytes, ind:Int):Int {
		final value = data.get(ind);
		var at = ind + 1;
		while (at < data.length && data.get(at) == value) at++;
		return (at - ind) - 1;
	}

	public static function highBit(value:Int):Int {
		var result = 0;
		var left = value;

		if (left >= 0x10000) {
			result += 16;
			left >>= 16;
		}
		if (left >= 0x100) {
			result += 8;
			left >>= 8;
		}
		if (left >= 0x10) {
			result += 4;
			left >>= 4;
		}
		if (left >= 4) {
			result += 2;
			left >>= 2;
		}
		if (left >= 2) result++;

		return result;
	}

	static function fixed(out:Bits, value:Int, count:Int):Void {
		var i = count - 1;
		while (i >= 0) {
			out.bit((value >> i) & 1);
			i--;
		}
	}

	static function variable(out:Bits, value:Int):Void {
		if (value < 2)
			throw new haxe.Exception("A variable number below two cannot be encoded, and " + value
				+ " reached the encoder.");

		var bits = highBit(value) - 1;

		out.bit((value >> bits) & 1);
		while (bits-- > 0) {
			out.bit(1);
			out.bit((value >> bits) & 1);
		}
		out.bit(0);
	}

	static function literal(out:Bits, value:Int):Void {
		out.bit(0);
		out.byte(value);
		wasMatch = false;
	}

	static function tiny(out:Bits, offset:Int):Void {
		out.bit(1);
		out.bit(1);
		out.bit(1);
		fixed(out, offset, 4);
		wasMatch = false;
	}

	static function short(out:Bits, offset:Int, length:Int):Void {
		out.bit(1);
		out.bit(1);
		out.bit(0);
		out.byte((offset << 1) | (length - 2));
		lastOffset = offset;
		wasMatch = true;
	}

	static function long(out:Bits, offset:Int, length:Int):Void {
		out.bit(1);
		out.bit(0);

		if (!wasMatch && lastOffset == offset) {
			variable(out, 2);
			variable(out, length);
		} else {
			var high = (offset >> 8) + 2;
			if (!wasMatch) high++;

			variable(out, high);
			out.byte(offset & 0xFF);
			variable(out, length - delta(offset));
		}

		lastOffset = offset;
		wasMatch = true;
	}

	static function ending(out:Bits):Void {
		out.bit(1);
		out.bit(1);
		out.bit(0);
		out.byte(0);
	}

	static function delta(offset:Int):Int {
		if (offset < 0x80 || offset >= 0x7D00) return 2;
		if (offset >= 0x500) return 1;
		return 0;
	}
}
#end

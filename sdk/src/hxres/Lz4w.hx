package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

private class Segment {
	public final at:Int;
	public final from:Int;
	public final length:Int;
	public final saved:Int;
	public final cost:Int;
	public final long:Bool;

	public function new(at:Int, from:Int, length:Int) {
		this.at = at;
		this.from = from;
		this.length = length;

		final offset = at > from ? at - from : from - at;

		if (offset > Lz4w.OFFSET_MAX || length > Lz4w.MATCH_MAX) {
			long = true;
			cost = 2;
			saved = length - Lz4w.LONG_MATCH_MIN > 0 ? length - Lz4w.LONG_MATCH_MIN : 0;
		} else {
			long = false;
			cost = 1;
			saved = length - Lz4w.MATCH_MIN;
		}
	}

	public inline function offset():Int {
		return at > from ? at - from : from - at;
	}
}

class Lz4w {
	public static inline final LITERAL_MAX = 0xF;

	public static inline final MATCH_MIN = 1;

	public static inline final LONG_MATCH_MIN = 2;

	public static inline final MATCH_MAX = 0xF + MATCH_MIN;

	public static inline final LONG_MATCH_MAX = 0xFF + LONG_MATCH_MIN;

	public static inline final OFFSET_MIN = 1;

	public static inline final LONG_OFFSET_MIN = 1;

	public static inline final OFFSET_MAX = 0xFF + OFFSET_MIN;

	public static inline final LONG_OFFSET_MAX = 0x3FFF + LONG_MATCH_MIN;

	public static inline final LONG_OFFSET_MASK = 0x7FFF;

	static inline final MOST_SAVED = LONG_MATCH_MAX - 2;

	public static function pack(data:Bytes):Bytes {
		final out = new BytesBuffer();
		final held = new Array<Int>();

		if (data.length >= 2) {
			final words = new Array<Int>();
			for (i in 0...Std.int(data.length / 2)) words.push(data.get(i * 2) | (data.get(i * 2 + 1) << 8));

			final runs = new Map<Int, Array<{offset:Int, repeat:Int}>>();
			var at = 0;
			while (at < words.length) {
				final from = at;
				final value = words[at++];

				var repeat = 0;
				while (at < words.length && words[at] == value) {
					repeat++;
					at++;
				}

				var list = runs.get(value);
				if (list == null) {
					list = [];
					runs.set(value, list);
				}
				list.push({offset: from, repeat: repeat});
			}

			final matches = new Array<Null<Segment>>();
			for (i in 0...words.length) matches.push(best(runs, words, i));

			final costs = new Array<Int>();
			for (_ in 0...matches.length + 1) costs.push(0);

			var i = matches.length - 1;
			while (i >= 0) {
				final asLiteral = costs[i + 1] + 1;
				var asMatch = 0x7FFFFFFF;

				final match = matches[i];
				if (match != null) asMatch = match.cost + costs[i + match.length];

				if (asLiteral < asMatch) {
					costs[i] = asLiteral;
					matches[i] = null;
				} else {
					costs[i] = asMatch;
				}
				i--;
			}

			final literal = new Array<Int>();
			var ind = 0;
			while (ind < matches.length) {
				final match = matches[ind];

				if (match != null) {
					segment(held, literal, match);
					ind += match.length;
					literal.splice(0, literal.length);
				} else {
					final word = words[ind++];
					literal.push(word & 0xFF);
					literal.push((word >> 8) & 0xFF);
				}
			}

			if (literal.length > 0) {
				segment(held, literal, null);
				literal.splice(0, literal.length);
			}

			segment(held, literal, null);
		}

		if ((data.length & 1) != 0) {
			held.push(0x80);
			held.push(data.get(data.length - 1));
		} else {
			held.push(0x00);
			held.push(0x00);
		}

		for (value in held) out.addByte(value & 0xFF);
		return out.getBytes();
	}

	static function best(runs:Map<Int, Array<{offset:Int, repeat:Int}>>, words:Array<Int>, ind:Int):Null<Segment> {
		if (ind < 1) return null;

		final list = runs.get(words[ind]);
		if (list == null) return null;

		final least = ind - LONG_OFFSET_MAX > 0 ? ind - LONG_OFFSET_MAX : 0;

		var start = 0;
		while (start < list.length) {
			final run = list[start];
			if (run.offset + run.repeat >= least) break;
			start++;
		}

		final here = repeatAt(words, ind);

		var found:Null<Segment> = null;
		var saved = 1;

		while (start < list.length) {
			final run = list[start];

			var offset = run.offset;
			var repeat = run.repeat;

			if (offset >= ind) break;

			if (offset < least) {
				repeat -= least - offset;
				offset = least;
			}

			if (repeat < here) {
				final length = repeat + 1 < LONG_MATCH_MAX ? repeat + 1 : LONG_MATCH_MAX;
				final match = new Segment(ind, offset, length);

				if (match.saved >= saved) {
					found = match;
					saved = match.saved;
					if (saved == MOST_SAVED) return found;
				}
			} else {
				if (repeat > here) {
					var delta = repeat - here;
					if (offset + delta >= ind) delta = (ind - offset) - 1;
					offset += delta;
					repeat -= delta;
				}

				var match:Segment;

				if (repeat > 0) {
					if (offset + repeat >= ind) repeat = (ind - offset) - 1;
					final inner = longest(words, offset + repeat, ind + repeat);
					final grown = inner.length + repeat;
					match = new Segment(inner.at - repeat, inner.from - repeat,
						grown < LONG_MATCH_MAX ? grown : LONG_MATCH_MAX);
				} else {
					match = longest(words, offset, ind);
				}

				if (match.saved >= saved) {
					found = match;
					saved = match.saved;
					if (saved == MOST_SAVED) return found;
				}
			}

			start++;
		}

		return found;
	}

	static function longest(words:Array<Int>, from:Int, ind:Int):Segment {
		var reference = from;
		var current = ind;
		var length = 0;

		while (current < words.length && words[reference++] == words[current++] && length < LONG_MATCH_MAX) length++;

		return new Segment(ind, from, length);
	}

	static function repeatAt(words:Array<Int>, ind:Int):Int {
		final value = words[ind];
		var at = ind + 1;
		while (at < words.length && words[at] == value) at++;
		return (at - ind) - 1;
	}

	static function segment(held:Array<Int>, literal:Array<Int>, match:Null<Segment>):Void {
		var length = Std.int(literal.length / 2);
		var offset = 0;

		while (length > LITERAL_MAX) {
			held.push((LITERAL_MAX & 0xF) << 4);
			held.push(0);
			for (i in 0...LITERAL_MAX * 2) held.push(literal[offset + i]);

			offset += LITERAL_MAX * 2;
			length -= LITERAL_MAX;
		}

		final matchLength = match == null ? 0 : match.length;
		var matchOffset = match == null ? 0 : match.offset();

		if (matchLength > 0 || length > 0) {
			if (match != null && match.long) {
				held.push((length & 0xF) << 4);
				held.push(matchLength - LONG_MATCH_MIN);
			} else if (matchLength != 0) {
				held.push(((length & 0xF) << 4) | ((matchLength - MATCH_MIN) & 0xF));
				held.push(matchOffset - OFFSET_MIN);
			} else {
				held.push((length & 0xF) << 4);
				held.push(0);
			}

			for (i in 0...length * 2) held.push(literal[offset + i]);

			if (match != null && match.long) {
				matchOffset = (-(matchOffset - LONG_OFFSET_MIN)) & LONG_OFFSET_MASK;
				held.push((matchOffset >> 8) & 0xFF);
				held.push(matchOffset & 0xFF);
			}
		} else {
			held.push(0);
			held.push(0);
		}
	}
}
#end

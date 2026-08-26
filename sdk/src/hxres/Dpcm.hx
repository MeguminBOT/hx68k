package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;

class Dpcm {
	static final DELTA = [-34, -21, -13, -8, -5, -3, -2, -1, 0, 1, 2, 3, 5, 8, 13, 21];

	public static function pack(source:Bytes):Bytes {
		final out = Bytes.alloc(Std.int(source.length / 2) + (source.length & 1));
		var level:Int = 0;
		var at:Int = 0;
		var index:Int = 0;

		while (index < source.length) {
			var chosen:Int = nearest(signed(source.get(index)), level);
			level += DELTA[chosen];
			var held:Int = chosen;

			chosen = nearest(index + 1 < source.length ? signed(source.get(index + 1)) : 0, level);
			level += DELTA[chosen];
			held |= chosen << 4;

			out.set(at++, held);
			index += 2;
		}

		return out;
	}

	static inline function signed(value:Int):Int {
		return (value & 0xFF) > 127 ? (value & 0xFF) - 256 : (value & 0xFF);
	}

	static function nearest(wanted:Int, level:Int):Int {
		final gap:Int = wanted - level;
		var chosen:Int = 0;
		var closest:Int = abs(gap - DELTA[0]);

		for (index in 1...16) {
			final apart:Int = abs(gap - DELTA[index]);
			if (apart < closest) {
				closest = apart;
				chosen = index;
			}
		}

		final reached:Int = DELTA[chosen] + level;
		if (reached > 127) return chosen - 1;
		if (reached < -128) return chosen + 1;
		return chosen;
	}

	static inline function abs(value:Int):Int {
		return value < 0 ? -value : value;
	}
}
#end

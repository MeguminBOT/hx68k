package hxres;

#if (macro || md_runtime)
class HashOrder {
	static inline final CAPACITY = 16;

	static inline final TREEIFY = 8;

	static inline final TREEIFY_CAPACITY = 64;

	public static function of<T>(items:Array<T>, at:T->Rect):Array<T> {
		var capacity = CAPACITY;
		var threshold = (capacity * 3) >> 2;

		final kept = new Array<T>();
		for (item in items) {
			var already = false;
			for (seen in kept) if (at(seen).same(at(item))) {
				already = true;
				break;
			}
			if (already) continue;

			kept.push(item);

			final index = spread(hash(at(item))) & (capacity - 1);
			var sharing = 0;
			for (seen in kept) if ((spread(hash(at(seen))) & (capacity - 1)) == index) sharing++;

			if (sharing > TREEIFY && capacity < TREEIFY_CAPACITY) {
				capacity <<= 1;
				threshold = (capacity * 3) >> 2;
			}

			if (kept.length > threshold) {
				capacity <<= 1;
				threshold = (capacity * 3) >> 2;
			}
		}

		final bins = new Array<Array<T>>();
		for (_ in 0...capacity) bins.push([]);

		for (item in kept) bins[spread(hash(at(item))) & (capacity - 1)].push(item);

		final out = new Array<T>();
		for (bin in bins) for (item in bin) out.push(item);
		return out;
	}

	public static function hash(rect:Rect):Int {
		var low = 0;
		var high = 0;

		final parts = [rect.x, rect.y, rect.width, rect.height];
		final weights = [1, 37, 43, 47];

		for (i in 0...4) {
			final bits = doubleBits(parts[i]);
			final scaledLow = mixLow(bits.low, weights[i]);
			final scaledHigh = mixHigh(bits.low, bits.high, weights[i]);

			final sum = addLow(low, scaledLow);
			high = wrap(high + scaledHigh + sum.carry);
			low = sum.low;
		}

		return low ^ high;
	}

	static inline function spread(value:Int):Int {
		return value ^ (value >>> 16);
	}

	static function doubleBits(value:Int):{low:Int, high:Int} {
		if (value == 0) return {low: 0, high: 0};

		final negative = value < 0;
		var magnitude = negative ? -value : value;

		var exponent = 0;
		var shifted = magnitude;
		while (shifted > 1) {
			shifted >>>= 1;
			exponent++;
		}

		final biased = exponent + 1023;
		final fraction = magnitude - (1 << exponent);
		final bits = 52 - exponent;

		var high = (negative ? 0x80000000 : 0) | (biased << 20);
		var low = 0;

		if (bits >= 32) {
			high = high | wrap(fraction << (bits - 32));
		} else {
			low = wrap(fraction << bits);
			high = high | (fraction >>> (32 - bits));
		}

		return {low: low, high: wrap(high)};
	}

	static function mixLow(low:Int, weight:Int):Int {
		return wrap(low * weight);
	}

	static function mixHigh(low:Int, high:Int, weight:Int):Int {
		final lowUpper = (low >>> 16) & 0xFFFF;
		final lowLower = low & 0xFFFF;
		final carry = ((lowLower * weight) >>> 16) + (lowUpper * weight);
		return wrap((high * weight) + (carry >>> 16));
	}

	static function addLow(left:Int, right:Int):{low:Int, carry:Int} {
		final sum = (left & 0xFFFF) + (right & 0xFFFF);
		final upper = ((left >>> 16) & 0xFFFF) + ((right >>> 16) & 0xFFFF) + (sum >>> 16);
		return {low: wrap(((upper & 0xFFFF) << 16) | (sum & 0xFFFF)), carry: (upper >>> 16) & 1};
	}

	static inline function wrap(value:Int):Int {
		return value | 0;
	}
}
#end

package md;

class Maths {
	public static inline final FRACTION = 6;

	public static function nextPowerOfTwo(value:UInt32):UInt32 {
		var found:Int = (value : Int) - 1;

		found |= found >> 1;
		found |= found >> 2;
		found |= found >> 4;
		found |= found >> 8;
		found |= found >> 16;

		return found + 1;
	}

	public static function log2(value:UInt32):UInt16 {
		final whole:Int = value;
		var result:Int = 0;
		var left:Int = whole;

		if (left > 0xFFFF) {
			result = 16;
			left >>= 16;
		}

		if (left >= 0x0100) {
			result += 8;
			left >>= 8;
		}

		if (left >= 0x0010) {
			result += 4;
			left >>= 4;
		}

		if (left >= 0x0004) {
			result += 2;
			left >>= 2;
		}

		return result | (left >> 1);
	}

	public static function approximateDistance(dx:Int, dy:Int):UInt32 {
		final across:Int = dx < 0 ? -dx : dx;
		final down:Int = dy < 0 ? -dy : dy;
		final least:Int = across < down ? across : down;
		final most:Int = across < down ? down : across;

		return ((most << 8) + (most << 3) - (most << 4) - (most << 1)
			+ (least << 7) - (least << 5) + (least << 3) - (least << 1)) >> 8;
	}

	public static function root(value:UInt32):UInt32 {
		var left:Int = value;
		var result:Int = 0;
		var bit:Int = 1 << 30;

		while (bit > left) bit >>= 2;

		while (bit != 0) {
			if (left >= result + bit) {
				left -= result + bit;
				result = (result >> 1) + bit;
			} else {
				result >>= 1;
			}

			bit >>= 2;
		}

		return result;
	}

	public static inline function sqrt(value:Fix16):Fix16 {
		return cast((root((value : Int) << FRACTION) : Int));
	}
}

package md;

class Format {
	public static function writeInt(value:Int, into:Vector<UInt8>, at:Int):Int {
		var pos = at;
		var rest = value;

		if (rest < 0) {
			into[pos] = 45;
			pos++;
			rest = -rest;
		}

		var scale = 1;
		var count = rest;
		while (count >= 10) {
			count = Std.int(count / 10);
			scale *= 10;
		}

		while (scale > 0) {
			into[pos] = 48 + Std.int(rest / scale) % 10;
			pos++;
			scale = Std.int(scale / 10);
		}

		into[pos] = 0;
		return pos;
	}
}

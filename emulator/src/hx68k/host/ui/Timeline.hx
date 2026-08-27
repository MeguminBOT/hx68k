package hx68k.host.ui;

class Timeline {
	public static inline final LEAST = 14.0;

	public static function thumbWidth(span:Int, width:Float):Float {
		if (span <= 1 || width <= LEAST) return width;
		final share = width / span;
		return share < LEAST ? LEAST : share;
	}

	public static function thumbAt(span:Int, position:Int, width:Float):Float {
		final travel = width - thumbWidth(span, width);
		if (span <= 1 || travel <= 0) return 0;

		final held = position < 0 ? 0 : (position >= span ? span - 1 : position);
		return travel * held / (span - 1);
	}

	public static function pick(span:Int, x:Float, width:Float):Int {
		final thumb = thumbWidth(span, width);
		final travel = width - thumb;
		if (span <= 1 || travel <= 0) return 0;

		final along = (x - thumb * 0.5) / travel;
		final chosen = Math.round(along * (span - 1));
		return chosen < 0 ? 0 : (chosen >= span ? span - 1 : chosen);
	}
}

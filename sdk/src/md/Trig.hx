package md;

@:build(mdcompiler.Tables.sine())
class Trig {
	public static inline final DEGREES = 360;

	public static function sin(degrees:Int):Fix16 {
		var turn:Int = degrees % DEGREES;
		if (turn < 0) turn += DEGREES;

		if (turn <= 90) return cast quarter[turn];
		if (turn <= 180) return cast quarter[180 - turn];
		if (turn <= 270) return cast(-(quarter[turn - 180] : Int));
		return cast(-(quarter[360 - turn] : Int));
	}

	public static inline function cos(degrees:Int):Fix16 {
		return sin(degrees + 90);
	}
}

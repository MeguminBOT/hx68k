package md;

extern class Fix16Ops {
	@:native("F16_mul") static function mul(a:Fix16, b:Fix16):Fix16;
	@:native("F16_div") static function div(a:Fix16, b:Fix16):Fix16;
	@:native("F16_toInt") static function toInt(v:Fix16):Int;
	@:native("F16_frac") static function frac(v:Fix16):Fix16;
	@:native("F16_abs") static function abs(v:Fix16):Fix16;
}

@:md.type("fix16")
abstract Fix16(Int) from Int to Int {
	public static inline function of(value:Int):Fix16 {
		return cast(value << 6);
	}

	public inline function toInt():Int {
		return Fix16Ops.toInt(cast this);
	}

	public inline function frac():Fix16 {
		return Fix16Ops.frac(cast this);
	}

	public inline function abs():Fix16 {
		return Fix16Ops.abs(cast this);
	}

	@:op(A + B) static inline function add(a:Fix16, b:Fix16):Fix16 {
		return cast((a : Int) + (b : Int));
	}

	@:op(A - B) static inline function sub(a:Fix16, b:Fix16):Fix16 {
		return cast((a : Int) - (b : Int));
	}

	@:op(A * B) static inline function mul(a:Fix16, b:Fix16):Fix16 {
		return Fix16Ops.mul(a, b);
	}

	@:op(A / B) static inline function div(a:Fix16, b:Fix16):Fix16 {
		return Fix16Ops.div(a, b);
	}
}

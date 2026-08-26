package md;

@:md.type("fix16")
abstract Fix16(Int) from Int to Int {
	public static inline function of(value:Int):Fix16 {
		return cast(value << 6);
	}

	public inline function toInt():Int {
		return (this : Int) >> 6;
	}

	public inline function frac():Fix16 {
		return cast((this : Int) & 63);
	}

	public inline function abs():Fix16 {
		return cast((this : Int) < 0 ? -(this : Int) : (this : Int));
	}

	@:op(A + B) static inline function add(a:Fix16, b:Fix16):Fix16 {
		return cast((a : Int) + (b : Int));
	}

	@:op(A - B) static inline function sub(a:Fix16, b:Fix16):Fix16 {
		return cast((a : Int) - (b : Int));
	}

	@:op(A * B) static inline function mul(a:Fix16, b:Fix16):Fix16 {
		return cast(((a : Int) * (b : Int)) >> 6);
	}

	@:op(A / B) static inline function div(a:Fix16, b:Fix16):Fix16 {
		return cast(Std.int(((a : Int) << 6) / (b : Int)));
	}
}

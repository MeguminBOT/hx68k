package md;

@:md.type("s8")
abstract Int8(Int) from Int to Int {
	@:op(A < B) static inline function lt(a:Int8, b:Int8):Bool {
		return (a : Int) < (b : Int);
	}

	@:op(A <= B) static inline function le(a:Int8, b:Int8):Bool {
		return (a : Int) <= (b : Int);
	}

	@:op(A > B) static inline function gt(a:Int8, b:Int8):Bool {
		return (a : Int) > (b : Int);
	}

	@:op(A >= B) static inline function ge(a:Int8, b:Int8):Bool {
		return (a : Int) >= (b : Int);
	}

	@:op(A == B) static inline function eq(a:Int8, b:Int8):Bool {
		return (a : Int) == (b : Int);
	}

	@:op(A != B) static inline function ne(a:Int8, b:Int8):Bool {
		return (a : Int) != (b : Int);
	}

	@:op(A + B) static inline function add(a:Int8, b:Int8):Int {
		return (a : Int) + (b : Int);
	}

	@:op(A - B) static inline function sub(a:Int8, b:Int8):Int {
		return (a : Int) - (b : Int);
	}

	@:op(A * B) static inline function mul(a:Int8, b:Int8):Int {
		return (a : Int) * (b : Int);
	}

	@:op(A % B) static inline function mod(a:Int8, b:Int8):Int {
		return (a : Int) % (b : Int);
	}

	@:op(A & B) static inline function and(a:Int8, b:Int8):Int {
		return (a : Int) & (b : Int);
	}

	@:op(A | B) static inline function or(a:Int8, b:Int8):Int {
		return (a : Int) | (b : Int);
	}

	@:op(A ^ B) static inline function xor(a:Int8, b:Int8):Int {
		return (a : Int) ^ (b : Int);
	}

	@:op(A << B) static inline function shl(a:Int8, b:Int8):Int {
		return (a : Int) << (b : Int);
	}

	@:op(A >> B) static inline function shr(a:Int8, b:Int8):Int {
		return (a : Int) >> (b : Int);
	}

	@:op(A >>> B) static inline function ushr(a:Int8, b:Int8):Int {
		return (a : Int) >>> (b : Int);
	}

	@:op(A / B) static inline function div(a:Int8, b:Int8):Int {
		return Std.int((a : Int) / (b : Int));
	}

	@:op(-A) static inline function neg(a:Int8):Int {
		return -(a : Int);
	}

	@:op(~A) static inline function not(a:Int8):Int {
		return ~(a : Int);
	}
}

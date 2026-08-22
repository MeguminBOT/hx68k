package md;

@:md.type("s16")
abstract Int16(Int) from Int to Int {
	@:op(A < B) static inline function lt(a:Int16, b:Int16):Bool {
		return (a : Int) < (b : Int);
	}

	@:op(A <= B) static inline function le(a:Int16, b:Int16):Bool {
		return (a : Int) <= (b : Int);
	}

	@:op(A > B) static inline function gt(a:Int16, b:Int16):Bool {
		return (a : Int) > (b : Int);
	}

	@:op(A >= B) static inline function ge(a:Int16, b:Int16):Bool {
		return (a : Int) >= (b : Int);
	}

	@:op(A == B) static inline function eq(a:Int16, b:Int16):Bool {
		return (a : Int) == (b : Int);
	}

	@:op(A != B) static inline function ne(a:Int16, b:Int16):Bool {
		return (a : Int) != (b : Int);
	}

	@:op(A + B) static inline function add(a:Int16, b:Int16):Int {
		return (a : Int) + (b : Int);
	}

	@:op(A - B) static inline function sub(a:Int16, b:Int16):Int {
		return (a : Int) - (b : Int);
	}

	@:op(A * B) static inline function mul(a:Int16, b:Int16):Int {
		return (a : Int) * (b : Int);
	}

	@:op(A % B) static inline function mod(a:Int16, b:Int16):Int {
		return (a : Int) % (b : Int);
	}

	@:op(A & B) static inline function and(a:Int16, b:Int16):Int {
		return (a : Int) & (b : Int);
	}

	@:op(A | B) static inline function or(a:Int16, b:Int16):Int {
		return (a : Int) | (b : Int);
	}

	@:op(A ^ B) static inline function xor(a:Int16, b:Int16):Int {
		return (a : Int) ^ (b : Int);
	}

	@:op(A << B) static inline function shl(a:Int16, b:Int16):Int {
		return (a : Int) << (b : Int);
	}

	@:op(A >> B) static inline function shr(a:Int16, b:Int16):Int {
		return (a : Int) >> (b : Int);
	}

	@:op(A >>> B) static inline function ushr(a:Int16, b:Int16):Int {
		return (a : Int) >>> (b : Int);
	}

	@:op(A / B) static inline function div(a:Int16, b:Int16):Int {
		return Std.int((a : Int) / (b : Int));
	}

	@:op(-A) static inline function neg(a:Int16):Int {
		return -(a : Int);
	}

	@:op(~A) static inline function not(a:Int16):Int {
		return ~(a : Int);
	}
}

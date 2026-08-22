package md;

@:md.type("s32")
abstract Int32(Int) from Int to Int {
	@:op(A < B) static inline function lt(a:Int32, b:Int32):Bool {
		return (a : Int) < (b : Int);
	}

	@:op(A <= B) static inline function le(a:Int32, b:Int32):Bool {
		return (a : Int) <= (b : Int);
	}

	@:op(A > B) static inline function gt(a:Int32, b:Int32):Bool {
		return (a : Int) > (b : Int);
	}

	@:op(A >= B) static inline function ge(a:Int32, b:Int32):Bool {
		return (a : Int) >= (b : Int);
	}

	@:op(A == B) static inline function eq(a:Int32, b:Int32):Bool {
		return (a : Int) == (b : Int);
	}

	@:op(A != B) static inline function ne(a:Int32, b:Int32):Bool {
		return (a : Int) != (b : Int);
	}

	@:op(A + B) static inline function add(a:Int32, b:Int32):Int {
		return (a : Int) + (b : Int);
	}

	@:op(A - B) static inline function sub(a:Int32, b:Int32):Int {
		return (a : Int) - (b : Int);
	}

	@:op(A * B) static inline function mul(a:Int32, b:Int32):Int {
		return (a : Int) * (b : Int);
	}

	@:op(A % B) static inline function mod(a:Int32, b:Int32):Int {
		return (a : Int) % (b : Int);
	}

	@:op(A & B) static inline function and(a:Int32, b:Int32):Int {
		return (a : Int) & (b : Int);
	}

	@:op(A | B) static inline function or(a:Int32, b:Int32):Int {
		return (a : Int) | (b : Int);
	}

	@:op(A ^ B) static inline function xor(a:Int32, b:Int32):Int {
		return (a : Int) ^ (b : Int);
	}

	@:op(A << B) static inline function shl(a:Int32, b:Int32):Int {
		return (a : Int) << (b : Int);
	}

	@:op(A >> B) static inline function shr(a:Int32, b:Int32):Int {
		return (a : Int) >> (b : Int);
	}

	@:op(A >>> B) static inline function ushr(a:Int32, b:Int32):Int {
		return (a : Int) >>> (b : Int);
	}

	@:op(A / B) static inline function div(a:Int32, b:Int32):Int {
		return Std.int((a : Int) / (b : Int));
	}

	@:op(-A) static inline function neg(a:Int32):Int {
		return -(a : Int);
	}

	@:op(~A) static inline function not(a:Int32):Int {
		return ~(a : Int);
	}
}

package md;

@:md.type("u32")
abstract UInt32(Int) from Int to Int {
	@:op(A < B) static inline function lt(a:UInt32, b:UInt32):Bool {
		return (a : Int) < (b : Int);
	}

	@:op(A <= B) static inline function le(a:UInt32, b:UInt32):Bool {
		return (a : Int) <= (b : Int);
	}

	@:op(A > B) static inline function gt(a:UInt32, b:UInt32):Bool {
		return (a : Int) > (b : Int);
	}

	@:op(A >= B) static inline function ge(a:UInt32, b:UInt32):Bool {
		return (a : Int) >= (b : Int);
	}

	@:op(A == B) static inline function eq(a:UInt32, b:UInt32):Bool {
		return (a : Int) == (b : Int);
	}

	@:op(A != B) static inline function ne(a:UInt32, b:UInt32):Bool {
		return (a : Int) != (b : Int);
	}

	@:op(A + B) static inline function add(a:UInt32, b:UInt32):Int {
		return (a : Int) + (b : Int);
	}

	@:op(A - B) static inline function sub(a:UInt32, b:UInt32):Int {
		return (a : Int) - (b : Int);
	}

	@:op(A * B) static inline function mul(a:UInt32, b:UInt32):Int {
		return (a : Int) * (b : Int);
	}

	@:op(A % B) static inline function mod(a:UInt32, b:UInt32):Int {
		return (a : Int) % (b : Int);
	}

	@:op(A & B) static inline function and(a:UInt32, b:UInt32):Int {
		return (a : Int) & (b : Int);
	}

	@:op(A | B) static inline function or(a:UInt32, b:UInt32):Int {
		return (a : Int) | (b : Int);
	}

	@:op(A ^ B) static inline function xor(a:UInt32, b:UInt32):Int {
		return (a : Int) ^ (b : Int);
	}

	@:op(A << B) static inline function shl(a:UInt32, b:UInt32):Int {
		return (a : Int) << (b : Int);
	}

	@:op(A >> B) static inline function shr(a:UInt32, b:UInt32):Int {
		return (a : Int) >> (b : Int);
	}

	@:op(A >>> B) static inline function ushr(a:UInt32, b:UInt32):Int {
		return (a : Int) >>> (b : Int);
	}

	@:op(A / B) static inline function div(a:UInt32, b:UInt32):Int {
		return Std.int((a : Int) / (b : Int));
	}

	@:op(-A) static inline function neg(a:UInt32):Int {
		return -(a : Int);
	}

	@:op(~A) static inline function not(a:UInt32):Int {
		return ~(a : Int);
	}
}

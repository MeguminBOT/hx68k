package md;

@:md.type("u16")
abstract UInt16(Int) from Int to Int {
	@:op(A < B) static inline function lt(a:UInt16, b:UInt16):Bool {
		return (a : Int) < (b : Int);
	}

	@:op(A <= B) static inline function le(a:UInt16, b:UInt16):Bool {
		return (a : Int) <= (b : Int);
	}

	@:op(A > B) static inline function gt(a:UInt16, b:UInt16):Bool {
		return (a : Int) > (b : Int);
	}

	@:op(A >= B) static inline function ge(a:UInt16, b:UInt16):Bool {
		return (a : Int) >= (b : Int);
	}

	@:op(A == B) static inline function eq(a:UInt16, b:UInt16):Bool {
		return (a : Int) == (b : Int);
	}

	@:op(A != B) static inline function ne(a:UInt16, b:UInt16):Bool {
		return (a : Int) != (b : Int);
	}

	@:op(A + B) static inline function add(a:UInt16, b:UInt16):Int {
		return (a : Int) + (b : Int);
	}

	@:op(A - B) static inline function sub(a:UInt16, b:UInt16):Int {
		return (a : Int) - (b : Int);
	}

	@:op(A * B) static inline function mul(a:UInt16, b:UInt16):Int {
		return (a : Int) * (b : Int);
	}

	@:op(A % B) static inline function mod(a:UInt16, b:UInt16):Int {
		return (a : Int) % (b : Int);
	}

	@:op(A & B) static inline function and(a:UInt16, b:UInt16):Int {
		return (a : Int) & (b : Int);
	}

	@:op(A | B) static inline function or(a:UInt16, b:UInt16):Int {
		return (a : Int) | (b : Int);
	}

	@:op(A ^ B) static inline function xor(a:UInt16, b:UInt16):Int {
		return (a : Int) ^ (b : Int);
	}

	@:op(A << B) static inline function shl(a:UInt16, b:UInt16):Int {
		return (a : Int) << (b : Int);
	}

	@:op(A >> B) static inline function shr(a:UInt16, b:UInt16):Int {
		return (a : Int) >> (b : Int);
	}

	@:op(A >>> B) static inline function ushr(a:UInt16, b:UInt16):Int {
		return (a : Int) >>> (b : Int);
	}

	@:op(A / B) static inline function div(a:UInt16, b:UInt16):Int {
		return Std.int((a : Int) / (b : Int));
	}

	@:op(-A) static inline function neg(a:UInt16):Int {
		return -(a : Int);
	}

	@:op(~A) static inline function not(a:UInt16):Int {
		return ~(a : Int);
	}
}

package md;

@:md.type("u8")
abstract UInt8(Int) from Int to Int {
	@:op(A < B) static inline function lt(a:UInt8, b:UInt8):Bool {
		return (a : Int) < (b : Int);
	}

	@:op(A <= B) static inline function le(a:UInt8, b:UInt8):Bool {
		return (a : Int) <= (b : Int);
	}

	@:op(A > B) static inline function gt(a:UInt8, b:UInt8):Bool {
		return (a : Int) > (b : Int);
	}

	@:op(A >= B) static inline function ge(a:UInt8, b:UInt8):Bool {
		return (a : Int) >= (b : Int);
	}

	@:op(A == B) static inline function eq(a:UInt8, b:UInt8):Bool {
		return (a : Int) == (b : Int);
	}

	@:op(A != B) static inline function ne(a:UInt8, b:UInt8):Bool {
		return (a : Int) != (b : Int);
	}

	@:op(A + B) static inline function add(a:UInt8, b:UInt8):Int {
		return (a : Int) + (b : Int);
	}

	@:op(A - B) static inline function sub(a:UInt8, b:UInt8):Int {
		return (a : Int) - (b : Int);
	}

	@:op(A * B) static inline function mul(a:UInt8, b:UInt8):Int {
		return (a : Int) * (b : Int);
	}

	@:op(A % B) static inline function mod(a:UInt8, b:UInt8):Int {
		return (a : Int) % (b : Int);
	}

	@:op(A & B) static inline function and(a:UInt8, b:UInt8):Int {
		return (a : Int) & (b : Int);
	}

	@:op(A | B) static inline function or(a:UInt8, b:UInt8):Int {
		return (a : Int) | (b : Int);
	}

	@:op(A ^ B) static inline function xor(a:UInt8, b:UInt8):Int {
		return (a : Int) ^ (b : Int);
	}

	@:op(A << B) static inline function shl(a:UInt8, b:UInt8):Int {
		return (a : Int) << (b : Int);
	}

	@:op(A >> B) static inline function shr(a:UInt8, b:UInt8):Int {
		return (a : Int) >> (b : Int);
	}

	@:op(A >>> B) static inline function ushr(a:UInt8, b:UInt8):Int {
		return (a : Int) >>> (b : Int);
	}

	@:op(A / B) static inline function div(a:UInt8, b:UInt8):Int {
		return Std.int((a : Int) / (b : Int));
	}

	@:op(-A) static inline function neg(a:UInt8):Int {
		return -(a : Int);
	}

	@:op(~A) static inline function not(a:UInt8):Int {
		return ~(a : Int);
	}
}

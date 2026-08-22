package hx68k.cpu.z80;

class Arithmetic {
	public static function add(c:Z80, value:Int, carry:Int):Void {
		final total = c.a + value + carry;
		final result = total & 0xFF;
		final half = (c.a & 0x0F) + (value & 0x0F) + carry;
		final overflow = (~(c.a ^ value) & (c.a ^ result) & 0x80) != 0;

		c.setF((result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result)
			| (half > 0x0F ? Z80.HALF : 0) | (overflow ? Z80.PARITY : 0)
			| (total > 0xFF ? Z80.CARRY : 0));
		c.a = result;
	}

	public static function subtract(c:Z80, value:Int, carry:Int):Void {
		final total = c.a - value - carry;
		final result = total & 0xFF;
		final half = (c.a & 0x0F) - (value & 0x0F) - carry;
		final overflow = ((c.a ^ value) & (c.a ^ result) & 0x80) != 0;

		c.setF((result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result)
			| (half < 0 ? Z80.HALF : 0) | (overflow ? Z80.PARITY : 0) | Z80.SUBTRACT
			| (total < 0 ? Z80.CARRY : 0));
		c.a = result;
	}

	public static function compare(c:Z80, value:Int):Void {
		final total = c.a - value;
		final result = total & 0xFF;
		final half = (c.a & 0x0F) - (value & 0x0F);
		final overflow = ((c.a ^ value) & (c.a ^ result) & 0x80) != 0;

		c.setF((result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(value)
			| (half < 0 ? Z80.HALF : 0) | (overflow ? Z80.PARITY : 0) | Z80.SUBTRACT
			| (total < 0 ? Z80.CARRY : 0));
	}

	public static function and(c:Z80, value:Int):Void {
		final result = c.a & value;
		c.setF((result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result) | Z80.HALF
			| (Z80.parity(result) ? Z80.PARITY : 0));
		c.a = result;
	}

	public static function or(c:Z80, value:Int):Void {
		final result = c.a | value;
		c.setF((result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result)
			| (Z80.parity(result) ? Z80.PARITY : 0));
		c.a = result;
	}

	public static function xor(c:Z80, value:Int):Void {
		final result = c.a ^ value;
		c.setF((result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result)
			| (Z80.parity(result) ? Z80.PARITY : 0));
		c.a = result;
	}

	public static function increment(c:Z80, value:Int):Int {
		final result = (value + 1) & 0xFF;
		c.setF((c.f & Z80.CARRY) | (result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result)
			| ((result & 0x0F) == 0 ? Z80.HALF : 0) | (result == 0x80 ? Z80.PARITY : 0));
		return result;
	}

	public static function decrement(c:Z80, value:Int):Int {
		final result = (value - 1) & 0xFF;
		c.setF((c.f & Z80.CARRY) | (result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result)
			| ((result & 0x0F) == 0x0F ? Z80.HALF : 0) | (result == 0x7F ? Z80.PARITY : 0)
			| Z80.SUBTRACT);
		return result;
	}

	public static function addWord(c:Z80, left:Int, right:Int):Int {
		final total = left + right;
		final result = total & 0xFFFF;
		final half = (left & 0x0FFF) + (right & 0x0FFF);

		c.setF((c.f & (Z80.SIGN | Z80.ZERO | Z80.PARITY)) | c.bits(result >> 8)
			| (half > 0x0FFF ? Z80.HALF : 0) | (total > 0xFFFF ? Z80.CARRY : 0));
		return result;
	}

	public static function decimal(c:Z80):Void {
		var adjust = 0;
		var carry = (c.f & Z80.CARRY) != 0;

		if ((c.f & Z80.HALF) != 0 || (c.a & 0x0F) > 9) adjust |= 0x06;
		if (carry || c.a > 0x99) {
			adjust |= 0x60;
			carry = true;
		}

		final result = ((c.f & Z80.SUBTRACT) != 0 ? c.a - adjust : c.a + adjust) & 0xFF;
		final half = (c.f & Z80.SUBTRACT) != 0
			? (c.f & Z80.HALF) != 0 && (c.a & 0x0F) < 6
			: (c.a & 0x0F) > 9;

		c.setF((result & Z80.SIGN) | (result == 0 ? Z80.ZERO : 0) | c.bits(result)
			| (half ? Z80.HALF : 0) | (Z80.parity(result) ? Z80.PARITY : 0)
			| (c.f & Z80.SUBTRACT) | (carry ? Z80.CARRY : 0));
		c.a = result;
	}

	public static function rotateLeftCircular(c:Z80):Void {
		final carry = (c.a >> 7) & 1;
		c.a = ((c.a << 1) | carry) & 0xFF;
		c.setF((c.f & (Z80.SIGN | Z80.ZERO | Z80.PARITY)) | c.bits(c.a) | carry);
	}

	public static function rotateRightCircular(c:Z80):Void {
		final carry = c.a & 1;
		c.a = ((c.a >> 1) | (carry << 7)) & 0xFF;
		c.setF((c.f & (Z80.SIGN | Z80.ZERO | Z80.PARITY)) | c.bits(c.a) | carry);
	}

	public static function rotateLeft(c:Z80):Void {
		final carry = (c.a >> 7) & 1;
		c.a = ((c.a << 1) | (c.f & Z80.CARRY)) & 0xFF;
		c.setF((c.f & (Z80.SIGN | Z80.ZERO | Z80.PARITY)) | c.bits(c.a) | carry);
	}

	public static function rotateRight(c:Z80):Void {
		final carry = c.a & 1;
		c.a = ((c.a >> 1) | ((c.f & Z80.CARRY) << 7)) & 0xFF;
		c.setF((c.f & (Z80.SIGN | Z80.ZERO | Z80.PARITY)) | c.bits(c.a) | carry);
	}

	public static function complement(c:Z80):Void {
		c.a = (~c.a) & 0xFF;
		c.setF((c.f & (Z80.SIGN | Z80.ZERO | Z80.PARITY | Z80.CARRY)) | c.bits(c.a)
			| Z80.HALF | Z80.SUBTRACT);
	}

	public static function setCarry(c:Z80):Void {
		final loose = (c.a | (c.previousQ ^ c.f)) & (Z80.Y | Z80.X);
		c.setF((c.f & (Z80.SIGN | Z80.ZERO | Z80.PARITY)) | loose | Z80.CARRY);
	}

	public static function complementCarry(c:Z80):Void {
		final loose = (c.a | (c.previousQ ^ c.f)) & (Z80.Y | Z80.X);
		final carry = c.f & Z80.CARRY;
		c.setF((c.f & (Z80.SIGN | Z80.ZERO | Z80.PARITY)) | loose | (carry != 0 ? Z80.HALF : 0)
			| (carry != 0 ? 0 : Z80.CARRY));
	}
}

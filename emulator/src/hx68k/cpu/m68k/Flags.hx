package hx68k.cpu.m68k;

import hx68k.cpu.m68k.Addressing.*;

class Flags {
	public static inline function setNz(c:M68000, value:Int, size:Int):Void {
		c.nf = (value & msb(size)) != 0;
		c.zf = (value & mask(size)) == 0;
	}

	public static inline function setLogicFlags(c:M68000, value:Int, size:Int):Void {
		setNz(c, value, size);
		c.vf = false;
		c.cf = false;
	}

	public static inline function settleFlags(c:M68000, value:Int, size:Int, earlyNz:Bool, earlyVc:Bool):Void {
		if (!earlyNz) setNz(c, value, size);
		if (!earlyVc) {
			c.vf = false;
			c.cf = false;
		}
	}

	public static function condition(c:M68000, cc:Int):Bool {
		return switch (cc) {
			case 0: true;
			case 1: false;
			case 2: !c.cf && !c.zf;
			case 3: c.cf || c.zf;
			case 4: !c.cf;
			case 5: c.cf;
			case 6: !c.zf;
			case 7: c.zf;
			case 8: !c.vf;
			case 9: c.vf;
			case 10: !c.nf;
			case 11: c.nf;
			case 12: c.nf == c.vf;
			case 13: c.nf != c.vf;
			case 14: !c.zf && (c.nf == c.vf);
			default: c.zf || (c.nf != c.vf);
		}
	}
}

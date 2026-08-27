package md;

import md.hw.Vdp as Ports;

class Palette {
	public static inline final COLORS = 64;

	public static inline final PER_PALETTE = 16;

	public static inline final MASK = 0x0EEE;

	public static inline function setColor(index:UInt16, value:UInt16):Void {
		Ports.color(index, value);
	}

	public static inline function color(index:UInt16):UInt16 {
		Ports.address(Ports.CRAM_READ, index * 2);
		return Ports.read() & MASK;
	}

	public static function setColors(index:UInt16, from:Vector<UInt16>, count:UInt16):Void {
		Ports.autoIncrement(2);
		Ports.address(Ports.CRAM_WRITE, index * 2);

		var i = 0;
		while (i < count) {
			Ports.write(from[i]);
			i++;
		}
	}

	public static function colors(index:UInt16, into:Vector<UInt16>, count:UInt16):Void {
		Ports.autoIncrement(2);
		Ports.address(Ports.CRAM_READ, index * 2);

		var i = 0;
		while (i < count) {
			into[i] = Ports.read() & MASK;
			i++;
		}
	}

	public static function load(index:UInt16, from:md.res.Palette):Void {
		setColors(index, from.data, from.length);
	}

	public static inline function setPalette(palette:UInt16, from:Vector<UInt16>):Void {
		setColors(palette * PER_PALETTE, from, PER_PALETTE);
	}

	public static inline function palette(which:UInt16, into:Vector<UInt16>):Void {
		colors(which * PER_PALETTE, into, PER_PALETTE);
	}
}

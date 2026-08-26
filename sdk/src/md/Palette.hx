package md;

import md.hw.Vdp as Ports;

class Palette {
	public static inline final COLOURS = 64;

	public static inline final PER_PALETTE = 16;

	public static inline final MASK = 0x0EEE;

	public static inline function setColour(index:UInt16, value:UInt16):Void {
		Ports.colour(index, value);
	}

	public static inline function colour(index:UInt16):UInt16 {
		Ports.address(Ports.CRAM_READ, index * 2);
		return Ports.read() & MASK;
	}

	public static function setColours(index:UInt16, from:Vector<UInt16>, count:UInt16):Void {
		Ports.autoIncrement(2);
		Ports.address(Ports.CRAM_WRITE, index * 2);

		var i = 0;
		while (i < count) {
			Ports.write(from[i]);
			i++;
		}
	}

	public static function colours(index:UInt16, into:Vector<UInt16>, count:UInt16):Void {
		Ports.autoIncrement(2);
		Ports.address(Ports.CRAM_READ, index * 2);

		var i = 0;
		while (i < count) {
			into[i] = Ports.read() & MASK;
			i++;
		}
	}

	public static function setFromResource(index:UInt16, palette:md.res.Palette):Void {
		setColours(index, palette.data, palette.length);
	}

	public static inline function setPalette(which:UInt16, from:Vector<UInt16>):Void {
		setColours(which * PER_PALETTE, from, PER_PALETTE);
	}

	public static inline function palette(which:UInt16, into:Vector<UInt16>):Void {
		colours(which * PER_PALETTE, into, PER_PALETTE);
	}
}

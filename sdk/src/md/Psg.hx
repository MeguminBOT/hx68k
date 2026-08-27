package md;

import md.hw.Psg as Ports;

class Psg {
	public static inline final CHANNELS = 4;

	public static inline final NOISE = 3;

	public static inline final SILENT = 0x0F;

	public static inline final LOUDEST = 0x00;

	#if md_pal
	public static inline final CLOCK = 3546893;
	#else
	public static inline final CLOCK = 3579545;
	#end

	public static function reset():Void {
		var channel = 0;

		while (channel < CHANNELS) {
			Ports.write(0x80 | (channel << 5));
			Ports.write(0x00);
			Ports.write(0x90 | (channel << 5) | SILENT);
			channel++;
		}
	}

	public static inline function setAttenuation(channel:UInt8, level:UInt8):Void {
		Ports.write(0x90 | ((channel & 3) << 5) | (level & 0x0F));
	}

	public static inline function silence(channel:UInt8):Void {
		setAttenuation(channel, SILENT);
	}

	public static inline function setTone(channel:UInt8, value:UInt16):Void {
		final divider:Int = value;

		Ports.write(0x80 | ((channel & 3) << 5) | (divider & 0x0F));
		Ports.write((divider >> 4) & 0x3F);
	}

	public static function setFrequency(channel:UInt8, hertz:UInt16):Void {
		final wanted:Int = hertz;
		setTone(channel, wanted == 0 ? 0 : Std.int(CLOCK / (wanted * 32)));
	}

	public static inline function setNoise(white:Bool, rate:UInt8):Void {
		Ports.write(0xE0 | (white ? 4 : 0) | (rate & 3));
	}
}

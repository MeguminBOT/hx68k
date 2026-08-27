package md;

import md.hw.Ym2612 as Ports;

class Fm {
	public static inline final CHANNELS = 6;

	public static inline final SLOTS = 4;

	public static inline final QUIETEST = 0x7F;

	static inline function part(channel:UInt8):Int {
		return channel < 3 ? 0 : 1;
	}

	static inline function within(channel:UInt8):Int {
		final n:Int = channel;
		return n < 3 ? n : n - 3;
	}

	static inline function voice(channel:UInt8):Int {
		final n:Int = channel;
		return n < 3 ? n : (n - 3) | 4;
	}

	static inline function ordered(slot:UInt8):Int {
		final n:Int = slot;
		return ((n & 1) << 1) | ((n >> 1) & 1);
	}

	static inline function slotAt(base:Int, channel:UInt8, slot:UInt8):Int {
		return base + (ordered(slot) << 2) + within(channel);
	}

	public static inline function setRegister(bank:UInt8, register:UInt8, value:UInt8):Void {
		Ports.write(bank, register, value);
	}

	public static function reset():Void {
		var channel = 0;

		while (channel < CHANNELS) {
			var slot = 0;
			while (slot < SLOTS) {
				setTotalLevel(channel, slot, QUIETEST);
				setRelease(channel, slot, 0, 0x0F);
				slot++;
			}

			keyOff(channel);
			setPanning(channel, true, true);
			channel++;
		}

		Ports.write(0, 0x2B, 0x00);
		Ports.write(0, 0x22, 0x00);
	}

	public static inline function keyOn(channel:UInt8, operators:UInt8):Void {
		Ports.write(0, 0x28, ((operators & 0x0F) << 4) | voice(channel));
	}

	public static inline function keyOff(channel:UInt8):Void {
		Ports.write(0, 0x28, voice(channel));
	}

	public static function setFrequency(channel:UInt8, block:UInt8, note:UInt16):Void {
		final bank:Int = part(channel);
		final where:Int = within(channel);
		final value:Int = note;

		Ports.write(bank, 0xA4 + where, ((block & 7) << 3) | ((value >> 8) & 7));
		Ports.write(bank, 0xA0 + where, value & 0xFF);
	}

	public static inline function setAlgorithm(channel:UInt8, algorithm:UInt8,
			feedback:UInt8):Void {
		Ports.write(part(channel), 0xB0 + within(channel), ((feedback & 7) << 3) | (algorithm & 7));
	}

	public static inline function setPanning(channel:UInt8, left:Bool, right:Bool):Void {
		Ports.write(part(channel), 0xB4 + within(channel),
			(left ? 0x80 : 0) | (right ? 0x40 : 0));
	}

	public static inline function setMultiple(channel:UInt8, slot:UInt8, detune:UInt8,
			multiple:UInt8):Void {
		Ports.write(part(channel), slotAt(0x30, channel, slot),
			((detune & 7) << 4) | (multiple & 0x0F));
	}

	public static inline function setTotalLevel(channel:UInt8, slot:UInt8, level:UInt8):Void {
		Ports.write(part(channel), slotAt(0x40, channel, slot), level & 0x7F);
	}

	public static inline function setAttack(channel:UInt8, slot:UInt8, scale:UInt8,
			rate:UInt8):Void {
		Ports.write(part(channel), slotAt(0x50, channel, slot),
			((scale & 3) << 6) | (rate & 0x1F));
	}

	public static inline function setDecay(channel:UInt8, slot:UInt8, modulated:Bool,
			rate:UInt8):Void {
		Ports.write(part(channel), slotAt(0x60, channel, slot),
			(modulated ? 0x80 : 0) | (rate & 0x1F));
	}

	public static inline function setSustain(channel:UInt8, slot:UInt8, rate:UInt8):Void {
		Ports.write(part(channel), slotAt(0x70, channel, slot), rate & 0x1F);
	}

	public static inline function setRelease(channel:UInt8, slot:UInt8, level:UInt8,
			rate:UInt8):Void {
		Ports.write(part(channel), slotAt(0x80, channel, slot),
			((level & 0x0F) << 4) | (rate & 0x0F));
	}

	public static inline function enableDac(on:Bool):Void {
		Ports.write(0, 0x2B, on ? 0x80 : 0x00);
	}

	public static inline function setDacSample(value:UInt8):Void {
		Ports.write(0, 0x2A, value);
	}
}

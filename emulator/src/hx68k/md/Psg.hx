package hx68k.md;

import haxe.ds.Vector;

@:allow(hx68k.md.Savestate)
final class Psg {
	public static inline final CLOCK = 3579545;

	public static inline final DIVIDER = 16;

	static inline final WHITE = 0x0009;
	static inline final PERIODIC = 0x0001;

	public final tone:Vector<Int> = new Vector<Int>(4);
	public final attenuation:Vector<Int> = new Vector<Int>(4);

	static inline final LOUDEST = 255;

	final volumes:Vector<Int> = new Vector<Int>(16);

	final counter:Vector<Int> = new Vector<Int>(4);
	final output:Vector<Int> = new Vector<Int>(4);

	public var writes(default, null):Int = 0;

	var latched:Int = 0;
	public var noise(default, null):Int = 0;
	public var shift(default, null):Int = 0x8000;
	var spare:Int = 0;
	var total:Int = 0;
	var counted:Int = 0;

	public function new() {
		for (i in 0...16) {
			volumes[i] = i == 15 ? 0 : Math.round(LOUDEST * Math.pow(10, -0.1 * i));
		}

		reset();
	}

	public function reset():Void {
		for (i in 0...4) {
			tone[i] = 0;
			attenuation[i] = 15;
			counter[i] = 0;
			output[i] = 1;
		}

		latched = 0;
		noise = 0;
		shift = 0x8000;
		spare = 0;
		total = 0;
		counted = 0;
		writes = 0;
	}

	public function write(value:Int):Void {
		final byte = value & 0xFF;
		writes++;

		if ((byte & 0x80) != 0) {
			latched = (byte >> 4) & 0x07;
			final channel = latched >> 1;

			if ((latched & 1) != 0) attenuation[channel] = byte & 0x0F;
			else if (channel == 3) setNoise(byte & 0x0F);
			else tone[channel] = (tone[channel] & 0x3F0) | (byte & 0x0F);

			return;
		}

		final channel = latched >> 1;
		if ((latched & 1) != 0) attenuation[channel] = byte & 0x0F;
		else if (channel == 3) setNoise(byte & 0x0F);
		else tone[channel] = (tone[channel] & 0x000F) | ((byte & 0x3F) << 4);
	}

	function setNoise(value:Int):Void {
		noise = value & 0x07;
		shift = 0x8000;
	}

	public function run(clocks:Int):Void {
		spare += clocks;

		while (spare >= DIVIDER) {
			spare -= DIVIDER;
			step();
		}
	}

	function step():Void {
		for (channel in 0...3) {
			if (--counter[channel] > 0) continue;

			counter[channel] = tone[channel] < 1 ? 1 : tone[channel];
			if (tone[channel] >= 1) output[channel] = output[channel] > 0 ? 0 : 1;
			else output[channel] = 1;
		}

		if (--counter[3] > 0) {
			gather();
			return;
		}

		counter[3] = switch (noise & 0x03) {
			case 0: 0x10;
			case 1: 0x20;
			case 2: 0x40;
			case _: tone[2] < 1 ? 1 : tone[2];
		}

		final feedback = (noise & 0x04) != 0 ? WHITE : PERIODIC;
		final parity = countBits(shift & feedback) & 1;
		shift = ((shift >> 1) | (parity << 15)) & 0xFFFF;
		output[3] = shift & 1;
		gather();
	}

	inline function gather():Void {
		total += level();
		counted++;
	}

	public function taken():Int {
		if (counted == 0) return level();

		final answer = Std.int(total / counted);
		total = 0;
		counted = 0;
		return answer;
	}

	public function level():Int {
		var sum = 0;
		for (channel in 0...4) if (output[channel] > 0) sum += volumes[attenuation[channel]];
		return sum;
	}

	static inline function countBits(value:Int):Int {
		var left = value;
		var count = 0;
		while (left != 0) {
			count += left & 1;
			left >>= 1;
		}
		return count;
	}
}

package hx68k.md;

import haxe.ds.Vector;

class Psg {
	public static inline final CLOCK = 3579545;

	static inline final DIVIDER = 16;

	static inline final WHITE = 0x0009;
	static inline final PERIODIC = 0x0001;

	public final tone:Vector<Int> = new Vector<Int>(4);
	public final attenuation:Vector<Int> = new Vector<Int>(4);

	final volumes:Vector<Int> = new Vector<Int>(16);

	final counter:Vector<Int> = new Vector<Int>(4);
	final output:Vector<Int> = new Vector<Int>(4);

	public var writes(default, null):Int = 0;

	var latched:Int = 0;
	var noise:Int = 0;
	var shift:Int = 0x8000;
	var spare:Float = 0;

	public function new() {
		for (i in 0...16) {
			volumes[i] = i == 15 ? 0 : Std.int(8191 * Math.pow(10, -0.1 * i));
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
		for (_ in 0...clocks) tick();
	}

	function tick():Void {
		spare += 1;
		if (spare < DIVIDER) return;
		spare -= DIVIDER;

		for (channel in 0...3) {
			if (--counter[channel] > 0) continue;

			counter[channel] = tone[channel] < 2 ? 1 : tone[channel];
			if (tone[channel] >= 2) output[channel] = output[channel] > 0 ? 0 : 1;
			else output[channel] = 1;
		}

		if (--counter[3] > 0) return;

		counter[3] = switch (noise & 0x03) {
			case 0: 0x10;
			case 1: 0x20;
			case 2: 0x40;
			case _: tone[2] < 2 ? 1 : tone[2];
		}

		final feedback = (noise & 0x04) != 0 ? WHITE : PERIODIC;
		final parity = countBits(shift & feedback) & 1;
		shift = ((shift >> 1) | (parity << 15)) & 0xFFFF;
		output[3] = shift & 1;
	}

	public function sample():Int {
		var total = 0;
		for (channel in 0...4) if (output[channel] > 0) total += volumes[attenuation[channel]];
		return total;
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

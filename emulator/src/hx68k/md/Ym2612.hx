package hx68k.md;

import haxe.ds.Vector;

class Ym2612 {
	public static inline final CLOCK = 7670453;
	public static inline final PER_SAMPLE = 144;

	static inline final SILENCE = 0x3FF;

	static final MULTIPLE = [1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30];

	static final DETUNE = [
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 8, 8],
		[1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14, 16, 16, 16, 16],
		[2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 20, 22, 22, 22, 22]
	];

	static final KEY_CODE = [0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3, 3, 3, 3, 3, 3];

	public final registers:Vector<Int> = new Vector<Int>(512);
	public final channels:Vector<Channel> = new Vector<Channel>(6);

	public var writes(default, null):Int = 0;

	public var dac(default, null):Int = 0;
	public var dacOn(default, null):Bool = false;

	final sine:Vector<Int> = new Vector<Int>(256);
	final exponential:Vector<Int> = new Vector<Int>(256);

	var address:Int = 0;
	var part:Int = 0;

	var timerA:Int = 0;
	var timerB:Int = 0;
	var timerACount:Int = 0;
	var timerBCount:Int = 0;
	var timerASubdivide:Int = 0;
	var status:Int = 0;

	var envelopeClock:Int = 0;
	var lfoClock:Int = 0;
	var lfoPhase:Int = 0;

	public function new() {
		for (i in 0...256) {
			final value = Math.sin((i + 0.5) * Math.PI / 512);
			sine[i] = Std.int(Math.round(-Math.log(value) / Math.log(2) * 256));
		}

		for (i in 0...256) {
			exponential[i] = Std.int(Math.round((Math.pow(2, i / 256.0) - 1) * 1024));
		}

		for (i in 0...6) channels[i] = new Channel();
		reset();
	}

	public function reset():Void {
		for (i in 0...registers.length) registers[i] = 0;
		for (channel in channels) channel.reset();

		address = 0;
		part = 0;
		timerA = 0;
		timerB = 0;
		timerACount = 0;
		timerBCount = 0;
		timerASubdivide = 0;
		status = 0;
		writes = 0;
		dac = 0;
		dacOn = false;
		envelopeClock = 0;
		lfoClock = 0;
		lfoPhase = 0;
	}

	public function write(port:Int, value:Int):Void {
		writes++;

		final byte = value & 0xFF;
		if ((port & 1) == 0) {
			part = (port >> 1) & 1;
			address = byte;
			return;
		}

		registers[(part << 8) | address] = byte;
		apply(part, address, byte);
	}

	public function read():Int {
		return status;
	}

	function apply(half:Int, at:Int, value:Int):Void {
		if (half == 0) {
			switch (at) {
				case 0x24: timerA = (timerA & 0x03) | (value << 2);
				case 0x25: timerA = (timerA & 0x3FC) | (value & 0x03);
				case 0x26: timerB = value;
				case 0x27: timers(value);
				case 0x28: key(value);
				case 0x2A: dac = value;
				case 0x2B: dacOn = (value & 0x80) != 0;
				case _:
			}
			if (at < 0x30) return;
		}

		final index = at & 0x03;
		if (index == 3) return;

		final channel = channels[half * 3 + index];

		if (at >= 0x30 && at < 0xA0) {
			final which = operatorOf(at);
			channel.operators[which].set(at & 0xF0, value);
			return;
		}

		switch (at & 0xFC) {
			case 0xA0: channel.setFrequency(channel.block, (channel.frequency & 0x700) | value);
			case 0xA4: channel.setFrequency((value >> 3) & 7, ((value & 7) << 8) | (channel.frequency & 0xFF));
			case 0xB0:
				channel.algorithm = value & 7;
				channel.feedback = (value >> 3) & 7;
			case 0xB4:
				channel.left = (value & 0x80) != 0;
				channel.right = (value & 0x40) != 0;
			case _:
		}
	}

	static inline function operatorOf(at:Int):Int {
		return switch ((at >> 2) & 3) {
			case 0: 0;
			case 1: 2;
			case 2: 1;
			case _: 3;
		}
	}

	function timers(value:Int):Void {
		if ((value & 0x10) != 0) status &= ~0x01;
		if ((value & 0x20) != 0) status &= ~0x02;

		if ((value & 0x01) != 0 && timerACount == 0) timerACount = 1024 - timerA;
		if ((value & 0x02) != 0 && timerBCount == 0) timerBCount = (256 - timerB) * 16;
	}

	function key(value:Int):Void {
		final which = value & 0x07;
		final index = (which & 3) + ((which & 4) != 0 ? 3 : 0);
		if ((which & 3) == 3) return;

		final channel = channels[index];
		for (slot in 0...4) {
			if ((value & (0x10 << slot)) != 0) channel.operators[slot].keyOn();
			else channel.operators[slot].keyOff();
		}
	}

	public function run(clocks:Int):Void {
		countTimers(clocks);
	}

	function countTimers(clocks:Int):Void {
		timerASubdivide += clocks;
		final steps = Std.int(timerASubdivide / PER_SAMPLE);
		if (steps == 0) return;
		timerASubdivide -= steps * PER_SAMPLE;

		if (timerACount > 0) {
			timerACount -= steps;
			if (timerACount <= 0) {
				if ((registers[0x27] & 0x04) != 0) status |= 0x01;
				timerACount += 1024 - timerA;
			}
		}

		if (timerBCount > 0) {
			timerBCount -= steps;
			if (timerBCount <= 0) {
				if ((registers[0x27] & 0x08) != 0) status |= 0x02;
				timerBCount += (256 - timerB) * 16;
			}
		}
	}

	public function sample():Int {
		envelopeClock++;
		final envelopeStep = (envelopeClock & 2) == 0;

		lfoClock++;
		if ((registers[0x22] & 0x08) != 0 && (lfoClock & 0x3F) == 0) lfoPhase = (lfoPhase + 1) & 0x7F;

		var total = 0;

		for (i in 0...6) {
			final channel = channels[i];

			if (i == 5 && dacOn) {
				total += (dac - 0x80) << 6;
				continue;
			}

			total += channel.sample(sine, exponential, envelopeStep);
		}

		return total;
	}
}

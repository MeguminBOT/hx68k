package hx68k.md;

import haxe.ds.Vector;

class Ym2612 {
	public static inline final CLOCK = 7670453;
	public static inline final PER_SAMPLE = 144;

	static inline final PER_FRAME = 24;

	static inline final CSM = 2;

	static inline final BUSY = 32;

	static inline final WRITE_LATENCY = 2;

	static final TURN = [0, 2, 1, 3];

	static final APART = [2, 0, 1];

	static final SPEAKS = [
		0, 1, 2, 3, 4, 5, 0, 1, 2, 3, 4, 5,
		0, 1, 2, 3, 4, 5, 0, 1, 2, 3, 4, 5
	];

	static final TURNS = [
		0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
		2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3
	];

	static final PLAYS = [
		0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2,
		1, 1, 1, 1, 1, 1, 3, 3, 3, 3, 3, 3
	];

	static final SWEEP = [108, 77, 71, 67, 62, 44, 8, 5];

	static final TREMOLO = [7, 3, 1, 0];

	static final TAKEN = [
		1, -1, -1, -1, 5, -1, -1, -1, 3, -1, -1, -1,
		0, -1, -1, -1, 4, -1, -1, -1, 2, -1, -1, -1
	];

	public final registers:Vector<Int> = new Vector<Int>(512);
	public final channels:Vector<Channel> = new Vector<Channel>(6);

	public var writes(default, null):Int = 0;

	public var left(default, null):Int = 0;
	public var right(default, null):Int = 0;

	public var dac(default, null):Int = 0;
	public var dacOn(default, null):Bool = false;

	public var discrete:Bool = true;

	final sine:Vector<Int> = new Vector<Int>(256);
	final exponential:Vector<Int> = new Vector<Int>(256);

	var address:Int = 0;
	var part:Int = 0;

	var timerA:Int = 0;
	var timerB:Int = 0;
	var timerACount:Int = 0;
	var timerBCount:Int = 0;
	var status:Int = 0;

	var envelopeCounter:Int = 0;
	var envelopeDivider:Int = 0;
	var visible:Int = 0;
	var ticking:Bool = false;
	var position:Int = 0;
	var pendingHalf:Int = 0;
	var pendingAddress:Int = 0;
	var pendingValue:Int = 0;
	var pendingIn:Int = 0;
	var waiting:Bool = false;
	public var lfoPhase(default, null):Int = 0;
	public var swell(default, null):Int = 126;

	var lfoOn:Bool = false;
	var lfoRate:Int = 0;
	var lfoHeld:Int = 0;
	var vibrato:Int = 0;
	var mode:Int = 0;
	var csmKeyed:Bool = false;
	var busyFor:Int = 0;

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
		status = 0;
		writes = 0;
		left = 0;
		right = 0;
		dac = 0;
		dacOn = false;
		envelopeCounter = 0;
		envelopeDivider = 0;
		visible = 0;
		ticking = false;
		position = 0;
		pendingHalf = 0;
		pendingAddress = 0;
		pendingValue = 0;
		pendingIn = 0;
		waiting = false;
		lfoOn = false;
		lfoRate = 0;
		lfoPhase = 0;
		lfoHeld = 0;
		vibrato = 0;
		mode = 0;
		csmKeyed = false;
		busyFor = 0;
		swell = 126;
	}

	public function write(port:Int, value:Int):Void {
		writes++;

		final byte = value & 0xFF;
		if ((port & 1) == 0) {
			part = (port >> 1) & 1;
			address = byte;
			return;
		}

		busyFor = BUSY;

		if (pendingIn > 0 || waiting) commit();

		pendingHalf = part;
		pendingAddress = address;
		pendingValue = byte;
		pendingIn = WRITE_LATENCY;
		waiting = false;
	}

	function commit():Void {
		pendingIn = 0;
		waiting = false;
		registers[(pendingHalf << 8) | pendingAddress] = pendingValue;
		apply(pendingHalf, pendingAddress, pendingValue);
	}

	inline function lands(at:Int):Bool {
		final address = pendingAddress;
		if (address < 0x30) return true;

		final channel = pendingHalf * 3 + (address & 3);
		if ((address & 3) == 3) return true;

		return address < 0xA0
			? at % 12 == ((address >> 2) & 1) * 6 + channel
			: at % 6 == channel;
	}

	public function read():Int {
		return status | (busyFor > 0 ? 0x80 : 0);
	}

	function apply(half:Int, at:Int, value:Int):Void {
		if (half == 0) {
			switch (at) {
				case 0x22:
					lfoOn = (value & 0x08) != 0;
					lfoRate = value & 7;
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

		if (half == 0 && at >= 0xA8 && at <= 0xAE && (at & 3) != 3) {
			final which = APART[at & 3];
			final third = channels[2];
			if (at < 0xAC) third.setSeparate(which, third.blocks[which], (third.notes[which] & 0x700) | value);
			else third.setSeparate(which, (value >> 3) & 7, ((value & 7) << 8) | (third.notes[which] & 0xFF));
			return;
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
				channel.tremoloDepth = TREMOLO[(value >> 4) & 3];
				channel.vibratoDepth = value & 7;
				channel.tune(vibrato);
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
		mode = (value >> 6) & 3;

		final apart = mode != 0;
		if (apart != channels[2].separate) {
			channels[2].separate = apart;
			channels[2].tune(vibrato);
		}

		channels[2].levelled = mode != CSM;

		if ((value & 0x10) != 0) status &= ~0x01;
		if ((value & 0x20) != 0) status &= ~0x02;

		if ((value & 0x01) != 0 && timerACount == 0) timerACount = 1024 - timerA;
		if ((value & 0x02) != 0 && timerBCount == 0) timerBCount = (256 - timerB) * 16;
	}

	function key(value:Int):Void {
		final which = value & 0x07;
		if ((which & 3) == 3) return;

		channels[(which & 3) + ((which & 4) != 0 ? 3 : 0)].armed = (value >> 4) & 0x0F;
	}

	function countTimers():Void {
		csmKeyed = false;

		if (timerACount > 0) {
			if (--timerACount <= 0) {
				if ((registers[0x27] & 0x04) != 0) status |= 0x01;
				timerACount += 1024 - timerA;
				csmKeyed = mode == CSM;
			}
		}

		if (timerBCount > 0) {
			if (--timerBCount <= 0) {
				if ((registers[0x27] & 0x08) != 0) status |= 0x02;
				timerBCount += (256 - timerB) * 16;
			}
		}
	}

	function cycle():Void {
		if (busyFor > 0) busyFor--;
		if (pendingIn > 0 && --pendingIn == 0) waiting = true;
		if (waiting && lands(position)) commit();

		final which = SPEAKS[position];
		channels[which].slot(TURNS[position], PLAYS[position], sine, exponential, visible, ticking,
			swell, csmKeyed && which == 2);

		final taken = TAKEN[position];
		if (taken >= 0) channels[taken].capture();

		if (position < 6) channels[which].keyRequest = channels[which].armed;

		if (++position < PER_FRAME) return;

		position = 0;

		ticking = visible != envelopeCounter;
		visible = envelopeCounter;

		if (++envelopeDivider >= 3) {
			envelopeDivider = 0;
			envelopeCounter = (envelopeCounter + 1) & 0xFFF;
		}
	}

	function oscillate():Void {
		final ramp = (lfoPhase << 1) & 0x7E;
		swell = (lfoPhase & 0x40) != 0 ? ramp : ramp ^ 0x7E;

		final step = lfoPhase >> 2;
		if (step != vibrato) {
			vibrato = step;
			for (channel in channels) channel.tune(step);
		}

		final mask = SWEEP[lfoRate];
		if ((lfoHeld & mask) == mask) {
			lfoHeld = 0;
			if (lfoOn) lfoPhase = (lfoPhase + 1) & 0x7F;
		}

		lfoHeld++;
		if (!lfoOn) lfoPhase = 0;
	}

	public function sample():Int {
		oscillate();
		countTimers();
		for (_ in 0...PER_FRAME) cycle();

		left = 0;
		right = 0;

		for (i in 0...6) {
			final channel = channels[i];

			final value = i == 5 && dacOn ? (dac - 0x80) << 1 : channel.delivered;

			if (!discrete) {
				if (channel.left) left += value;
				if (channel.right) right += value;
				continue;
			}

			final step = value >= 0 ? 1 : -1;
			final driven = (value >= 0 ? value + 1 : value) + 3 * step;

			left += channel.left ? driven : 4 * step;
			right += channel.right ? driven : 4 * step;
		}

		return left + right;
	}
}

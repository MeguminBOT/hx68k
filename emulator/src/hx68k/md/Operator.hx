package hx68k.md;

import haxe.ds.Vector;

enum abstract Phase(Int) from Int to Int {
	var Attack = 0;
	var Decay = 1;
	var Sustain = 2;
	var Release = 3;
}

class Operator {
	public var detune:Int = 0;
	public var multiple:Int = 0;
	public var totalLevel:Int = 0;
	public var keyScale:Int = 0;
	public var attackRate:Int = 0;
	public var decayRate:Int = 0;
	public var sustainRate:Int = 0;
	public var releaseRate:Int = 0;

	public var sustainLevel:Int = 0;

	public var tremolo:Bool = false;

	public var phase:Int = 0;
	public var increment:Int = 0;
	public var envelope:Int = 1023;
	public var state:Phase = Release;

	public var keyed:Bool = false;

	public var ssg:Int = 0;

	public var restarts(default, null):Bool = false;

	public var repeats(default, null):Bool = false;

	var rising:Bool = false;
	var inverted:Bool = false;
	var holding:Bool = false;

	public function new() {}

	public function reset():Void {
		detune = 0;
		multiple = 0;
		totalLevel = 0;
		keyScale = 0;
		attackRate = 0;
		decayRate = 0;
		sustainRate = 0;
		releaseRate = 0;
		sustainLevel = 0;
		tremolo = false;
		phase = 0;
		increment = 0;
		envelope = 1023;
		state = Release;
		keyed = false;
		ssg = 0;
		restarts = false;
		repeats = false;
		rising = false;
		inverted = false;
		holding = false;
	}

	public function set(group:Int, value:Int):Void {
		switch (group) {
			case 0x30:
				detune = (value >> 4) & 7;
				multiple = value & 0x0F;
			case 0x40:
				totalLevel = value & 0x7F;
			case 0x50:
				keyScale = (value >> 6) & 3;
				attackRate = value & 0x1F;
			case 0x60:
				tremolo = (value & 0x80) != 0;
				decayRate = value & 0x1F;
			case 0x70:
				sustainRate = value & 0x1F;
			case 0x90:
				ssg = value & 0x0F;
			case 0x80:
				final level = (value >> 4) & 0x0F;
				sustainLevel = (level == 0x0F ? 31 : level) << 1;
				releaseRate = (value & 0x0F) * 2 + 1;
			case _:
		}
	}

	public function shape(wanted:Bool):Void {
		restarts = false;
		repeats = false;
		holding = false;

		var direction = false;

		if ((ssg & 0x08) != 0) {
			direction = rising;

			if ((envelope & 0x200) != 0) {
				if ((ssg & 0x03) == 0x00) restarts = true;
				if ((ssg & 0x01) == 0x00) repeats = true;
				if ((ssg & 0x03) == 0x02) direction = !direction;
				if ((ssg & 0x03) == 0x03) direction = true;
			}

			if (wanted && ((ssg & 0x07) == 0x05 || (ssg & 0x07) == 0x03)) holding = true;

			direction = direction && keyed;
		}

		rising = direction;
		inverted = (rising != ((ssg & 0x0C) == 0x0C)) && keyed;
	}

	public inline function lift():Void {
		envelope = shown();
	}

	public inline function shown():Int {
		return inverted ? (512 - envelope) & 0x3FF : envelope;
	}

	public function advance(keyCode:Int, counter:Int, tick:Bool, held:Bool, started:Bool):Void {
		final shaped = (ssg & 0x08) != 0;

		final rate = rateOf(keyCode >> (3 - keyScale), started ? Attack : state);
		final fastest = rate >= 62;

		var size = 0;
		if (tick && rate != 0) {
			if (rate < 48) {
				final shift = 11 - (rate >> 2);
				if ((counter & ((1 << shift) - 1)) == 0) size = STEP[rate & 3][(counter >> shift) & 7];
			} else {
				final grow = FASTER[rate & 3][counter & 3] + (rate >> 2) - 12;
				size = 1 << (grow > 3 ? 3 : grow);
			}
		}

		final spent = shaped ? (envelope & 0x200) != 0 : (envelope & 0x3F0) == 0x3F0;
		if (shaped && state != Attack) size <<= 2;

		if (started) {
			final again = state == Attack;
			state = Attack;

			if (fastest) envelope = 0;
			else if (again && envelope != 0 && size != 0 && held) {
				envelope = (envelope + (((~envelope) * size) >> 4)) & 0x3FF;
			}

			return;
		}

		var next = state;
		var step = 0;

		switch (state) {
			case Attack:
				if (envelope == 0) next = Decay;
				else if (size != 0 && !fastest && held) step = ((~envelope) * size) >> 4;

			case Decay:
				if ((envelope >> 4) == sustainLevel) next = Sustain;
				else if (!spent && size != 0) step = size;

			case Sustain, Release:
				if (!spent && size != 0) step = size;
		}

		if (!held) next = Release;

		if (state != Attack && spent && !holding) {
			next = Release;
			envelope = 1023;
			step = 0;
		}

		envelope = (envelope + step) & 0x3FF;
		state = next;
	}

	static final STEP = [
		[0, 1, 0, 1, 0, 1, 0, 1],
		[0, 1, 0, 1, 1, 1, 0, 1],
		[0, 1, 1, 1, 0, 1, 1, 1],
		[0, 1, 1, 1, 1, 1, 1, 1]
	];

	static final FASTER = [
		[0, 0, 0, 0],
		[1, 0, 0, 0],
		[1, 0, 1, 0],
		[1, 1, 1, 0]
	];

	function rateOf(scaling:Int, which:Phase):Int {
		final base = switch (which) {
			case Attack: attackRate;
			case Decay: decayRate;
			case Sustain: sustainRate;
			case Release: releaseRate;
		}

		if (base == 0) return 0;
		final rate = base * 2 + scaling;
		return rate > 63 ? 63 : rate;
	}

	public function output(sine:Vector<Int>, exponential:Vector<Int>, modulation:Int):Int {
		final at = ((phase >> 10) + modulation) & 0x3FF;
		final quarter = at & 0xFF;
		final mirrored = (at & 0x100) != 0 ? 255 - quarter : quarter;

		var level = shown() + (totalLevel << 3);
		if (level > 1023) level = 1023;

		var attenuation = sine[mirrored] + (level << 2);
		if (attenuation > 0x1FFF) attenuation = 0x1FFF;

		final value = ((exponential[(~attenuation) & 0xFF] + 1024) << 2) >> (attenuation >> 8);
		return (at & 0x200) != 0 ? -value : value;
	}

	public inline function step():Void {
		phase = (phase + increment) & 0xFFFFF;
	}
}

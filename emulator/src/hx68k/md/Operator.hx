package hx68k.md;

enum abstract Phase(Int) from Int to Int {
	var Off = 0;
	var Attack = 1;
	var Decay = 2;
	var Sustain = 3;
	var Release = 4;
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
	public var state:Phase = Off;

	var counter:Int = 0;

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
		state = Off;
		counter = 0;
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
			case 0x80:
				final level = (value >> 4) & 0x0F;
				sustainLevel = level == 0x0F ? 1023 : level * 32;
				releaseRate = (value & 0x0F) * 2 + 1;
			case _:
		}
	}

	public function keyOn():Void {
		if (state != Off && state != Release) return;
		state = Attack;
		phase = 0;
		counter = 0;
		if (attackRate >= 31) envelope = 0;
	}

	public function keyOff():Void {
		if (state != Off) state = Release;
	}

	public function advance(keyCode:Int, step:Bool):Void {
		if (!step || state == Off) return;

		final scaling = keyCode >> (3 - keyScale);
		final rate = rateOf(scaling);
		if (rate == 0) return;

		counter++;
		final every = 1 << (11 - (rate >> 2));
		if (every > 1 && (counter % every) != 0) return;

		final size = 1 + (rate & 3);

		switch (state) {
			case Attack:
				envelope -= ((envelope * size) >> 4) + 1;
				if (envelope <= 0) {
					envelope = 0;
					state = Decay;
				}
			case Decay:
				envelope += size;
				if (envelope >= sustainLevel) {
					envelope = sustainLevel;
					state = Sustain;
				}
			case Sustain, Release:
				envelope += size;
				if (envelope >= 1023) {
					envelope = 1023;
					if (state == Release) state = Off;
				}
			case _:
		}
	}

	function rateOf(scaling:Int):Int {
		final base = switch (state) {
			case Attack: attackRate;
			case Decay: decayRate;
			case Sustain: sustainRate;
			case Release: releaseRate;
			case _: 0;
		}

		if (base == 0) return 0;
		final rate = base * 2 + scaling;
		return rate > 63 ? 63 : rate;
	}

	public function output(sine:haxe.ds.Vector<Int>, exponential:haxe.ds.Vector<Int>,
			modulation:Int):Int {
		if (state == Off) return 0;

		final at = ((phase >> 10) + modulation) & 0x3FF;
		final quarter = at & 0xFF;
		final mirrored = (at & 0x100) != 0 ? 255 - quarter : quarter;

		var attenuation = sine[mirrored] + (envelope << 2) + (totalLevel << 3);
		if (attenuation > 0x1FFF) attenuation = 0x1FFF;

		final value = (exponential[(~attenuation) & 0xFF] + 1024) >> (attenuation >> 8);
		return (at & 0x200) != 0 ? -value : value;
	}

	public inline function step():Void {
		phase = (phase + increment) & 0xFFFFF;
	}
}

package hx68k.md;

import haxe.ds.Vector;

@:allow(hx68k.md.Savestate)
final class Channel {
	static final DETUNE:Vector<Int> = Vector.fromArrayCopy([16, 17, 19, 20, 22, 24, 27, 29]);

	static final KEY_CODE:Vector<Int> =
		Vector.fromArrayCopy([0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3, 3, 3, 3, 3, 3]);

	static final VIBRATO:Vector<Int> = Vector.fromArrayCopy([
		0x077, 0x077, 0x077, 0x077, 0x077, 0x077, 0x077, 0x077,
		0x077, 0x077, 0x077, 0x077, 0x074, 0x074, 0x074, 0x074,
		0x077, 0x077, 0x077, 0x074, 0x074, 0x074, 0x073, 0x073,
		0x077, 0x077, 0x074, 0x074, 0x073, 0x073, 0x221, 0x221,
		0x077, 0x077, 0x074, 0x073, 0x073, 0x073, 0x221, 0x072,
		0x077, 0x077, 0x073, 0x221, 0x072, 0x072, 0x220, 0x210,
		0x077, 0x077, 0x072, 0x121, 0x071, 0x071, 0x120, 0x110,
		0x077, 0x077, 0x071, 0x021, 0x070, 0x070, 0x020, 0x010
	]);

	public final operators:Vector<Operator> = new Vector<Operator>(4);

	public var algorithm:Int = 0;
	public var feedback:Int = 0;
	public var frequency:Int = 0;
	public var block:Int = 0;
	public var left:Bool = true;
	public var right:Bool = true;

	public var separate:Bool = false;

	public final notes:Vector<Int> = new Vector<Int>(3);
	public final blocks:Vector<Int> = new Vector<Int>(3);

	public var levelled:Bool = true;

	public var tremoloDepth:Int = 7;

	public var vibratoDepth:Int = 0;

	public var armed:Int = 0;

	public var keyRequest:Int = 0;

	public var published(default, null):Int = 0;

	public var delivered(default, null):Int = 0;

	public final outputs:Vector<Int> = new Vector<Int>(4);

	final codes:Vector<Int> = new Vector<Int>(4);

	var accumulated:Int = 0;
	var carried:Int = 0;
	var lateTwo:Int = 0;
	var earlierTwo:Int = 0;
	var previous:Int = 0;
	var older:Int = 0;
	var swept:Int = 0;

	public function new() {
		for (i in 0...4) operators[i] = new Operator();
		for (i in 0...4) outputs[i] = 0;
		for (i in 0...4) codes[i] = 0;
		for (i in 0...3) notes[i] = 0;
		for (i in 0...3) blocks[i] = 0;
	}

	public function reset():Void {
		for (each in operators) each.reset();
		for (i in 0...4) outputs[i] = 0;
		algorithm = 0;
		feedback = 0;
		frequency = 0;
		block = 0;
		left = true;
		right = true;
		separate = false;
		levelled = true;
		for (i in 0...3) notes[i] = 0;
		for (i in 0...3) blocks[i] = 0;
		tremoloDepth = 7;
		vibratoDepth = 0;
		swept = 0;
		armed = 0;
		keyRequest = 0;
		published = 0;
		delivered = 0;
		accumulated = 0;
		carried = 0;
		lateTwo = 0;
		earlierTwo = 0;
		previous = 0;
		older = 0;
		retune();
	}

	public function setFrequency(block:Int, frequency:Int):Void {
		this.block = block & 7;
		this.frequency = frequency & 0x7FF;
		retune();
	}

	public function setSeparate(index:Int, block:Int, frequency:Int):Void {
		blocks[index] = block & 7;
		notes[index] = frequency & 0x7FF;
		retune();
	}

	public function tune(step:Int):Void {
		swept = step;
		retune();
	}

	public inline function noteOf(index:Int):Int {
		return separate && index != 3 ? notes[index] : frequency;
	}

	public inline function blockOf(index:Int):Int {
		return separate && index != 3 ? blocks[index] : block;
	}

	public inline function keyCode(index:Int):Int {
		return codes[index];
	}

	function retune():Void {
		for (i in 0...4) {
			final each = operators[i];
			final note = noteOf(i);
			final at = blockOf(i);
			codes[i] = (at << 2) | KEY_CODE[(note >> 7) & 0x0F];

			final tuned = ((note << 1) + vibratoOf(note)) & 0xFFF;

			var step = (tuned << at) >> 2;
			final amount = detuneOf(each.detune & 3, codes[i]);
			step += (each.detune & 4) != 0 ? -amount : amount;
			step &= 0x1FFFF;

			each.increment = (each.multiple == 0 ? step >> 1 : step * each.multiple) & 0xFFFFF;
		}
	}

	inline function vibratoOf(note:Int):Int {
		if (vibratoDepth == 0) return 0;

		final at = (swept & 8) != 0 ? 7 - (swept & 7) : swept & 7;
		final shifts = VIBRATO[(vibratoDepth << 3) | at];
		final high = note >> 4;
		final size = ((high >> (shifts & 0x0F)) + (high >> ((shifts >> 4) & 0x0F))) >> (shifts >> 8);

		return (swept & 16) != 0 ? -size : size;
	}

	static function detuneOf(amount:Int, keyCode:Int):Int {
		if (amount == 0) return 0;

		final code = keyCode > 0x1C ? 0x1C : keyCode;
		final sum = (code >> 2) + 9 + (amount == 3 ? 3 : (amount & 2));
		return DETUNE[((sum & 1) << 2) | (code & 3)] >> (9 - (sum >> 1));
	}

	public function slot(turn:Int, index:Int, counter:Int, tick:Bool, swell:Int,
			pulsed:Bool):Void {
		if (turn == 1) {
			published = accumulated;
			accumulated = 0;
		}

		accumulated = accumulate(accumulated, carried);

		final each = operators[index];

		final wanted = pulsed || (keyRequest & (1 << index)) != 0;

		var out = 0;

		if (each.idle(wanted)) {
			each.step();
		} else {
			each.shape(wanted);

			final pressed = wanted && !each.keyed;
			final started = pressed || (each.keyed && each.repeats);
			final restarting = pressed || each.restarts;

			final attenuation = (levelled ? each.totalLevel << 3 : 0)
				+ (each.tremolo ? swell >> tremoloDepth : 0);

			out = each.output(modulation(index), attenuation);

			if (restarting) each.phase = 0;
			else each.step();

			if (each.keyed && !wanted) each.lift();
			each.advance(keyCode(index), counter, tick, wanted, started, pulsed);
			each.keyed = wanted;
		}

		outputs[index] = out;

		if (index == 0) {
			older = previous;
			previous = out;
		} else if (index == 1) {
			earlierTwo = lateTwo;
			lateTwo = out;
		}

		carried = carries(index) ? out : 0;
	}

	public inline function capture():Void {
		delivered = published;
	}

	static inline function accumulate(total:Int, value:Int):Int {
		final sum = total + (value >> 5);
		return sum > 255 ? 255 : (sum < -256 ? -256 : sum);
	}

	inline function modulation(index:Int):Int {
		return switch (index) {
			case 0:
				feedback == 0 ? 0 : (previous + older) >> (10 - feedback);
			case 2:
				switch (algorithm) {
					case 0, 2: lateTwo >> 1;
					case 1: (older + lateTwo) >> 1;
					case 5: older >> 1;
					case _: 0;
				}
			case 1:
				switch (algorithm) {
					case 0, 4, 5, 6: outputs[0] >> 1;
					case 3: outputs[0] >> 1;
					case _: 0;
				}
			case _:
				switch (algorithm) {
					case 0, 1, 4: outputs[2] >> 1;
					case 2: (outputs[0] + outputs[2]) >> 1;
					case 3: (earlierTwo + outputs[2]) >> 1;
					case 5: outputs[0] >> 1;
					case _: 0;
				}
		}
	}

	inline function carries(index:Int):Bool {
		return switch (index) {
			case 0: algorithm == 7;
			case 2: algorithm >= 5;
			case 1: algorithm >= 4;
			case _: true;
		}
	}

	public inline function onLeft():Int {
		return left ? delivered : 0;
	}

	public inline function onRight():Int {
		return right ? delivered : 0;
	}
}

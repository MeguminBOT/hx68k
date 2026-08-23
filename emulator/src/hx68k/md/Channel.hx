package hx68k.md;

import haxe.ds.Vector;

class Channel {
	static final DETUNE = [16, 17, 19, 20, 22, 24, 27, 29];

	static final KEY_CODE = [0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3, 3, 3, 3, 3, 3];

	public final operators:Vector<Operator> = new Vector<Operator>(4);

	public var algorithm:Int = 0;
	public var feedback:Int = 0;
	public var frequency:Int = 0;
	public var block:Int = 0;
	public var left:Bool = true;
	public var right:Bool = true;

	public var armed:Int = 0;

	public var keyRequest:Int = 0;

	public var published(default, null):Int = 0;

	public var delivered(default, null):Int = 0;

	public final outputs:Vector<Int> = new Vector<Int>(4);

	var accumulated:Int = 0;
	var carried:Int = 0;
	var lateTwo:Int = 0;
	var earlierTwo:Int = 0;
	var previous:Int = 0;
	var older:Int = 0;

	public function new() {
		for (i in 0...4) operators[i] = new Operator();
		for (i in 0...4) outputs[i] = 0;
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
	}

	public function setFrequency(block:Int, frequency:Int):Void {
		this.block = block & 7;
		this.frequency = frequency & 0x7FF;
		retune();
	}

	public inline function keyCode():Int {
		return (block << 2) | KEY_CODE[(frequency >> 7) & 0x0F];
	}

	function retune():Void {
		final code = keyCode();

		for (i in 0...4) {
			final each = operators[i];

			var step = (frequency << block) >> 1;
			final amount = detuneOf(each.detune & 3, code);
			step += (each.detune & 4) != 0 ? -amount : amount;
			step &= 0x1FFFF;

			each.increment = (each.multiple == 0 ? step >> 1 : step * each.multiple) & 0xFFFFF;
		}
	}

	static function detuneOf(amount:Int, keyCode:Int):Int {
		if (amount == 0) return 0;

		final code = keyCode > 0x1C ? 0x1C : keyCode;
		final sum = (code >> 2) + 9 + (amount == 3 ? 3 : (amount & 2));
		return DETUNE[((sum & 1) << 2) | (code & 3)] >> (9 - (sum >> 1));
	}

	public function slot(turn:Int, index:Int, sine:Vector<Int>, exponential:Vector<Int>,
			counter:Int, tick:Bool):Void {
		if (turn == 1) {
			published = accumulated;
			accumulated = 0;
		}

		accumulated = accumulate(accumulated, carried);

		final each = operators[index];

		final wanted = (keyRequest & (1 << index)) != 0;
		final lifted = (armed & (1 << index)) == 0;
		final started = wanted && !each.keyed;
		if (started) each.keyOn(keyCode());

		final out = each.output(sine, exponential, modulation(index));
		each.step();

		each.advance(keyCode(), counter, tick, !lifted, started);
		each.keyed = wanted;

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

package hx68k.md;

import haxe.ds.Vector;

class Channel {
	public final operators:Vector<Operator> = new Vector<Operator>(4);

	public var algorithm:Int = 0;
	public var feedback:Int = 0;
	public var frequency:Int = 0;
	public var block:Int = 0;
	public var left:Bool = true;
	public var right:Bool = true;

	var previous:Int = 0;
	var older:Int = 0;

	public function new() {
		for (i in 0...4) operators[i] = new Operator();
	}

	public function reset():Void {
		for (each in operators) each.reset();
		algorithm = 0;
		feedback = 0;
		frequency = 0;
		block = 0;
		left = true;
		right = true;
		previous = 0;
		older = 0;
	}

	public function setFrequency(block:Int, frequency:Int):Void {
		this.block = block & 7;
		this.frequency = frequency & 0x7FF;
		retune();
	}

	public function keyCode():Int {
		final top = (frequency >> 7) & 0x0F;
		final bit = top >= 8 ? 1 : 0;
		return (block << 2) | (bit << 1) | ((top >> 2) & 1);
	}

	function retune():Void {
		for (i in 0...4) {
			final each = operators[i];

			var step = (frequency << block) >> 1;
			step = each.multiple == 0 ? step >> 1 : step * each.multiple;

			final code = keyCode();
			final amount = detuneOf(each.detune & 3, code);
			step += (each.detune & 4) != 0 ? -amount : amount;

			each.increment = step & 0xFFFFF;
		}
	}

	static function detuneOf(which:Int, code:Int):Int {
		return switch (which) {
			case 0: 0;
			case 1: code >> 3;
			case 2: (code >> 3) * 2;
			case _: (code >> 3) * 3;
		}
	}

	public function sample(sine:Vector<Int>, exponential:Vector<Int>, step:Bool):Int {
		final code = keyCode();
		for (each in operators) each.advance(code, step);

		final fed = feedback == 0 ? 0 : ((previous + older) << feedback) >> 9;
		final one = operators[0].output(sine, exponential, fed);
		older = previous;
		previous = one;

		final out = switch (algorithm) {
			case 0:
				final two = operators[1].output(sine, exponential, one >> 1);
				final three = operators[2].output(sine, exponential, two >> 1);
				operators[3].output(sine, exponential, three >> 1);
			case 1:
				final two = operators[1].output(sine, exponential, 0);
				final three = operators[2].output(sine, exponential, (one + two) >> 1);
				operators[3].output(sine, exponential, three >> 1);
			case 2:
				final two = operators[1].output(sine, exponential, 0);
				final three = operators[2].output(sine, exponential, two >> 1);
				operators[3].output(sine, exponential, (one + three) >> 1);
			case 3:
				final two = operators[1].output(sine, exponential, one >> 1);
				final three = operators[2].output(sine, exponential, 0);
				operators[3].output(sine, exponential, (two + three) >> 1);
			case 4:
				final two = operators[1].output(sine, exponential, one >> 1);
				final three = operators[2].output(sine, exponential, 0);
				two + operators[3].output(sine, exponential, three >> 1);
			case 5:
				final carried = one >> 1;
				operators[1].output(sine, exponential, carried)
					+ operators[2].output(sine, exponential, carried)
					+ operators[3].output(sine, exponential, carried);
			case 6:
				final two = operators[1].output(sine, exponential, one >> 1);
				two + operators[2].output(sine, exponential, 0)
					+ operators[3].output(sine, exponential, 0);
			case _:
				one + operators[1].output(sine, exponential, 0)
					+ operators[2].output(sine, exponential, 0)
					+ operators[3].output(sine, exponential, 0);
		}

		for (each in operators) each.step();

		if (!left && !right) return 0;
		return out;
	}
}

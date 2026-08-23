package hx68k.test;

class OpnVoice {
	public var algorithm:Int = 7;
	public var feedback:Int = 0;

	public final detune:Array<Int> = [0, 0, 0, 0];
	public final multiple:Array<Int> = [1, 1, 1, 1];
	public final totalLevel:Array<Int> = [127, 127, 127, 127];
	public final keyScale:Array<Int> = [0, 0, 0, 0];
	public final attack:Array<Int> = [31, 31, 31, 31];
	public final decay:Array<Int> = [0, 0, 0, 0];
	public final sustain:Array<Int> = [0, 0, 0, 0];
	public final level:Array<Int> = [0, 0, 0, 0];
	public final release:Array<Int> = [15, 15, 15, 15];

	public final ssg:Array<Int> = [0, 0, 0, 0];

	public var block:Int = 3;
	public var frequency:Int = 0x180;
	public var panning:Int = 0xC0;

	public var keys:Int = 0x0F;

	public var lift:Int = -1;

	public function new() {}

	public function loud(at:Int):OpnVoice {
		for (i in 0...4) totalLevel[i] = at;
		return this;
	}

	public function alone(which:Int, at:Int):OpnVoice {
		for (i in 0...4) totalLevel[i] = i == which ? at : 127;
		return this;
	}

	public function envelope(attackRate:Int, decayRate:Int, sustainRate:Int, sustainLevel:Int,
			releaseRate:Int, scaling:Int = 0):OpnVoice {
		for (i in 0...4) {
			attack[i] = attackRate;
			decay[i] = decayRate;
			sustain[i] = sustainRate;
			level[i] = sustainLevel;
			release[i] = releaseRate;
			keyScale[i] = scaling;
		}
		return this;
	}

	public function note(atBlock:Int, atFrequency:Int):OpnVoice {
		block = atBlock;
		frequency = atFrequency;
		return this;
	}

	public function wiring(which:Int, back:Int):OpnVoice {
		algorithm = which;
		feedback = back;
		return this;
	}
}

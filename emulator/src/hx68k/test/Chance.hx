package hx68k.test;

class Chance {
	var state:Int;

	public function new(seed:Int) {
		state = seed == 0 ? 0x2545F491 : seed;
	}

	public function next():Int {
		state ^= state << 13;
		state ^= (state : Int) >>> 17;
		state ^= state << 5;
		return state & 0x3FFFFFFF;
	}

	public function upTo(limit:Int):Int {
		return next() % limit;
	}

	public function between(low:Int, high:Int):Int {
		return low + upTo(high - low);
	}

	public function pick(from:Array<Int>):Int {
		return from[upTo(from.length)];
	}

	public function odds(chance:Int):Bool {
		return upTo(100) < chance;
	}
}

package;

import md.Int16;

@:md.pool(64)
class Entity {
	public var value:Int16;
	public var rate:Int16;
	public var next:Entity;

	public function new(value:Int16, rate:Int16) {
		this.value = value;
		this.rate = rate;
		this.next = null;
	}

	public function step(seed:Int):Void {
		var next:Int16 = value + rate * seed;
		if (next > 4000) next = next - 4000;
		value = next;
	}
}

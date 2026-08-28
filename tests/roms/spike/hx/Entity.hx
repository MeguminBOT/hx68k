package;

@:md.pool(64)
class Entity {
	public var x:Int;
	public var step:Int;
	public var next:Entity;

	public function new(start:Int, stride:Int) {
		x = start;
		step = stride;
		next = null;
	}

	public function update():Void {
		x += step;
		if (x > 255) x -= 256;
	}
}

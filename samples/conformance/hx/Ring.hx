package;

@:md.pool(4)
class Ring extends Shape {
	public var spokes:Int;

	public function new(size:Int) {
		super(size);
		spokes = 3;
	}

	override public function area():Int {
		return spokes * size + super.area();
	}
}

package;

@:md.pool(2)
final class Tile extends Shape {
	public function new(size:Int) {
		super(size);
	}

	override public function area():Int {
		return size + 7;
	}
}

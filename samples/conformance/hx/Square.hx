package;

@:md.pool(4)
class Square extends Shape implements Sized {
	public function new(size:Int) {
		super(size);
	}

	override public function area():Int {
		return size * size;
	}

	public function span():Int {
		return size * 2;
	}
}

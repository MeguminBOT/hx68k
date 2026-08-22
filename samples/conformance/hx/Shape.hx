package;

class Shape {
	public var size:Int;

	public function new(size:Int) {
		this.size = size;
	}

	public function area():Int {
		return size;
	}

	public function tag():Int {
		return 1;
	}
}

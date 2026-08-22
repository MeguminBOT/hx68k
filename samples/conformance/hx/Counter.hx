package;

@:md.pool(2)
class Counter {
	public var value:Int;

	public function new(start:Int) {
		value = start;
	}

	public function add(n:Int):Void {
		value += n;
	}

	public function twice(n:Int):Void {
		add(n);
		add(n);
	}

	public function get():Int {
		return value;
	}
}

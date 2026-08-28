package;

@:md.pool(2)
class Gauge implements Sized {
	public var ticks:Int;

	public function new(ticks:Int) {
		this.ticks = ticks;
	}

	public function span():Int {
		return ticks + 1;
	}
}

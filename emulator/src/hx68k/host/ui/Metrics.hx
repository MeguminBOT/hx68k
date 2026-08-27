package hx68k.host.ui;

class Metrics {
	public final advance:Float;
	public final height:Float;

	public final margin:Float;
	public final bar:Float;
	public final reserved:Float;

	public final leastWide:Float;
	public final leastHigh:Float;

	public function new(advance:Float, height:Float, toolRows:Int = 1) {
		this.advance = advance;
		this.height = height;

		this.margin = Math.max(4, advance * 0.5);
		this.bar = height + Math.max(4, advance * 0.5);
		this.reserved = bar * toolRows + Math.max(3, advance * 0.375);

		this.leastWide = advance * 24;
		this.leastHigh = bar + height * 2;
	}

	public inline function rowsIn(high:Float):Int {
		final body = high - bar - margin;
		return body <= 0 ? 0 : Std.int(body / height);
	}
}

package hx68k.host;

enum abstract Dock(Int) from Int to Int {
	var Loose = 0;
	var Left = 1;
	var Right = 2;
	var Bottom = 3;
}

class Panel {
	public final id:String;

	public var title:String;
	public var x:Float;
	public var y:Float;
	public var width:Float;
	public var height:Float;
	public var docked:Dock = Loose;
	public var collapsed:Bool = false;
	public var open:Bool = true;
	public var order:Int = 0;

	public var scroll:Float = 0;
	public var content:Float = 0;

	public var widest:Float = 0;

	public function new(id:String, title:String, x:Float, y:Float, width:Float, height:Float) {
		this.id = id;
		this.title = title;
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	public function holds(pointerX:Float, pointerY:Float, bar:Float):Bool {
		final tall = collapsed ? bar : height;
		return pointerX >= x && pointerX < x + width && pointerY >= y && pointerY < y + tall;
	}

	public function onBar(pointerX:Float, pointerY:Float, bar:Float):Bool {
		return pointerX >= x && pointerX < x + width && pointerY >= y && pointerY < y + bar;
	}

	public function grip(pointerX:Float, pointerY:Float, reach:Float):{across:Int, down:Int} {
		if (collapsed || docked != Loose) return {across: 0, down: 0};

		final near = pointerX >= x - reach && pointerX < x + width + reach
			&& pointerY >= y - reach && pointerY < y + height + reach;
		if (!near) return {across: 0, down: 0};

		final across = pointerX >= x + width - reach ? 1 : (pointerX < x + reach ? -1 : 0);
		final down = pointerY >= y + height - reach ? 1 : 0;
		return {across: across, down: down};
	}
}

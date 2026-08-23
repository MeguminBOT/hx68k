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

	public function onGrip(pointerX:Float, pointerY:Float, grip:Float):Bool {
		if (collapsed || docked != Loose) return false;
		return pointerX >= x + width - grip && pointerX < x + width
			&& pointerY >= y + height - grip && pointerY < y + height;
	}
}

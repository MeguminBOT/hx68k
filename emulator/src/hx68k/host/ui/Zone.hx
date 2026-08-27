package hx68k.host.ui;

enum abstract Side(Int) from Int to Int {
	var None = 0;
	var Left = 1;
	var Right = 2;
	var Above = 3;
	var Below = 4;
	var Middle = 5;
}

class Zone {
	public var side:Side = None;
	public var onto:Null<String> = null;

	public var x:Float = 0;
	public var y:Float = 0;
	public var width:Float = 0;
	public var height:Float = 0;

	public function new() {}

	public function clear():Void {
		side = None;
		onto = null;
		x = 0;
		y = 0;
		width = 0;
		height = 0;
	}

	public function set(side:Side, onto:String, x:Float, y:Float, width:Float, height:Float):Void {
		this.side = side;
		this.onto = onto;
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	public function landing():Bool {
		return side != None && onto != null;
	}
}

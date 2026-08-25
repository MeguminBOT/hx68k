package hx68k.host;

interface Layout {
	public function name():String;

	public function freeform():Bool;

	public function adopt(groups:Array<Group>):Void;

	public function place(groups:Array<Group>, width:Float, height:Float, metrics:Metrics):Void;

	public function aim(groups:Array<Group>, moving:Group, pointerX:Float, pointerY:Float,
		width:Float, height:Float, metrics:Metrics, into:Zone):Void;

	public function settle(groups:Array<Group>, moving:Group, zone:Zone):Void;

	public function save():String;

	public function load(state:String, groups:Array<Group>):Void;
}

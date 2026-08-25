package hx68k.host;

class Group {
	public final id:String;

	public var x:Float = 0;
	public var y:Float = 0;
	public var width:Float = 0;
	public var height:Float = 0;

	public var order:Int = 0;

	public final members:Array<String> = [];

	public var active:Int = 0;

	public function new(id:String) {
		this.id = id;
	}

	public function add(panel:String):Void {
		if (members.indexOf(panel) >= 0) return;
		members.push(panel);
	}

	public function drop(panel:String):Bool {
		final at = members.indexOf(panel);
		if (at < 0) return false;

		members.splice(at, 1);
		if (active >= members.length) active = members.length - 1;
		if (active < 0) active = 0;
		return true;
	}

	public function holds(panel:String):Bool {
		return members.indexOf(panel) >= 0;
	}

	public function showing():Null<String> {
		return active >= 0 && active < members.length ? members[active] : null;
	}

	public function show(panel:String):Void {
		final at = members.indexOf(panel);
		if (at >= 0) active = at;
	}

	public function tabbed():Bool {
		return members.length > 1;
	}

	public function empty():Bool {
		return members.length == 0;
	}
}

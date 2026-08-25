package hx68k.host;

enum abstract Holder(Int) from Int to Int {
	var Application = 0;
	var Modal = 1;
	var Field = 2;
	var Capture = 3;
}

class Focus {
	public var depth(get, never):Int;

	final kinds:Array<Holder> = [];
	final names:Array<String> = [];

	public function new() {}

	function get_depth():Int {
		return kinds.length;
	}

	public function take(kind:Holder, name:String):Void {
		if (kind == Application) return;

		drop(name);
		kinds.push(kind);
		names.push(name);
	}

	public function top():Holder {
		return kinds.length == 0 ? Application : kinds[kinds.length - 1];
	}

	public function holding():String {
		return names.length == 0 ? "" : names[names.length - 1];
	}

	public function has(name:String):Bool {
		return names.indexOf(name) >= 0;
	}

	public function on(name:String):Bool {
		return names.length > 0 && names[names.length - 1] == name;
	}

	public function holds(kind:Holder):Bool {
		for (each in kinds) if (each == kind) return true;
		return false;
	}

	public function drop(name:String):Bool {
		final at = names.indexOf(name);
		if (at < 0) return false;

		kinds.splice(at, 1);
		names.splice(at, 1);
		return true;
	}

	public function escape():Holder {
		if (kinds.length == 0) return Application;

		names.pop();
		return kinds.pop();
	}

	public function typing():Bool {
		final kind = top();
		return kind == Field || kind == Capture;
	}

	public function capturing():Bool {
		return top() == Capture;
	}

	public function busy():Bool {
		return kinds.length > 0;
	}

	public function clear():Void {
		while (kinds.length > 0) {
			kinds.pop();
			names.pop();
		}
	}

	public static function named(kind:Holder):String {
		return switch (kind) {
			case Capture: "capture";
			case Field: "field";
			case Modal: "modal";
			case _: "application";
		}
	}
}

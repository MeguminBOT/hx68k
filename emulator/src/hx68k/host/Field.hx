package hx68k.host;

class Field {
	public var text(default, null):String = "";
	public var caret(default, null):Int = 0;
	public var mark(default, null):Int = 0;
	public var limit(default, null):Int;

	var kept:String = "";

	public function new(text:String = "", limit:Int = 0) {
		this.limit = limit;
		set(text);
	}

	public function set(given:String):Void {
		text = limit > 0 && given.length > limit ? given.substr(0, limit) : given;
		kept = text;
		caret = text.length;
		mark = caret;
	}

	public inline function from():Int {
		return caret < mark ? caret : mark;
	}

	public inline function to():Int {
		return caret < mark ? mark : caret;
	}

	public inline function selecting():Bool {
		return caret != mark;
	}

	public function selection():String {
		return selecting() ? text.substring(from(), to()) : "";
	}

	public function changed():Bool {
		return text != kept;
	}

	public function place(at:Int):Void {
		caret = bound(at);
		mark = caret;
	}

	public function drag(at:Int):Void {
		caret = bound(at);
	}

	public function all():Void {
		mark = 0;
		caret = text.length;
	}

	public function insert(what:String):Void {
		if (what == "") return;

		final start = from();
		final rest = text.substr(to());
		var head = text.substr(0, start) + what;

		if (limit > 0 && head.length + rest.length > limit) {
			final room = limit - start - rest.length;
			if (room <= 0) return;
			head = text.substr(0, start) + what.substr(0, room);
		}

		text = head + rest;
		caret = head.length;
		mark = caret;
	}

	public function backspace():Void {
		if (selecting()) {
			cut();
			return;
		}
		if (caret == 0) return;

		text = text.substr(0, caret - 1) + text.substr(caret);
		caret--;
		mark = caret;
	}

	public function erase():Void {
		if (selecting()) {
			cut();
			return;
		}
		if (caret >= text.length) return;

		text = text.substr(0, caret) + text.substr(caret + 1);
		mark = caret;
	}

	public function cut():String {
		if (!selecting()) return "";

		final taken = selection();
		final start = from();
		text = text.substr(0, start) + text.substr(to());
		caret = start;
		mark = start;
		return taken;
	}

	public function left(select:Bool, word:Bool):Void {
		if (!select && selecting()) {
			caret = from();
			mark = caret;
			if (!word) return;
		}

		caret = word ? wordLeft(caret) : bound(caret - 1);
		if (!select) mark = caret;
	}

	public function right(select:Bool, word:Bool):Void {
		if (!select && selecting()) {
			caret = to();
			mark = caret;
			if (!word) return;
		}

		caret = word ? wordRight(caret) : bound(caret + 1);
		if (!select) mark = caret;
	}

	public function home(select:Bool):Void {
		caret = 0;
		if (!select) mark = caret;
	}

	public function end(select:Bool):Void {
		caret = text.length;
		if (!select) mark = caret;
	}

	public function revert():Void {
		text = kept;
		caret = text.length;
		mark = caret;
	}

	public function commit():Void {
		kept = text;
	}

	inline function bound(at:Int):Int {
		return at < 0 ? 0 : (at > text.length ? text.length : at);
	}

	static inline function blank(code:Int):Bool {
		return code == " ".code || code == "\t".code;
	}

	function wordLeft(at:Int):Int {
		var walk = bound(at);
		while (walk > 0 && blank(text.charCodeAt(walk - 1))) walk--;
		while (walk > 0 && !blank(text.charCodeAt(walk - 1))) walk--;
		return walk;
	}

	function wordRight(at:Int):Int {
		var walk = bound(at);
		final last = text.length;
		while (walk < last && !blank(text.charCodeAt(walk))) walk++;
		while (walk < last && blank(text.charCodeAt(walk))) walk++;
		return walk;
	}
}

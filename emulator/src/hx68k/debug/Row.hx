package hx68k.debug;

enum abstract Kind(Int) from Int to Int {
	var Label = 0;

	var Value = 1;

	var Place = 2;

	var Aside = 3;

	var Here = 4;
}

typedef Part = {
	final text:String;
	final kind:Kind;
}

class Row {
	public final parts:Array<Part>;

	public final apart:Bool;

	public function new(parts:Array<Part>, apart:Bool = false) {
		this.parts = parts;
		this.apart = apart;
	}

	public static function of(...text:String):Row {
		final parts = new Array<Part>();
		for (one in text) parts.push({text: one, kind: Value});
		return new Row(parts);
	}

	public static function blank():Row {
		return new Row([], true);
	}

	public static function said(text:String, kind:Kind = Aside):Row {
		return new Row([{text: text, kind: kind}], true);
	}

	public function part(index:Int):Part {
		return index < parts.length ? parts[index] : {text: "", kind: Value};
	}

	public function toString():String {
		final out = new Array<String>();
		for (one in parts) if (one.text != "") out.push(one.text);
		return out.join("  ");
	}
}

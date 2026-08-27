package hx68k.debug;

enum abstract RowKind(Int) from Int to Int {
	var Label = 0;

	var Value = 1;

	var Place = 2;

	var Aside = 3;

	var Here = 4;
}

typedef RowPart = {
	final text:String;
	final kind:RowKind;
}

class Row {
	public final parts:Array<RowPart>;

	public final apart:Bool;

	public function new(parts:Array<RowPart>, apart:Bool = false) {
		this.parts = parts;
		this.apart = apart;
	}

	public static function of(...text:String):Row {
		final parts = new Array<RowPart>();
		for (one in text) parts.push({text: one, kind: Value});
		return new Row(parts);
	}

	public static function blank():Row {
		return new Row([], true);
	}

	public static function said(text:String, kind:RowKind = Aside):Row {
		return new Row([{text: text, kind: kind}], true);
	}

	public function part(index:Int):RowPart {
		return index < parts.length ? parts[index] : {text: "", kind: Value};
	}

	public function toString():String {
		final out = new Array<String>();
		for (one in parts) if (one.text != "") out.push(one.text);
		return out.join("  ");
	}
}

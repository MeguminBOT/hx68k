package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;

enum Item {
	Number(value:Int, width:Int);
	Reference(name:String);
}

class Assembly {
	public static function read(text:String):Map<String, Array<Item>> {
		final out = new Map<String, Array<Item>>();
		final order = new Array<String>();
		var current:Null<Array<Item>> = null;

		for (raw in text.split("\n")) {
			final line = StringTools.trim(StringTools.replace(raw, "\r", ""));
			if (line == "" || StringTools.startsWith(line, ";")) continue;
			if (line.indexOf("=") >= 0) continue;
			if (StringTools.startsWith(line, ".")) continue;

			if (StringTools.endsWith(line, ":")) {
				final name = line.substr(0, line.length - 1);
				current = [];
				out.set(name, current);
				order.push(name);
				continue;
			}

			final width = if (StringTools.startsWith(line, "dc.b")) 1
				else if (StringTools.startsWith(line, "dc.w")) 2
				else if (StringTools.startsWith(line, "dc.l")) 4
				else -1;
			if (width < 0 || current == null) continue;

			for (piece in line.substr(4).split(",")) {
				final value = StringTools.trim(piece);
				if (value == "") continue;
				final number = parse(value);
				current.push(number == null ? Reference(value) : Number(number, width));
			}
		}

		return out;
	}

	public static function bytes(items:Array<Item>):Bytes {
		var total = 0;
		for (item in items) total += switch (item) {
			case Number(_, width): width;
			case Reference(_): 4;
		}

		final out = Bytes.alloc(total);
		var at = 0;
		for (item in items) switch (item) {
			case Number(value, width):
				var shift = (width - 1) * 8;
				while (shift >= 0) {
					out.set(at++, (value >> shift) & 0xFF);
					shift -= 8;
				}
			case Reference(name):
				throw new haxe.Exception("The label " + name + " is an address, so it has no bytes here.");
		}

		return out;
	}

	public static function words(items:Array<Item>):Array<Int> {
		final data = bytes(items);
		final out = new Array<Int>();
		var at = 0;
		while (at + 1 < data.length) {
			out.push((data.get(at) << 8) | data.get(at + 1));
			at += 2;
		}
		return out;
	}

	static function parse(value:String):Null<Int> {
		if (StringTools.startsWith(value, "0x") || StringTools.startsWith(value, "0X"))
			return Std.parseInt(value);
		final first = value.charCodeAt(0);
		if (first == null) return null;
		if (first == "-".code || (first >= "0".code && first <= "9".code)) return Std.parseInt(value);
		return null;
	}
}
#end

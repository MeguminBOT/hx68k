package hx68k.map;

class Symbols {
	public var count(get, never):Int;

	final addresses:Array<Int> = [];
	final names:Array<String> = [];
	final byName:Map<String, Int> = [];

	public function new(path:String) {
		final rows:Array<{address:Int, name:String}> = [];

		for (line in sys.io.File.getContent(path).split("\n")) {
			final text = StringTools.trim(line);
			if (text == "") continue;

			final space = text.indexOf(" ");
			if (space <= 0) continue;

			final address = Std.parseInt("0x" + text.substr(0, space));
			if (address == null) continue;

			rows.push({address: address, name: StringTools.trim(text.substr(space + 1))});
		}

		rows.sort((a, b) -> a.address - b.address);

		for (row in rows) {
			addresses.push(row.address);
			names.push(row.name);
			if (!byName.exists(row.name)) byName.set(row.name, row.address);
		}
	}

	public function at(address:Int):Null<String> {
		if (addresses.length == 0 || address < addresses[0]) return null;

		var low = 0;
		var high = addresses.length - 1;

		while (low < high) {
			final middle = (low + high + 1) >> 1;
			if (addresses[middle] <= address) low = middle else high = middle - 1;
		}

		return names[low];
	}

	public function addressOf(name:String):Null<Int> {
		return byName.exists(name) ? byName.get(name) : null;
	}

	inline function get_count():Int {
		return addresses.length;
	}
}

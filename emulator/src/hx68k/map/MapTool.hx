package hx68k.map;

class MapTool {
	static function main():Void {
		final args = Sys.args();
		if (args.length < 2) {
			Sys.println("usage: map <rom.out> <generated-source-directory> [address|symbol ...]");
			Sys.exit(2);
		}

		final map = new SourceMap(new Elf(args[0]), args[1]);

		if (args.length == 2) {
			Sys.exit(check(map));
			return;
		}

		if (args[2] == "--statics") {
			Sys.exit(listStatics(map));
			return;
		}

		var missing = 0;
		for (i in 2...args.length) {
			final address = parse(map, args[i]);
			if (address == null) {
				Sys.println(args[i] + ": no such symbol");
				missing++;
				continue;
			}
			final place = map.resolve(address);
			if (place == null) {
				Sys.println("0x" + StringTools.hex(address, 6) + ": nothing generated covers this address");
				missing++;
				continue;
			}
			Sys.println(map.toString(place));
		}
		Sys.exit(missing == 0 ? 0 : 1);
	}

	static function listStatics(map:SourceMap):Int {
		var found = 0;
		for (source in map.maps.keys()) {
			final sidecar = map.maps.get(source);
			for (entry in sidecar.statics) {
				final address = map.addressOf(entry.symbol);
				if (address == null) continue;
				found++;
				Sys.println(StringTools.rpad(entry.name, " ", 24) + "0x" + StringTools.hex(address & 0xFFFFFF, 6)
					+ "  " + StringTools.rpad(entry.ctype, " ", 10) + sidecar.files[entry.file]
					+ ":" + entry.line);
			}
		}
		return found == 0 ? 1 : 0;
	}

	static function parse(map:SourceMap, text:String):Null<Int> {
		if (StringTools.startsWith(text, "0x") || StringTools.startsWith(text, "0X"))
			return Std.parseInt(text);
		final digits = ~/^[0-9]+$/;
		if (digits.match(text)) return Std.parseInt(text);
		return map.addressOf(text);
	}

	static function check(map:SourceMap):Int {
		var files = 0;
		var records = 0;
		var declared = 0;
		var probes = 0;
		var resolved = 0;
		var absent = 0;
		var wrong = 0;

		for (source in map.maps.keys()) {
			final sidecar = map.maps.get(source);
			files++;
			records += sidecar.lines.length;
			declared += sidecar.functions.length;

			for (entry in sidecar.functions) {
				final address = map.addressOf(entry.symbol);
				if (address == null) {
					absent++;
					continue;
				}

				final size = sizeOf(map, entry.symbol);
				for (offset in [0, size > 2 ? size >> 1 : 0]) {
					probes++;
					final place = map.resolve(address + offset);
					if (place == null || place.name != entry.name) {
						wrong++;
						Sys.println("  wrong: " + entry.symbol + "+" + offset + " reads as "
							+ (place == null ? "nothing" : place.name + " at " + place.file + ":" + place.line)
							+ ", expected " + entry.name);
						continue;
					}
					resolved++;
				}
			}
		}

		Sys.println("hx68k source map");
		Sys.println("  " + files + " generated files, " + records + " line records, "
			+ declared + " functions");
		Sys.println("  probes " + probes + ", resolved " + resolved + ", absent " + absent
			+ ", wrong " + wrong);

		if (resolved == 0) {
			Sys.println("  nothing resolved, so the map proves nothing");
			return 1;
		}
		return wrong == 0 ? 0 : 1;
	}

	static function sizeOf(map:SourceMap, symbol:String):Int {
		for (entry in map.elf.symbols) if (entry.name == symbol) return entry.size;
		return 0;
	}
}

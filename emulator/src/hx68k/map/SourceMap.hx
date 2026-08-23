package hx68k.map;

typedef Place = {
	final address:Int;
	final generated:String;
	final generatedLine:Int;
	final file:String;
	final line:Int;
	final name:String;
	final symbol:String;
}

class SourceMap {
	public final elf:Elf;
	public final dwarf:Dwarf;
	public final maps:Map<String, Hxmap> = [];

	public final variables:Null<Variables>;
	public final callFrames:Null<CallFrame>;

	final owners:Map<String, Hxmap> = [];

	public function new(elf:Elf, directory:String) {
		this.elf = elf;
		this.dwarf = new Dwarf(elf);
		this.variables = elf.section(".debug_info") == null ? null : new Variables(elf);
		this.callFrames = elf.section(".debug_frame") == null ? null : new CallFrame(elf);

		for (name in sys.FileSystem.readDirectory(directory)) {
			if (!StringTools.endsWith(name, ".hxmap")) continue;
			final map = new Hxmap(haxe.io.Path.join([directory, name]));
			maps.set(map.source, map);
			for (entry in map.functions) owners.set(entry.symbol, map);
		}
		if (!maps.iterator().hasNext()) throw "no .hxmap sidecars in " + directory;
	}

	public function addressOf(symbol:String):Null<Int> {
		return elf.addressOf(symbol);
	}

	public function functionNamed(name:String):Null<hx68k.map.Hxmap.Function> {
		for (source in maps.keys()) {
			for (entry in maps.get(source).functions) if (entry.name == name) return entry;
		}
		return null;
	}

	public function staticNamed(name:String):Null<hx68k.map.Hxmap.Static> {
		for (source in maps.keys()) {
			for (entry in maps.get(source).statics) if (entry.name == name) return entry;
		}
		return null;
	}

	public function addressOfLine(file:String, line:Int):Null<Int> {
		for (source in maps.keys()) {
			final sidecar = maps.get(source);
			var best:Null<Int> = null;
			for (record in sidecar.lines) {
				if (record.line != line || !StringTools.endsWith(sidecar.files[record.file], file)) continue;
				if (best == null || record.generated < best) best = record.generated;
			}
			if (best == null) continue;
			final at = dwarf.firstAddress(sidecar.source, best);
			if (at != null) return at;
		}
		return null;
	}

	public function resolve(address:Int):Null<Place> {
		final holder = elf.functionAt(address);
		if (holder == null) return null;

		final map = owners.get(holder.name);
		if (map == null) return null;

		final row = dwarf.at(map.source, address, holder.address);
		if (row == null) return null;

		final site = map.at(row.line);
		if (site == null) return null;

		return {
			address: address,
			generated: map.source,
			generatedLine: row.line,
			file: haxe.io.Path.join([map.root, site.file]),
			line: site.line,
			name: site.name,
			symbol: holder.name
		};
	}

	public function toString(place:Place):String {
		return "0x" + StringTools.hex(place.address, 6) + "  " + place.file + ":" + place.line
			+ "  " + place.name + "  (" + place.generated + ":" + place.generatedLine + ")";
	}
}

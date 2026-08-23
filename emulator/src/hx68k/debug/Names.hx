package hx68k.debug;

import hx68k.map.SourceMap;

class Names {
	public static inline final OUTSIDE = "outside any symbol";

	final map:Null<SourceMap>;
	final known:Map<Int, String> = [];

	public function new(map:Null<SourceMap>) {
		this.map = map;
	}

	public function at(address:Int):String {
		if (map == null) return OUTSIDE;

		final cached = known.get(address);
		if (cached != null) return cached;

		final place = map.resolve(address);
		var name = place == null ? null : place.name;

		if (name == null) {
			final symbol = map.elf.functionAt(address);
			name = symbol == null ? OUTSIDE : symbol.name;
		}

		known.set(address, name);
		return name;
	}
}

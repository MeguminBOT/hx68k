package hx68k.debug;

import hx68k.map.SourceMap;
import hx68k.map.Symbols;

class Names {
	public static inline final OUTSIDE = "outside any symbol";

	final map:Null<SourceMap>;
	final symbols:Null<Symbols>;
	final known:Map<Int, String> = [];

	public function new(debugger:Debugger) {
		this.map = debugger.map;
		this.symbols = debugger.symbols;
	}

	public function at(address:Int):String {
		final cached = known.get(address);
		if (cached != null) return cached;

		var name:Null<String> = null;

		if (map != null) {
			final place = map.resolve(address);
			name = place == null ? null : place.name;

			if (name == null) {
				final symbol = map.elf.functionAt(address);
				if (symbol != null) name = symbol.name;
			}
		}

		if (name == null && symbols != null) name = symbols.at(address);
		if (name == null) name = OUTSIDE;

		known.set(address, name);
		return name;
	}
}

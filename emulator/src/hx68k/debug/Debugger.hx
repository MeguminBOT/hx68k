package hx68k.debug;

import hx68k.map.SourceMap;
import hx68k.md.Machine;

class Debugger {
	public final machine:Machine;
	public final map:SourceMap;

	public function new(machine:Machine, map:SourceMap) {
		this.machine = machine;
		this.map = map;
	}

	public function at():Int {
		return (machine.cpu.pc - 4) & 0xFFFFFF;
	}

	public function site():Null<Place> {
		return map.resolve(at());
	}

	public function step():Void {
		machine.step();
	}

	public function runTo(address:Int, budget:Int = 8000000):Bool {
		var steps = 0;

		while (steps < budget) {
			if (at() == address) return true;
			machine.step();
			steps++;
		}

		return false;
	}

	public function stepLine(budget:Int = 100000):Null<Place> {
		final from = site();
		var steps = 0;

		while (steps < budget) {
			machine.step();
			steps++;

			final now = site();
			if (now == null) continue;
			if (from == null || now.line != from.line || now.file != from.file) return now;
		}

		return null;
	}

	public function breakpoint(name:String):Null<Int> {
		final entry = map.functionNamed(name);
		return entry == null ? null : map.addressOf(entry.symbol);
	}

	public function valueOf(name:String):Null<Int> {
		final entry = map.staticNamed(name);
		if (entry == null) return null;

		final address = map.addressOf(entry.symbol);
		if (address == null) return null;

		final at = address & 0xFFFFFF;
		final width = widthOf(entry.ctype);
		final signed = StringTools.startsWith(stem(entry.ctype), "s");

		return switch (width) {
			case 1:
				final word = machine.readWord(at);
				final value = (at & 1) == 0 ? (word >> 8) & 0xFF : word & 0xFF;
				signed && value >= 0x80 ? value - 0x100 : value;
			case 2:
				final value = machine.readWord(at);
				signed && value >= 0x8000 ? value - 0x10000 : value;
			case _:
				(machine.readWord(at) << 16) | machine.readWord(at + 2);
		}
	}

	public static function widthOf(ctype:String):Int {
		return switch (stem(ctype)) {
			case "s8", "u8", "bool": 1;
			case "s16", "u16": 2;
			case _: 4;
		}
	}

	static function stem(ctype:String):String {
		var text = StringTools.replace(ctype, "const ", "");
		final bracket = text.indexOf("[");
		if (bracket >= 0) text = text.substr(0, bracket);
		return StringTools.trim(text);
	}
}

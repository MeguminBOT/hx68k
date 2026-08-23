package hx68k.debug;

import hx68k.map.SourceMap;
import hx68k.map.Variables;
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
		final colon = name.lastIndexOf(":");
		if (colon > 0) {
			final line = Std.parseInt(name.substr(colon + 1));
			if (line != null) return map.addressOfLine(name.substr(0, colon), line);
		}

		final entry = map.functionNamed(name);
		return entry == null ? null : map.addressOf(entry.symbol);
	}

	public function valueOf(name:String):Null<Int> {
		final entry = map.staticNamed(name);
		if (entry == null) return null;

		final address = map.addressOf(entry.symbol);
		if (address == null) return null;

		return read(address & 0xFFFFFF, widthOf(entry.ctype), StringTools.startsWith(stem(entry.ctype), "s"));
	}

	public function localOf(name:String):Null<Int> {
		final variables = map.variables;
		if (variables == null) return null;

		final here = at();
		final subprogram = variables.at(here);
		if (subprogram == null) return null;

		for (variable in subprogram.variables) {
			if (variable.name != name) continue;

			final place = variables.placeOf(subprogram, variable, here);
			return switch (place.where) {
				case Constant: narrow(place.value, variable.width, variable.signed);
				case InRegister: narrow(register(place.register), variable.width, variable.signed);
				case AtRegisterOffset:
					read(register(place.register) + place.value, variable.width, variable.signed);
				case AtAddress: read(place.value, variable.width, variable.signed);
				case AtFrameOffset:
					final base = frameBase(subprogram, here);
					base == null ? null : read(base + place.value, variable.width, variable.signed);
				case _: null;
			}
		}

		return null;
	}

	public function frameBase(subprogram:Subprogram, address:Int):Null<Int> {
		switch (subprogram.frameBase.where) {
			case TheCallFrameAddress:
				final frames = map.callFrames;
				if (frames == null) return null;
				final cfa = frames.at(address);
				return cfa == null ? null : (register(cfa.register) + cfa.offset) & 0xFFFFFF;
			case AtRegisterOffset:
				return (register(subprogram.frameBase.register) + subprogram.frameBase.value) & 0xFFFFFF;
			case InRegister:
				return register(subprogram.frameBase.register) & 0xFFFFFF;
			case _:
				return null;
		}
	}

	public inline function register(number:Int):Int {
		return number < 8 ? machine.cpu.d[number] : machine.cpu.a[number - 8];
	}

	function read(address:Int, width:Int, signed:Bool):Int {
		final at = address & 0xFFFFFF;

		return switch (width) {
			case 1:
				final word = machine.readWord(at);
				narrow((at & 1) == 0 ? (word >> 8) & 0xFF : word & 0xFF, 1, signed);
			case 2: narrow(machine.readWord(at), 2, signed);
			case _: (machine.readWord(at) << 16) | machine.readWord(at + 2);
		}
	}

	static function narrow(value:Int, width:Int, signed:Bool):Int {
		return switch (width) {
			case 1:
				final byte = value & 0xFF;
				signed && byte >= 0x80 ? byte - 0x100 : byte;
			case 2:
				final word = value & 0xFFFF;
				signed && word >= 0x8000 ? word - 0x10000 : word;
			case _: value;
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

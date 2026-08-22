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
		return (machine.readWord(at) << 16) | machine.readWord(at + 2);
	}
}

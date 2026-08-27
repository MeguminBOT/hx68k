package hx68k.debug;

import hx68k.map.SourceMap;

typedef StackFrame = {
	final address:Int;
	final calledFrom:Int;
	final stack:Int;
	final name:String;
	final place:Null<Place>;
}

class Backtrace {
	static final CALL_LENGTHS = [2, 4, 6];

	public final debugger:Debugger;

	final names:Names;
	final disassembler:Disassembler;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
		this.names = new Names(debugger.map);
		this.disassembler = new Disassembler(new MachineCode(debugger.machine));
	}

	public function walk(limit:Int = 16, depth:Int = 2048):Array<StackFrame> {
		final here = debugger.at();
		final out = [describe(here, -1, -1)];

		final sp = debugger.machine.cpu.a[7] & 0xFFFFFF;
		var at = sp;

		while (at < sp + depth && out.length < limit) {
			final candidate = ((debugger.machine.readWord(at) << 16)
				| debugger.machine.readWord(at + 2)) & 0xFFFFFF;

			final from = callBefore(candidate);
			if (from >= 0) out.push(describe(candidate, from, at));

			at += 2;
		}

		return out;
	}

	public function callBefore(address:Int):Int {
		if ((address & 1) != 0 || address < 8) return -1;
		if (address >= 0x400000 && address < 0xE00000) return -1;

		for (length in CALL_LENGTHS) {
			final at = (address - length) & 0xFFFFFF;

			final word = debugger.machine.readWord(at);
			if ((word & 0xFFC0) != 0x4E80 && (word & 0xFF00) != 0x6100) continue;

			final instruction = disassembler.at(at);
			if (instruction.length != length) continue;

			final stem = instruction.text.substr(0, 3);
			if (stem == "JSR" || stem == "BSR") return at;
		}

		return -1;
	}

	function describe(address:Int, calledFrom:Int, stack:Int):StackFrame {
		return {
			address: address,
			calledFrom: calledFrom,
			stack: stack,
			name: names.at(address),
			place: debugger.map == null ? null : debugger.map.resolve(address)
		};
	}

	public static function line(frame:StackFrame):String {
		final where = StringTools.hex(frame.address, 6) + "  " + StringTools.rpad(frame.name, " ", 24);
		final site = frame.place == null
			? "-"
			: haxe.io.Path.withoutDirectory(frame.place.file) + ":" + frame.place.line;

		if (frame.calledFrom < 0) return where + site;
		return where + StringTools.rpad(site, " ", 18)
			+ "called from $" + StringTools.hex(frame.calledFrom, 6)
			+ ", on the stack at $" + StringTools.hex(frame.stack, 6);
	}
}

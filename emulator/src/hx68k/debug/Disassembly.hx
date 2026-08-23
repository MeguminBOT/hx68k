package hx68k.debug;

class Disassembly implements View {
	final debugger:Debugger;
	final disassembler:Disassembler;
	final names:Names;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
		this.disassembler = new Disassembler(new MachineCode(debugger.machine));
		this.names = new Names(debugger.map);
	}

	public function title():String {
		return "disassembly";
	}

	public function lines(rows:Int):Array<String> {
		final out = new Array<String>();
		var at = debugger.at();

		for (i in 0...rows) {
			final instruction = disassembler.at(at);
			final place = debugger.map == null ? null : debugger.map.resolve(at);

			final site = place == null
				? names.at(at)
				: haxe.io.Path.withoutDirectory(place.file) + ":" + place.line;

			out.push((i == 0 ? "> " : "  ") + StringTools.hex(at, 6) + "  "
				+ StringTools.rpad(instruction.text, " ", 28) + site);

			at = (at + instruction.length) & 0xFFFFFF;
		}

		return out;
	}
}

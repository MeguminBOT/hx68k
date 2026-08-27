package hx68k.debug;

import hx68k.debug.Row.RowKind;
import hx68k.debug.Row.RowPart;

class DisassemblyView implements View {
	final debugger:Debugger;
	final disassembler:Disassembler;
	final names:Names;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
		this.disassembler = new Disassembler(new MachineCode(debugger.machine));
		this.names = new Names(debugger);
	}

	public function title():String {
		return "disassembly";
	}

	public function rows(limit:Int):Array<Row> {
		final out = new Array<Row>();
		var at = debugger.at();

		if (debugger.map == null) {
			out.push(Row.said("no source map loaded, so these are addresses rather than Haxe"));
		}

		for (i in 0...limit) {
			final instruction = disassembler.at(at);
			final place = debugger.map == null ? null : debugger.map.resolve(at);

			final site = place != null
				? haxe.io.Path.withoutDirectory(place.file) + ":" + place.line
				: (debugger.map == null ? "" : names.at(at));

			final space = instruction.text.indexOf(" ");
			final what = space < 0 ? instruction.text : instruction.text.substr(0, space);
			final on = space < 0 ? "" : instruction.text.substr(space + 1);

			out.push(new Row([
				{text: i == 0 ? ">" : "", kind: Here},
				{text: StringTools.hex(at, 6), kind: Place},
				{text: what, kind: Value},
				{text: on, kind: Value},
				{text: site, kind: Aside}
			]));

			at = (at + instruction.length) & 0xFFFFFF;
		}

		return out;
	}
}

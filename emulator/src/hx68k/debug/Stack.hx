package hx68k.debug;

import hx68k.debug.Row.Kind;
import hx68k.debug.Row.Part;

class Stack implements View {
	final backtrace:Backtrace;

	public function new(debugger:Debugger) {
		this.backtrace = new Backtrace(debugger);
	}

	public function title():String {
		return "stack";
	}

	public function rows(limit:Int):Array<Row> {
		final out = new Array<Row>();

		for (frame in backtrace.walk(limit)) {
			final site = frame.place == null
				? ""
				: haxe.io.Path.withoutDirectory(frame.place.file) + ":" + frame.place.line;

			out.push(new Row([
				{text: StringTools.hex(frame.address, 6), kind: Place},
				{text: frame.name, kind: Value},
				{text: site, kind: Aside},
				{text: frame.calledFrom < 0 ? "" : "from " + StringTools.hex(frame.calledFrom, 6), kind: Aside}
			]));
		}

		return out;
	}
}

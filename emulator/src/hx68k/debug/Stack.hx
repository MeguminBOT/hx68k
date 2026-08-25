package hx68k.debug;

import hx68k.debug.Row.Kind;
import hx68k.debug.Row.Part;

class Stack implements View {
	final backtrace:Backtrace;
	final debugger:Debugger;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
		this.backtrace = new Backtrace(debugger);
	}

	public function title():String {
		return "stack";
	}

	public function rows(limit:Int):Array<Row> {
		final out = new Array<Row>();
		final named = debugger.map != null;

		if (!named) out.push(Row.said("no source map loaded, so these are return addresses only"));

		for (frame in backtrace.walk(limit)) {
			final site = frame.place == null
				? ""
				: haxe.io.Path.withoutDirectory(frame.place.file) + ":" + frame.place.line;

			out.push(new Row([
				{text: StringTools.hex(frame.address, 6), kind: Place},
				{text: named ? frame.name : "", kind: Value},
				{text: site, kind: Aside},
				{text: frame.calledFrom < 0 ? "" : "from " + StringTools.hex(frame.calledFrom, 6), kind: Aside}
			]));
		}

		return out;
	}
}

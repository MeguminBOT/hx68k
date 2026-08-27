package hx68k.debug.md;

import hx68k.debug.Debugger;
import hx68k.debug.Row.RowKind;
import hx68k.debug.Row.RowPart;
import hx68k.debug.Row;
import hx68k.debug.md.Slots.SlotLine;
import hx68k.debug.View;
import hx68k.md.Vdp;

class BandwidthView implements View {
	final slots:Slots;

	public function new(debugger:Debugger) {
		this.slots = new Slots(debugger);
	}

	public function title():String {
		return "slots";
	}

	public function rows(limit:Int):Array<Row> {
		final spend = slots.read();
		final out = new Array<Row>();

		out.push(new Row([
			said("written"), value(Std.string(spend.wrote)),
			said("landed"), value(Std.string(spend.landed)),
			said("by dma"), value(Std.string(spend.carried)),
			said("deepest"), value(spend.deepest + "/" + Vdp.FIFO_DEPTH),
			said("stalled"), value(Std.string(spend.stalled))
		]));

		out.push(Row.said(spend.overspent > 0
			? spend.overspent + " lines spent more slots than they had"
			: spend.overrun > 0
				? spend.overrun + " slots went while the beam was drawing"
				: "nothing reached video memory while the beam was drawing"));

		out.push(Row.blank());

		var line = 0;

		while (line < spend.lines.length && out.length < limit) {
			var end = line;
			while (end + 1 < spend.lines.length && alike(spend.lines[end + 1], spend.lines[line])) end++;

			final spent = spend.lines[line];
			final used = spent.landed + spent.carried;

			if (spent.wrote > 0 || used > 0 || spent.stalled > 0) {
				out.push(new Row([
					{text: line == end ? Std.string(line) : line + "-" + end, kind: Label},
					value(used + "/" + spent.open),
					{text: bar(used, spent.open), kind: used > spent.open ? Here : Value},
					{text: spent.deepest > 0 ? spent.deepest + "/" + Vdp.FIFO_DEPTH : "", kind: Aside},
					{text: spent.stalled > 0 ? spent.stalled + " waited" : "", kind: Aside},
					{text: spent.blanked ? "" : "drawing", kind: Aside}
				]));
			}

			line = end + 1;
		}

		if (out.length == 3) out.push(Row.said("nothing touched the VDP last frame"));

		return out.slice(0, limit);
	}

	static function bar(used:Int, open:Int):String {
		if (open < 1) return "";

		final full = used >= open ? 16 : Std.int(16.0 * used / open);
		var out = "";
		for (i in 0...16) out += i < full ? "#" : ".";
		return out;
	}

	static function alike(one:SlotLine, other:SlotLine):Bool {
		return one.wrote == other.wrote && one.landed == other.landed && one.carried == other.carried
			&& one.stalled == other.stalled && one.deepest == other.deepest
			&& one.blanked == other.blanked && one.open == other.open;
	}

	static inline function said(text:String):RowPart {
		return {text: text, kind: Label};
	}

	static inline function value(text:String):RowPart {
		return {text: text, kind: Value};
	}
}

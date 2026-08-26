package hx68k.debug;

import hx68k.md.Vdp;

typedef Spent = {
	final line:Int;
	final open:Int;
	final wrote:Int;
	final landed:Int;
	final carried:Int;
	final stalled:Int;
	final deepest:Int;
	final blanked:Bool;
	final wide:Bool;
}

typedef Spend = {
	final lines:Array<Spent>;
	final wrote:Int;
	final landed:Int;
	final carried:Int;
	final stalled:Int;
	final deepest:Int;
	final busiest:Int;
	final overrun:Int;
	final overspent:Int;
}

class Slots {
	public final debugger:Debugger;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
	}

	public function frame():Spend {
		final vdp = debugger.machine.vdp;
		debugger.machine.runFrame();

		final lines = new Array<Spent>();
		var wrote = 0;
		var landed = 0;
		var carried = 0;
		var stalled = 0;
		var deepest = 0;
		var busiest = 0;
		var overrun = 0;
		var overspent = 0;

		for (line in 0...Vdp.LINES_NTSC) {
			final shape = vdp.lineShape[line];
			final blanked = (shape & 1) != 0;
			final wide = (shape & 2) != 0;
			final open = openings(wide, blanked);
			final used = vdp.lineLanded[line] + vdp.lineCarried[line];

			lines.push({
				line: line,
				open: open,
				wrote: vdp.lineWrote[line],
				landed: vdp.lineLanded[line],
				carried: vdp.lineCarried[line],
				stalled: vdp.lineStalled[line],
				deepest: vdp.lineDeepest[line],
				blanked: blanked,
				wide: wide
			});

			wrote += vdp.lineWrote[line];
			landed += vdp.lineLanded[line];
			carried += vdp.lineCarried[line];
			stalled += vdp.lineStalled[line];
			if (vdp.lineDeepest[line] > deepest) deepest = vdp.lineDeepest[line];
			if (used > lines[busiest].landed + lines[busiest].carried) busiest = line;
			if (!blanked && used > 0) overrun += used;
			if (used > open) overspent++;
		}

		return {
			lines: lines,
			wrote: wrote,
			landed: landed,
			carried: carried,
			stalled: stalled,
			deepest: deepest,
			busiest: busiest,
			overrun: overrun,
			overspent: overspent
		};
	}

	public static function openings(wide:Bool, blanked:Bool):Int {
		final total = wide ? Vdp.SLOTS_H40 : Vdp.SLOTS_H32;
		var open = 0;
		for (at in 1...total + 1) if (Vdp.externalSlot(at, wide, blanked)) open++;
		return open;
	}

	public static function lines(spend:Spend, most:Int):Array<String> {
		final out = new Array<String>();
		out.push(pad("line", 8) + pad("slots", 7) + pad("used", 6) + pad("fifo", 7)
			+ pad("stalled", 9) + "what");

		var shown = 0;
		var line = 0;

		while (line < spend.lines.length) {
			var end = line;
			while (end + 1 < spend.lines.length && alike(spend.lines[end + 1], spend.lines[line])) end++;

			if (spend.lines[line].wrote > 0 || spend.lines[line].landed > 0
					|| spend.lines[line].carried > 0 || spend.lines[line].stalled > 0) {
				if (shown++ >= most) {
					out.push("    and " + (spend.lines.length - line) + " lines further down");
					return out;
				}
				out.push(row(spend.lines[line], end));
			}

			line = end + 1;
		}

		return out;
	}

	public static function summary(spend:Spend):Array<String> {
		final out = new Array<String>();
		final busiest = spend.lines[spend.busiest];

		out.push("the 68000 wrote " + spend.wrote + " words at the data port, and " + spend.landed
			+ " words in all reached video memory through the fifo");
		out.push("a fill or a copy moved " + spend.carried + " bytes, and the fifo got "
			+ spend.deepest + " of " + Vdp.FIFO_DEPTH + " deep");
		out.push("the 68000 waited " + spend.stalled + " master clocks on a full fifo, which is "
			+ share(spend.stalled, Vdp.MASTER_PER_LINE * Vdp.LINES_NTSC) + " of the frame");
		out.push("line " + busiest.line + " was the busiest, spending "
			+ (busiest.landed + busiest.carried) + " of its " + busiest.open + " slots");
		out.push(spend.overspent == 0
			? "no line spent more slots than it had"
			: spend.overspent + " lines spent more slots than they had");
		out.push(spend.overrun == 0
			? "nothing reached video memory while the beam was drawing"
			: spend.overrun + " slots went while the beam was drawing, where a line has far fewer");

		return out;
	}

	static function alike(one:Spent, other:Spent):Bool {
		return one.wrote == other.wrote && one.landed == other.landed && one.carried == other.carried
			&& one.stalled == other.stalled && one.deepest == other.deepest
			&& one.blanked == other.blanked && one.wide == other.wide;
	}

	static function row(spent:Spent, end:Int):String {
		final where = spent.line == end ? Std.string(spent.line) : spent.line + "-" + end;
		final used = spent.landed + spent.carried;

		return pad(where, 8) + pad(Std.string(spent.open), 7) + pad(Std.string(used), 6)
			+ pad(spent.deepest + "/" + Vdp.FIFO_DEPTH, 7) + pad(Std.string(spent.stalled), 9)
			+ (spent.blanked ? "blanked" : "drawing")
			+ (spent.wrote > 0 ? ", " + spent.wrote + " written" : "")
			+ (spent.carried > 0 ? ", " + spent.carried + " by dma" : "")
			+ (used > spent.open ? ", over its slots" : "");
	}

	static function pad(text:String, wide:Int):String {
		var out = text;
		while (out.length < wide) out = " " + out;
		return out + "  ";
	}

	static function share(part:Int, whole:Int):String {
		if (whole == 0) return "n/a";
		return Std.string(Math.round(1000.0 * part / whole) / 10) + "%";
	}
}

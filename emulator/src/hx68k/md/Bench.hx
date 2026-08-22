package hx68k.md;

import hx68k.map.Elf;

typedef Span = {
	final group:String;
	final kind:String;
	final cycles:Int;
}

class Bench {
	static inline final STEP_LIMIT = 20000000;
	static inline final TOLERANCE = 1.0;

	static function main():Void {
		final args = Sys.args();
		if (args.length < 3) {
			Sys.println("usage: bench <rom.bin> <rom.out> <group:kind> ...");
			Sys.exit(2);
		}

		final machine = new Machine();
		machine.vdp.rendering = false;
		machine.load(args[0]);

		final elf = new Elf(args[1]);
		final mark = address(elf, "hx_mark");
		final done = address(elf, "hx_probe_done");
		if (mark == null || done == null) {
			Sys.println("the ROM has no hx_mark or hx_probe_done");
			Sys.exit(2);
		}

		final measured = run(machine, mark, done);
		final labels = args.slice(2);

		if (measured.length != labels.length) {
			Sys.println("measured " + measured.length + " intervals but " + labels.length
				+ " were named");
			Sys.exit(1);
		}

		final spans:Array<Span> = [];
		for (i in 0...labels.length) {
			final parts = labels[i].split(":");
			spans.push({group: parts[0], kind: parts.length > 1 ? parts[1] : "haxe", cycles: measured[i]});
		}

		Sys.exit(report(spans));
	}

	static function address(elf:Elf, symbol:String):Null<Int> {
		final found = elf.addressOf(symbol);
		return found == null ? null : found & 0xFFFFFF;
	}

	static function run(machine:Machine, mark:Int, done:Int):Array<Int> {
		final intervals = [];
		var opened = -1;
		var steps = 0;

		while (machine.readWord(done) == 0 && steps < STEP_LIMIT) {
			if (((machine.cpu.pc - 4) & 0xFFFFFF) == mark) {
				if (opened >= 0) intervals.push(machine.cycles - opened);
				opened = machine.cycles;
			}
			machine.step();
			steps++;
		}

		return intervals;
	}

	static function report(spans:Array<Span>):Int {
		var slower = 0;

		for (span in spans) {
			final against = reference(spans, span.group);
			var note = "";
			if (against != null && span.kind != "c") {
				final percent = Math.round((span.cycles - against) * 1000 / against) / 10;
				note = "  " + (percent > 0 ? "+" : "") + percent + "% against C";
				if (percent > TOLERANCE) slower++;
			}
			Sys.println("  " + StringTools.rpad(span.group + " " + span.kind, " ", 24)
				+ StringTools.lpad(Std.string(span.cycles), " ", 9) + " cycles" + note);
		}

		Sys.println("");
		Sys.println(spans.length + " measured spans, " + slower + " more than " + TOLERANCE
			+ "% slower than the C written beside it");
		return slower == 0 ? 0 : 1;
	}

	static function reference(spans:Array<Span>, group:String):Null<Int> {
		for (span in spans) if (span.group == group && span.kind == "c") return span.cycles;
		return null;
	}
}

package hx68k.debug;

import hx68k.map.Elf;
import hx68k.map.SourceMap;
import hx68k.md.Machine;

class DebugTool {
	static function main():Void {
		final args = Sys.args();
		if (args.length < 3) {
			Sys.println("usage: debug <rom.bin> <rom.out> <generated-source>"
				+ " --break <Class.function> [--watch <Class.static> [--expect n,n,n]]"
				+ " [--trace n] [--profile frames [--settle frames]]");
			Sys.exit(2);
		}

		var stop = "";
		var watch = "";
		var traced = 0;
		var profiled = 0;
		var settle = 10;
		var expected:Array<Int> = [];

		var i = 3;
		while (i < args.length - 1) {
			switch (args[i]) {
				case "--break": stop = args[i + 1];
				case "--watch": watch = args[i + 1];
				case "--expect": expected = args[i + 1].split(",").map(text -> Std.parseInt(text));
				case "--trace": traced = Std.parseInt(args[i + 1]);
				case "--profile": profiled = Std.parseInt(args[i + 1]);
				case "--settle": settle = Std.parseInt(args[i + 1]);
				case _:
			}
			i += 2;
		}

		final machine = new Machine();
		machine.vdp.rendering = false;
		machine.load(args[0]);

		final debugger = new Debugger(machine, new SourceMap(new Elf(args[1]), args[2]));

		if (profiled > 0) Sys.exit(profile(debugger, stop, profiled, settle));
		Sys.exit(traced > 0 ? traceFrom(debugger, stop, traced) : hunt(debugger, stop, watch, expected));
	}

	static function profile(debugger:Debugger, stop:String, frames:Int, settle:Int):Int {
		if (stop != "") {
			final address = debugger.breakpoint(stop);
			if (address == null) {
				Sys.println("no such function: " + stop);
				return 2;
			}
			if (!debugger.runTo(address)) {
				Sys.println("never reached " + stop);
				return 1;
			}
			Sys.println("from " + stop + ", frame " + debugger.machine.vdp.frame
				+ " line " + debugger.machine.vdp.line);
		} else {
			for (_ in 0...settle) debugger.machine.runFrame();
		}

		final report = new Profiler(debugger).run(frames);
		Sys.println("profiled " + report.frames + " frames: " + report.cycles
			+ " cycles of 68000 in " + report.instructions + " instructions");
		Sys.println("");

		var attributed = 0;
		for (cost in report.costs) attributed += cost.cycles;

		var shown = 0;
		for (cost in report.costs) {
			if (shown++ >= 12) break;
			Sys.println("  " + StringTools.lpad(Std.string(cost.cycles), " ", 9)
				+ StringTools.lpad(share(cost.cycles, report.cycles), " ", 8)
				+ StringTools.lpad(Std.string(cost.instructions), " ", 10) + "  " + cost.name);
		}

		Sys.println("");
		for (run in runs(report.scanlines)) Sys.println("  " + run);

		Sys.println("");
		Sys.println("attributed " + attributed + " of " + report.cycles + " cycles to "
			+ report.costs.length + " names");

		return attributed == report.cycles ? 0 : 1;
	}

	static function runs(scanlines:Array<String>):Array<String> {
		final out = new Array<String>();
		var start = 0;

		while (start < scanlines.length) {
			var end = start;
			while (end + 1 < scanlines.length && scanlines[end + 1] == scanlines[start]) end++;

			final where = start == end ? Std.string(start) : start + "-" + end;
			out.push(StringTools.lpad(where, " ", 9) + "  "
				+ (scanlines[start] == "" ? "nothing ran" : scanlines[start]));
			start = end + 1;
		}

		return out;
	}

	static function share(part:Int, whole:Int):String {
		if (whole == 0) return "n/a";
		return Std.string(Math.round(1000.0 * part / whole) / 10) + "%";
	}

	static function traceFrom(debugger:Debugger, stop:String, instructions:Int):Int {
		final address = debugger.breakpoint(stop);
		if (address == null) {
			Sys.println("no such function: " + stop);
			return 2;
		}

		if (!debugger.runTo(address)) {
			Sys.println("never reached " + stop);
			return 1;
		}

		final steps = new Trace(debugger).record(instructions);
		var holes = 0;

		for (step in steps) {
			Sys.println(Trace.describe(step));
			if (StringTools.startsWith(step.text, "dc.w")) holes++;
		}

		final accounted = Trace.accountedFor(steps);
		if (accounted < steps.length) {
			var shown = 0;
			for (i in 0...steps.length - 1) {
				final step = steps[i];
				if (step.transfers || step.interrupted) continue;
				if (steps[i + 1].address == step.address + step.length) continue;
				if (shown++ >= 5) break;
				Sys.println("  unaccounted: " + Trace.describe(step) + "  -> $"
					+ StringTools.hex(steps[i + 1].address, 6) + " after " + step.length + " bytes");
			}
		}

		Sys.println("trace: " + steps.length + " instructions, " + accounted
			+ " accounted for, " + holes + " not disassembled");

		return accounted == steps.length && holes == 0 ? 0 : 1;
	}

	static function hunt(debugger:Debugger, stop:String, watch:String, expected:Array<Int>):Int {
		final address = debugger.breakpoint(stop);
		if (address == null) {
			Sys.println("no such function: " + stop);
			return 2;
		}

		if (!debugger.runTo(address)) {
			Sys.println("never reached " + stop);
			return 1;
		}

		final entry = debugger.site();
		Sys.println("break at " + where(entry) + "  " + stop);

		var seen = 0;
		var last = debugger.valueOf(watch);
		var here = entry;

		for (line in 0...200) {
			final ran = here;
			final place = debugger.stepLine();
			if (place == null) break;
			here = place;

			final value = debugger.valueOf(watch);
			if (value == last) continue;
			last = value;

			Sys.println("  " + where(ran) + "  " + watch + " = " + value);

			if (seen >= expected.length) continue;
			if (value == expected[seen]) {
				seen++;
				continue;
			}

			Sys.println("found: " + where(ran) + " sets " + watch + " to " + value + " where "
				+ expected[seen] + " was expected");
			return 0;
		}

		Sys.println("nothing went wrong in the first 200 lines of " + stop);
		return 1;
	}

	static function where(place:Null<Place>):String {
		if (place == null) return "somewhere with no Haxe behind it";
		return haxe.io.Path.withoutDirectory(place.file) + ":" + place.line;
	}
}

package hx68k.debug;

import hx68k.map.Elf;
import hx68k.map.SourceMap;
import hx68k.md.Machine;

class DebugTool {
	static function main():Void {
		final args = Sys.args();
		if (args.length < 3) {
			Sys.println("usage: debug <rom.bin> <rom.out> <generated-source>"
				+ " --break <Class.function> [--watch <Class.static> [--expect n,n,n]] [--trace n]");
			Sys.exit(2);
		}

		var stop = "";
		var watch = "";
		var traced = 0;
		var expected:Array<Int> = [];

		var i = 3;
		while (i < args.length - 1) {
			switch (args[i]) {
				case "--break": stop = args[i + 1];
				case "--watch": watch = args[i + 1];
				case "--expect": expected = args[i + 1].split(",").map(text -> Std.parseInt(text));
				case "--trace": traced = Std.parseInt(args[i + 1]);
				case _:
			}
			i += 2;
		}

		final machine = new Machine();
		machine.vdp.rendering = false;
		machine.load(args[0]);

		final debugger = new Debugger(machine, new SourceMap(new Elf(args[1]), args[2]));
		Sys.exit(traced > 0 ? traceFrom(debugger, stop, traced) : hunt(debugger, stop, watch, expected));
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

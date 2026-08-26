package hx68k.debug;

import hx68k.map.Elf;
import hx68k.map.SourceMap;
import hx68k.md.Machine;

class DebugTool {
	static function main():Void {
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
		if (args.length < 1) {
			Sys.println("usage: debug <rom.bin> [<rom.out> <generated-source>]"
				+ " --break <Class.function|File.hx:line> [--watch <Class.static> [--expect n,n,n]]"
				+ " [--trace n] [--profile frames] [--view] [--raster frames]"
				+ " [--read Class.static[,...]] [--stack] [--views] [--settle frames] [--hits n[,...]]");
			Sys.exit(2);
		}

		var stop = "";
		var watch = "";
		var traced = 0;
		var profiled = 0;
		var rastered = 0;
		var read = "";
		var settle = 10;
		var hits:Array<Int> = [1];
		var expected:Array<Int> = [];

		final viewing = args.indexOf("--view") >= 0;
		final walking = args.indexOf("--stack") >= 0;
		final showing = args.indexOf("--views") >= 0;

		var i = 1;
		while (i < args.length && args[i].charAt(0) != "-") i++;

		while (i < args.length) {
			switch (args[i]) {
				case "--break": stop = value(args, i);
				case "--watch": watch = value(args, i);
				case "--expect": expected = value(args, i).split(",").map(text -> Std.parseInt(text));
				case "--trace": traced = count(args, i);
				case "--profile": profiled = count(args, i);
				case "--raster": rastered = count(args, i);
				case "--read": read = value(args, i);
				case "--hits": hits = value(args, i).split(",").map(text -> Std.parseInt(text));
				case "--settle": settle = count(args, i);
				case _: i--;
			}
			i += 2;
		}

		final machine = new Machine();
		machine.vdp.rendering = false;
		machine.load(args[0]);

		var map:Null<SourceMap> = null;
		if (args.length >= 3 && args[1].charAt(0) != "-") {
			try {
				map = new SourceMap(new Elf(args[1]), args[2]);
			} catch (e:String) {
				Sys.println("no source map for " + args[1] + ": " + e);
				Sys.println("build the sample with its debug profile, which keeps the line table");
				Sys.exit(2);
				return;
			}
		}

		final debugger = new Debugger(machine, map);

		final once = hits[hits.length - 1];

		if (showing) Sys.exit(views(debugger, stop, settle, once));
		if (walking) Sys.exit(stack(debugger, stop, settle, once));
		if (read != "") Sys.exit(readNames(debugger, stop, read.split(","), settle, hits));
		if (viewing) Sys.exit(view(debugger, stop, settle, once));
		if (rastered > 0) Sys.exit(raster(debugger, stop, rastered, settle, once));
		if (profiled > 0) Sys.exit(profile(debugger, stop, profiled, settle, once));
		Sys.exit(traced > 0 ? traceFrom(debugger, stop, traced, settle, once) : hunt(debugger, stop, watch, expected));
	}

	static function show(value:Int, width:Int, signed:Bool):String {
		if (signed || width < 4) return Std.string(value);
		return "$" + StringTools.hex(value, 8);
	}

	static function views(debugger:Debugger, stop:String, settle:Int, hits:Int):Int {
		if (!reach(debugger, stop, settle, hits)) return 1;

		var shown = 0;
		for (view in Views.of(debugger)) {
			Sys.println("");
			Sys.println("--- " + view.title() + " ---");
			for (line in Views.lines(view, 24)) Sys.println("  " + line);
			shown++;
		}

		return shown > 0 ? 0 : 1;
	}

	static function stack(debugger:Debugger, stop:String, settle:Int, hits:Int):Int {
		if (!reach(debugger, stop, settle, hits)) return 1;

		final frames = new Backtrace(debugger).walk();
		for (frame in frames) Sys.println("  " + Backtrace.line(frame));

		Sys.println("");
		Sys.println(frames.length + " frames, the innermost first");

		final agreement = viaFrameRule(debugger);
		if (agreement != null && frames.length > 1) {
			final same = agreement == frames[1].address;
			Sys.println("the call frame rule puts the return address at $" + StringTools.hex(agreement, 6)
				+ ", which the scan " + (same ? "also found" : "did not find"));
			if (!same) return 1;
		}

		return frames.length > 1 ? 0 : 1;
	}

	static function viaFrameRule(debugger:Debugger):Null<Int> {
		final variables = debugger.map == null ? null : debugger.map.variables;
		if (variables == null) return null;

		final here = debugger.at();
		final subprogram = variables.at(here);
		if (subprogram == null) return null;

		final base = debugger.frameBase(subprogram, here);
		if (base == null) return null;

		final at = (base - 4) & 0xFFFFFF;
		return ((debugger.machine.readWord(at) << 16) | debugger.machine.readWord(at + 2)) & 0xFFFFFF;
	}

	static function readNames(debugger:Debugger, stop:String, names:Array<String>, settle:Int,
			hits:Array<Int>):Int {
		var worst = 0;
		var reached = 0;

		for (want in hits) {
			if (!reachRange(debugger, stop, settle, reached, want)) return 1;
			reached = want;

			for (name in names) {
				final code = readName(debugger, name);
				if (code > worst) worst = code;
			}
		}

		return worst;
	}

	static function readName(debugger:Debugger, name:String):Int {
		final entry = debugger.map == null ? null : debugger.map.staticNamed(name);
		if (entry != null) {
			final value = debugger.valueOf(name);
			Sys.println(name + "  static  " + entry.ctype + " = " + value);
			return value == null ? 1 : 0;
		}

		final variables = debugger.map == null ? null : debugger.map.variables;
		final subprogram = variables == null ? null : variables.at(debugger.at());
		if (subprogram == null) {
			Sys.println("no static named " + name + ", and nothing is known about where the program is");
			return 2;
		}

		for (variable in subprogram.variables) {
			if (variable.name != name) continue;

			final value = debugger.localOf(name);
			Sys.println(name + "  " + (variable.parameter ? "parameter" : "local") + "  "
				+ (variable.signed ? "s" : "u") + (variable.width * 8) + "  in " + subprogram.name
				+ " = " + (value == null ? "not where this can read it yet"
					: show(value, variable.width, variable.signed)));
			return value == null ? 1 : 0;
		}

		Sys.println("no static named " + name + ", and " + subprogram.name + " has no such variable");
		return 2;
	}

	static function raster(debugger:Debugger, stop:String, frames:Int, settle:Int, hits:Int):Int {
		if (!reach(debugger, stop, settle, hits)) return 1;

		final beam = new Raster(debugger).frames(frames);
		Sys.println("over " + frames + " frames and " + beam.instructions + " instructions the VDP took "
			+ beam.writes + " writes and " + beam.reads + " reads, from "
			+ beam.touches.length + " of them");
		Sys.println("  " + beam.offscreen + " of those writes went in with the display off, "
			+ beam.blanked + " while the beam was blanked, and " + beam.active
			+ " while it was drawing");

		Sys.println("");
		final counts = Raster.perLine(beam, beam.lines);
		for (band in 0...Std.int((beam.lines + 7) / 8)) {
			final row = new StringBuf();
			row.add(StringTools.lpad(Std.string(band * 8), " ", 5) + "  ");
			for (line in band * 8...band * 8 + 8) {
				row.add(line < counts.length ? weight(counts[line]) : " ");
			}
			Sys.println(row.toString());
		}

		Sys.println("");
		Sys.println("who touched it, in writes and reads");
		final wrote = new Map<String, Int>();
		final read = new Map<String, Int>();
		final order = new Array<String>();

		for (touch in beam.touches) {
			if (!wrote.exists(touch.name)) {
				order.push(touch.name);
				wrote.set(touch.name, 0);
				read.set(touch.name, 0);
			}
			wrote.set(touch.name, wrote.get(touch.name) + touch.writes);
			read.set(touch.name, read.get(touch.name) + touch.reads);
		}
		order.sort((a, b) -> (wrote.get(b) + read.get(b)) - (wrote.get(a) + read.get(a)));

		var shown = 0;
		for (name in order) {
			if (shown++ >= 8) break;
			Sys.println("  " + StringTools.lpad(Std.string(wrote.get(name)), " ", 7)
				+ StringTools.lpad(Std.string(read.get(name)), " ", 9) + "  " + name);
		}

		final split = beam.offscreen + beam.blanked + beam.active;
		Sys.println("");
		Sys.println("placed " + split + " of " + beam.writes + " writes against the beam");

		return beam.writes > 0 && split == beam.writes ? 0 : 1;
	}

	static function weight(writes:Int):String {
		if (writes == 0) return ".";
		if (writes < 8) return "-";
		if (writes < 64) return "+";
		return "#";
	}

	static function value(args:Array<String>, i:Int):String {
		return i + 1 < args.length ? args[i + 1] : "";
	}

	static function count(args:Array<String>, i:Int):Int {
		final parsed = Std.parseInt(value(args, i));
		return parsed == null ? 0 : parsed;
	}

	static function view(debugger:Debugger, stop:String, settle:Int, hits:Int):Int {
		if (!reach(debugger, stop, settle, hits)) return 1;

		final viewer = new Viewer(debugger.machine.vdp);
		final shape = viewer.layout();

		Sys.println("display " + (shape.display ? "on" : "off") + "  " + (shape.wide ? "H40" : "H32")
			+ "  " + (shape.tall ? "V30" : "V28") + (shape.effects ? "  shadow and highlight" : "")
			+ "  plane " + shape.columns + "x" + shape.rows + " cells  backdrop " + shape.backdrop);
		Sys.println("bases   plane A $" + StringTools.hex(shape.planeA, 4)
			+ "  plane B $" + StringTools.hex(shape.planeB, 4)
			+ "  window $" + StringTools.hex(shape.window, 4)
			+ "  sprites $" + StringTools.hex(shape.sprites, 4)
			+ "  hscroll $" + StringTools.hex(shape.horizontalScroll, 4));

		Sys.println("");
		for (row in 0...4) {
			final line = new StringBuf();
			line.add("palette " + row + "  ");
			for (column in 0...16) line.add(StringTools.hex(debugger.machine.vdp.cram[row * 16 + column], 4) + " ");
			Sys.println(line.toString());
		}

		Sys.println("");
		Sys.println("vram    " + occupancy(viewer));

		Sys.println("");
		final sprites = viewer.spriteList();
		Sys.println("sprites " + sprites.length + " in the link chain");
		var shown = 0;
		for (sprite in sprites) {
			if (shown++ >= 8) break;
			Sys.println("  " + StringTools.lpad(Std.string(sprite.index), " ", 3)
				+ "  at " + StringTools.lpad(Std.string(sprite.x), " ", 4)
				+ "," + StringTools.lpad(Std.string(sprite.y), " ", 4)
				+ "  " + sprite.width + "x" + sprite.height + " cells"
				+ "  tile " + StringTools.lpad(Std.string(sprite.tile), " ", 4)
				+ "  palette " + sprite.palette
				+ (sprite.priority ? "  front" : "")
				+ (sprite.flipX ? "  flipX" : "") + (sprite.flipY ? "  flipY" : "")
				+ "  link " + sprite.link);
		}

		Sys.println("");
		Sys.println("plane A, first four rows");
		for (row in 0...4) {
			final line = new StringBuf();
			line.add("  ");
			for (column in 0...16) {
				final entry = viewer.cell(shape.planeA, column, row);
				line.add(StringTools.hex(entry.tile, 3) + (entry.priority ? "!" : " "));
			}
			Sys.println(line.toString());
		}

		return 0;
	}

	static function occupancy(viewer:Viewer):String {
		final out = new StringBuf();
		for (used in viewer.vramUse()) out.add(used == 0 ? "." : (used >= 0x800 ? "#" : "-"));
		return out.toString();
	}

	static function reach(debugger:Debugger, stop:String, settle:Int, hits:Int = 1):Bool {
		return reachRange(debugger, stop, settle, 0, hits);
	}

	static function reachRange(debugger:Debugger, stop:String, settle:Int, from:Int, to:Int):Bool {
		if (stop == "") {
			if (from == 0) for (_ in 0...settle) debugger.machine.runFrame();
			return true;
		}

		final address = debugger.breakpoint(stop);
		if (address == null) {
			Sys.println("no such function: " + stop);
			return false;
		}

		var at = from;
		while (at < to) {
			if (at > 0) debugger.step();
			if (!debugger.runTo(address)) {
				Sys.println("reached " + stop + " " + at + " times, not " + to);
				return false;
			}
			at++;
		}

		Sys.println("at " + stop + (to > 1 ? ", call " + to : "") + ", frame "
			+ debugger.machine.vdp.frame + " line " + debugger.machine.vdp.line);
		return true;
	}

	static function profile(debugger:Debugger, stop:String, frames:Int, settle:Int, hits:Int):Int {
		if (!reach(debugger, stop, settle, hits)) return 1;

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

	static function traceFrom(debugger:Debugger, stop:String, instructions:Int, settle:Int, hits:Int):Int {
		if (!reach(debugger, stop, settle, hits)) return 1;

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

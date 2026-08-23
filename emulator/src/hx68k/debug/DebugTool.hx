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
				+ " [--trace n] [--profile frames] [--view] [--raster frames] [--settle frames]");
			Sys.exit(2);
		}

		var stop = "";
		var watch = "";
		var traced = 0;
		var profiled = 0;
		var rastered = 0;
		var settle = 10;
		var expected:Array<Int> = [];

		final viewing = args.indexOf("--view") >= 0;

		var i = 3;
		while (i < args.length) {
			switch (args[i]) {
				case "--break": stop = value(args, i);
				case "--watch": watch = value(args, i);
				case "--expect": expected = value(args, i).split(",").map(text -> Std.parseInt(text));
				case "--trace": traced = count(args, i);
				case "--profile": profiled = count(args, i);
				case "--raster": rastered = count(args, i);
				case "--settle": settle = count(args, i);
				case _: i--;
			}
			i += 2;
		}

		final machine = new Machine();
		machine.vdp.rendering = false;
		machine.load(args[0]);

		final debugger = new Debugger(machine, new SourceMap(new Elf(args[1]), args[2]));

		if (viewing) Sys.exit(view(debugger, stop, settle));
		if (rastered > 0) Sys.exit(raster(debugger, stop, rastered, settle));
		if (profiled > 0) Sys.exit(profile(debugger, stop, profiled, settle));
		Sys.exit(traced > 0 ? traceFrom(debugger, stop, traced) : hunt(debugger, stop, watch, expected));
	}

	static function raster(debugger:Debugger, stop:String, frames:Int, settle:Int):Int {
		if (!reach(debugger, stop, settle)) return 1;

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

	static function view(debugger:Debugger, stop:String, settle:Int):Int {
		if (!reach(debugger, stop, settle)) return 1;

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

	static function reach(debugger:Debugger, stop:String, settle:Int):Bool {
		if (stop == "") {
			for (_ in 0...settle) debugger.machine.runFrame();
			return true;
		}

		final address = debugger.breakpoint(stop);
		if (address == null) {
			Sys.println("no such function: " + stop);
			return false;
		}
		if (!debugger.runTo(address)) {
			Sys.println("never reached " + stop);
			return false;
		}

		Sys.println("from " + stop + ", frame " + debugger.machine.vdp.frame
			+ " line " + debugger.machine.vdp.line);
		return true;
	}

	static function profile(debugger:Debugger, stop:String, frames:Int, settle:Int):Int {
		if (!reach(debugger, stop, settle)) return 1;

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

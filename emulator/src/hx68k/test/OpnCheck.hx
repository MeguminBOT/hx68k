package hx68k.test;

import haxe.io.Bytes;
import hx68k.md.Ym2612;
import sys.FileSystem;
import sys.io.File;

class OpnCheck {
	static inline final LAG = 32;

	static inline final SETTLE = 200;

	static function main():Void {
		final args = Sys.args();

		if (args.length < 2) {
			Sys.println("usage: opn <scripts> <references>        every fixture, counted by group");
			Sys.println("       opn <script.txt> <reference.pcm>  one fixture, printing where it parts");
			Sys.println("       opn <script.txt> <reference.pcm> --envelope   ... and what channel one held");
			Sys.println("       opn <script.txt> <reference.pcm> --inside     ... and what a sample was made of");
			Sys.println("       opn <script.txt> <reference.pcm> --oscillator ... and where the oscillator was");
			Sys.println("       ... <trace> <from sample> <channel>   any of the three, on any channel");
			Sys.exit(2);
		}

		if (args.length > 4) traced = Std.parseInt(args[4]);

		if (FileSystem.isDirectory(args[0])) whole(args[0], args[1]);
		else single(args[0], args[1], args.length > 2 ? args[2] : null,
			args.length > 3 ? Std.parseInt(args[3]) : -1);
	}

	static function whole(scripts:String, references:String):Void {
		final groups:Map<String, Array<Outcome>> = new Map();
		final order:Array<String> = [];

		for (file in FileSystem.readDirectory(scripts)) {
			if (!StringTools.endsWith(file, ".txt")) continue;

			final name = file.substr(0, file.length - 4);
			final reference = references + "/" + name + ".pcm";
			if (!FileSystem.exists(reference)) continue;

			final at = name.indexOf("-");
			final group = at < 0 ? name : name.substr(0, at);
			if (!groups.exists(group)) {
				groups.set(group, []);
				order.push(group);
			}

			groups.get(group).push(measure(name, scripts + "/" + file, reference));
		}

		order.sort(Reflect.compare);

		var exact = 0;
		var total = 0;

		for (group in order) {
			final outcomes = groups.get(group);
			var kept = 0;
			for (outcome in outcomes) if (outcome.exact) kept++;

			exact += kept;
			total += outcomes.length;

			Sys.println("  " + StringTools.rpad(group, " ", 12)
				+ StringTools.lpad(Std.string(kept), " ", 4) + " of "
				+ StringTools.lpad(Std.string(outcomes.length), " ", 4) + " bit identical");

			var shown = 0;
			for (outcome in outcomes) {
				if (outcome.exact || shown >= 3) continue;
				Sys.println("      " + outcome.line);
				shown++;
			}
		}

		Sys.println("");
		Sys.println("  " + exact + " of " + total + " fixtures bit identical ("
			+ round(total == 0 ? 0 : 100.0 * exact / total) + "%)");
	}

	static function single(script:String, reference:String, watching:Null<String>, from:Int):Void {
		final parts = script.split("/");
		var name = parts[parts.length - 1];
		if (StringTools.endsWith(name, ".txt")) name = name.substr(0, name.length - 4);
		watched = watching == null ? "" : watching;
		final held:Null<Array<Array<Int>>> = watching == null ? null : [];
		final outcome = measure(name, script, reference, held);
		Sys.println(outcome.line);

		final mine = outcome.mine;
		final theirs = outcome.reference;

		if (held != null && from >= 0) {
			Sys.println("  sample      mine     reference" + columns());
			for (i in from...from + 20) {
				if (i >= mine.length || i >= theirs.length) break;
				Sys.println("  " + StringTools.lpad(Std.string(i), " ", 6)
					+ StringTools.lpad(Std.string(mine[i]), " ", 10)
					+ StringTools.lpad(Std.string(theirs[i]), " ", 14) + row(held, i));
			}
			return;
		}

		if (outcome.exact) return;
		final until = (mine.length < theirs.length ? mine.length : theirs.length) - outcome.lag;
		var shown = 0;

		var first = -1;
		for (i in SETTLE...until) {
			if (mine[i] == theirs[i + outcome.lag]) continue;
			if (first < 0) first = i;
			if (shown == 0) Sys.println("  sample      mine     reference" + (held == null ? "" : columns()));
			Sys.println("  " + StringTools.lpad(Std.string(i), " ", 6)
				+ StringTools.lpad(Std.string(mine[i]), " ", 10)
				+ StringTools.lpad(Std.string(theirs[i + outcome.lag]), " ", 14)
				+ (held == null ? "" : row(held, i)));
			if (++shown >= 16) break;
		}

		if (held != null && first > SETTLE) {
			Sys.println("");
			Sys.println("  before it parted");
			for (i in (first - 6)...first) {
				Sys.println("  " + StringTools.lpad(Std.string(i), " ", 6)
					+ StringTools.lpad(Std.string(mine[i]), " ", 10)
					+ StringTools.lpad(Std.string(theirs[i + outcome.lag]), " ", 14) + row(held, i));
			}
		}
	}

	static function row(held:Array<Array<Int>>, at:Int):String {
		if (at >= held.length) return "";

		final width = watched == "--inside" || watched == "--oscillator" ? 7 : 5;
		var out = "  ";
		for (value in held[at]) out += StringTools.lpad(Std.string(value), " ", width);
		return out;
	}

	static function measure(name:String, script:String, reference:String,
			held:Null<Array<Array<Int>>> = null):Outcome {
		final steps = parse(File.getContent(script));
		final theirs = samplesOf(File.getBytes(reference));

		final mine = run(steps, theirs.length, held, StringTools.startsWith(name, "discrete-"));

		final count = mine.length < theirs.length ? mine.length : theirs.length;
		if (count <= SETTLE) {
			return {
				name: name, exact: false, lag: 0, mine: mine, reference: theirs,
				line: StringTools.rpad(name, " ", 22) + "nothing to compare"
			};
		}

		var best = exactness(mine, theirs, 0);
		var lag = 0;

		if (best < 1) {
			for (at in 1...LAG + 1) {
				final share = exactness(mine, theirs, at);
				if (share > best) {
					best = share;
					lag = at;
				}
			}
		}

		var worst = 0;
		final until = count - lag;
		for (i in SETTLE...until) {
			final off = mine[i] - theirs[i + lag];
			final size = off < 0 ? -off : off;
			if (size > worst) worst = size;
		}

		var line = StringTools.rpad(name, " ", 22)
			+ "exact " + StringTools.lpad(round(best * 100), " ", 8) + "%"
			+ "   worst " + StringTools.lpad(Std.string(worst), " ", 4)
			+ "   lag " + StringTools.lpad(Std.string(lag), " ", 3);

		if (best < 1) line += "   correlation " + round(correlate(mine, theirs, lag));
		if (silent(mine)) line += "   THIS MADE NO SOUND";

		return {
			name: name, exact: best >= 1 && lag == 0, lag: lag,
			mine: mine, reference: theirs, line: line
		};
	}

	static function parse(text:String):Array<Step> {
		final out:Array<Step> = [];

		for (line in text.split("\n")) {
			final bits = StringTools.trim(line).split(" ");
			if (bits.length < 3) continue;

			out.push({
				wait: Std.parseInt(bits[0]),
				port: Std.parseInt(bits[1]),
				value: Std.parseInt(bits[2])
			});
		}

		return out;
	}

	static function samplesOf(bytes:Bytes):Array<Int> {
		final out = [];

		var at = 0;
		while (at + 3 < bytes.length) {
			final value = bytes.getUInt16(at);
			out.push(value >= 0x8000 ? value - 0x10000 : value);
			at += 4;
		}

		return out;
	}

	static var watched:String = "";

	static var traced:Int = 0;

	static function columns():String {
		return switch (watched) {
			case "--inside": "     phase   out   pub  left";
			case "--oscillator": "     step  swell    inc  level";
			case _: "     S1   S3   S2   S4";
		}
	}

	static function run(steps:Array<Step>, count:Int, held:Null<Array<Array<Int>>>,
			discrete:Bool):Array<Int> {
		final chip = new Ym2612();
		chip.discrete = discrete;
		final out = [];

		inline function one():Void {
			final channel = chip.channels[traced];
			final waiting = watched != "--oscillator" ? null : [
				chip.lfoPhase, chip.swell, channel.operators[0].increment,
				channel.operators[0].level(channel.operators[0].totalLevel << 3)
			];

			chip.sample();
			out.push(chip.left);

			if (held != null) {
				final operators = channel.operators;
				held.push(switch (watched) {
					case "--inside":
						[operators[0].phase, channel.outputs[0], channel.published, chip.left];
					case "--oscillator": waiting;
					case _:
						[
							operators[0].envelope, operators[2].envelope,
							operators[1].envelope, operators[3].envelope
						];
				});
			}
		}

		for (step in steps) {
			for (_ in 0...step.wait) {
				if (out.length >= count) break;
				one();
			}
			chip.write(step.port, step.value);
		}

		while (out.length < count) one();
		return out;
	}

	static function exactness(mine:Array<Int>, reference:Array<Int>, lag:Int):Float {
		final until = (mine.length < reference.length ? mine.length : reference.length) - lag;
		if (until - SETTLE < 16) return -1;

		var same = 0;
		for (i in SETTLE...until) if (mine[i] == reference[i + lag]) same++;
		return same / (until - SETTLE);
	}

	static function correlate(mine:Array<Int>, reference:Array<Int>, lag:Int):Float {
		final until = (mine.length < reference.length ? mine.length : reference.length) - lag;
		if (until - SETTLE < 16) return 0;

		var sumMine = 0.0;
		var sumTheirs = 0.0;
		for (i in SETTLE...until) {
			sumMine += mine[i];
			sumTheirs += reference[i + lag];
		}

		final meanMine = sumMine / (until - SETTLE);
		final meanTheirs = sumTheirs / (until - SETTLE);

		var together = 0.0;
		var squareMine = 0.0;
		var squareTheirs = 0.0;

		for (i in SETTLE...until) {
			final a = mine[i] - meanMine;
			final b = reference[i + lag] - meanTheirs;
			together += a * b;
			squareMine += a * a;
			squareTheirs += b * b;
		}

		final spread = Math.sqrt(squareMine * squareTheirs);
		return spread == 0 ? 0 : together / spread;
	}

	static function silent(samples:Array<Int>):Bool {
		for (sample in samples) if (sample != 0) return false;
		return true;
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 1000) / 1000);
	}
}

private typedef Step = {
	final wait:Int;
	final port:Int;
	final value:Int;
}

private typedef Outcome = {
	final name:String;
	final exact:Bool;
	final lag:Int;
	final mine:Array<Int>;
	final reference:Array<Int>;
	final line:String;
}

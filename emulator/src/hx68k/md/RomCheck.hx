package hx68k.md;

import hx68k.map.Elf;

enum Check {
	Value(symbol:String, offset:Int, width:Int, expected:Int);
	Vram(at:Int, expected:Int);
	Cram(index:Int, expected:Int);
}

typedef Job = {
	final name:String;
	final rom:String;
	final elf:String;
	var symbol:String;
	var width:Int;
	var reach:Int;
	var frames:Int;
	final checks:Array<Check>;
}

class RomCheck {
	static function main():Void {
		final args = Sys.args();
		if (args.length < 2) {
			Sys.println("usage: rom <observables file> <repository root>");
			Sys.exit(2);
		}

		final root = args[1];
		final jobs = read(args[0]);
		if (jobs.length == 0) {
			Sys.println("no ROMs listed in " + args[0]);
			Sys.exit(2);
		}

		var failed = 0;
		for (job in jobs) failed += run(job, root);
		Sys.exit(failed == 0 ? 0 : 1);
	}

	static function read(path:String):Array<Job> {
		final jobs:Array<Job> = [];

		for (text in sys.io.File.getContent(path).split("\n")) {
			final parts = StringTools.trim(text).split(" ");
			final job = jobs.length == 0 ? null : jobs[jobs.length - 1];

			switch (parts[0]) {
				case "rom": jobs.push({
						name: parts[1],
						rom: parts[2],
						elf: parts[3],
						symbol: "",
						width: 0,
						reach: 0,
						frames: 0,
						checks: []
					});
				case "until" if (job != null):
					job.symbol = parts[1];
					job.width = Std.parseInt(parts[2]);
					job.reach = Std.parseInt(parts[3]);
					job.frames = Std.parseInt(parts[4]);
				case "value" if (job != null):
					job.checks.push(Value(parts[1], Std.parseInt(parts[2]), Std.parseInt(parts[3]),
						Std.parseInt(parts[4])));
				case "vram" if (job != null):
					job.checks.push(Vram(Std.parseInt(parts[1]), Std.parseInt(parts[2])));
				case "cram" if (job != null):
					job.checks.push(Cram(Std.parseInt(parts[1]), Std.parseInt(parts[2])));
				case _:
			}
		}

		return jobs;
	}

	static function run(job:Job, root:String):Int {
		final machine = new Machine();
		machine.vdp.rendering = false;
		machine.load(haxe.io.Path.join([root, job.rom]));
		final elf = new Elf(haxe.io.Path.join([root, job.elf]));

		final target = address(elf, job.symbol);
		if (target == null) {
			Sys.println("  FAIL " + job.name + ": no symbol " + job.symbol);
			return 1;
		}

		var frames = 0;
		while (frames < job.frames && peek(machine, target, job.width) < job.reach) {
			machine.runFrame();
			frames++;
		}

		final reached = peek(machine, target, job.width);
		if (reached < job.reach) {
			Sys.println("  FAIL " + job.name + ": " + job.symbol + " reached " + reached
				+ " of " + job.reach + " in " + frames + " frames");
			return 1;
		}

		var wrong = 0;
		for (check in job.checks) {
			final seen = observe(machine, elf, check);
			final want = expected(check);
			if (seen == want) continue;
			wrong++;
			Sys.println("  FAIL " + job.name + ": " + describe(check) + " got " + seen
				+ " want " + want);
		}

		Sys.println((wrong == 0 ? "  ok   " : "  FAIL ") + job.name + ": " + (job.checks.length - wrong)
			+ " of " + job.checks.length + " observables match Musashi after " + frames + " frames");
		return wrong == 0 ? 0 : 1;
	}

	static function address(elf:Elf, symbol:String):Null<Int> {
		final found = elf.addressOf(symbol);
		return found == null ? null : found & 0xFFFFFF;
	}

	static function peek(machine:Machine, at:Int, width:Int):Int {
		return switch (width) {
			case 4: (machine.readWord(at) << 16) | machine.readWord(at + 2);
			case 2: machine.readWord(at);
			case _: (machine.readWord(at) >> 8) & 0xFF;
		}
	}

	static function observe(machine:Machine, elf:Elf, check:Check):Int {
		return switch (check) {
			case Value(symbol, offset, width, _):
				final at = address(elf, symbol);
				at == null ? 0 : peek(machine, at + offset, width);
			case Vram(at, _):
				(machine.vdp.vram.get(at) << 8) | machine.vdp.vram.get(at | 1);
			case Cram(index, _):
				machine.vdp.cram[index];
		}
	}

	static function expected(check:Check):Int {
		return switch (check) {
			case Value(_, _, _, value): value;
			case Vram(_, value): value;
			case Cram(_, value): value;
		}
	}

	static function describe(check:Check):String {
		return switch (check) {
			case Value(symbol, offset, _, _): symbol + "+" + offset;
			case Vram(at, _): "vram 0x" + StringTools.hex(at, 4);
			case Cram(index, _): "cram " + index;
		}
	}
}

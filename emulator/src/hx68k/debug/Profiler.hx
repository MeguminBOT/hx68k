package hx68k.debug;

typedef ProfileCost = {
	final name:String;
	var cycles:Int;
	var instructions:Int;
}

typedef Profile = {
	final cycles:Int;
	final instructions:Int;
	final frames:Int;
	final costs:Array<ProfileCost>;
	final scanlines:Array<String>;
}

class Profiler {
	public final debugger:Debugger;

	final names:Names;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
		this.names = new Names(debugger);
	}

	public function run(frames:Int):Profile {
		final machine = debugger.machine;
		final costs:Map<String, ProfileCost> = [];
		final order = new Array<String>();
		final target = machine.vdp.frame + frames;

		var lines = new Map<Int, Map<String, Int>>();
		var lastFrame = machine.vdp.frame;
		var instructions = 0;
		final started = machine.cycles;

		while (machine.vdp.frame != target) {
			final name = names.at(debugger.at());
			final line = machine.vdp.line;
			final before = machine.cycles;

			if (machine.vdp.frame != lastFrame) {
				lastFrame = machine.vdp.frame;
				lines = new Map<Int, Map<String, Int>>();
			}

			machine.step();
			instructions++;

			final spent = machine.cycles - before;
			var cost = costs.get(name);
			if (cost == null) {
				cost = {name: name, cycles: 0, instructions: 0};
				costs.set(name, cost);
				order.push(name);
			}
			cost.cycles += spent;
			cost.instructions++;

			var row = lines.get(line);
			if (row == null) {
				row = new Map<String, Int>();
				lines.set(line, row);
			}
			row.set(name, (row.exists(name) ? row.get(name) : 0) + spent);
		}

		final ranked = [for (name in order) costs.get(name)];
		ranked.sort((a, b) -> b.cycles - a.cycles);

		return {
			cycles: machine.cycles - started,
			instructions: instructions,
			frames: frames,
			costs: ranked,
			scanlines: dominant(lines)
		};
	}

	static function dominant(lines:Map<Int, Map<String, Int>>):Array<String> {
		var highest = -1;
		for (line in lines.keys()) if (line > highest) highest = line;

		final out = new Array<String>();
		for (line in 0...highest + 1) {
			final row = lines.get(line);
			if (row == null) {
				out.push("");
				continue;
			}

			var best = "";
			var most = -1;
			for (name in row.keys()) {
				final spent = row.get(name);
				if (spent > most) {
					most = spent;
					best = name;
				}
			}
			out.push(best);
		}

		return out;
	}
}

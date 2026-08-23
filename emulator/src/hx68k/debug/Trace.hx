package hx68k.debug;

import hx68k.map.SourceMap;

typedef Step = {
	final address:Int;
	final text:String;
	final length:Int;
	final transfers:Bool;
	final interrupted:Bool;
	final place:Null<Place>;
}

class Trace {
	public final debugger:Debugger;

	final disassembler:Disassembler;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
		this.disassembler = new Disassembler(new MachineCode(debugger.machine));
	}

	public function step():Step {
		final address = debugger.at();
		final instruction = disassembler.at(address);
		final place = debugger.site();
		final taken = debugger.machine.interrupts;
		debugger.step();

		return {
			address: address,
			text: instruction.text,
			length: instruction.length,
			transfers: transfers(instruction.text),
			interrupted: debugger.machine.interrupts != taken,
			place: place
		};
	}

	public function record(instructions:Int):Array<Step> {
		final out = new Array<Step>();
		for (_ in 0...instructions) out.push(step());
		return out;
	}

	public static function describe(step:Step):String {
		final code = StringTools.hex(step.address, 6) + "  " + StringTools.rpad(step.text, " ", 28);
		if (step.place == null) return code + "-";
		return code + haxe.io.Path.withoutDirectory(step.place.file) + ":" + step.place.line
			+ "  " + step.place.name;
	}

	public static function accountedFor(steps:Array<Step>):Int {
		var count = 0;

		for (i in 0...steps.length) {
			final step = steps[i];
			if (step.transfers || step.interrupted) {
				count++;
				continue;
			}
			if (i + 1 >= steps.length || steps[i + 1].address == step.address + step.length) count++;
		}

		return count;
	}

	static function transfers(text:String):Bool {
		final space = text.indexOf(" ");
		final name = space < 0 ? text : text.substr(0, space);
		final dot = name.indexOf(".");
		final stem = dot < 0 ? name : name.substr(0, dot);

		if (stem.charAt(0) == "B" && stem.length <= 3) return true;
		if (StringTools.startsWith(stem, "DB")) return true;

		return switch (stem) {
			case "JMP", "JSR", "RTS", "RTE", "RTR", "TRAP", "TRAPV", "CHK", "STOP", "RESET": true;
			case "DIVU", "DIVS", "ILLEGAL": true;
			case _: false;
		}
	}
}

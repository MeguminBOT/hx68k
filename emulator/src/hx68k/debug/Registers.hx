package hx68k.debug;

class Registers implements View {
	final debugger:Debugger;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
	}

	public function title():String {
		return "registers";
	}

	public function lines(rows:Int):Array<String> {
		final cpu = debugger.machine.cpu;
		final out = new Array<String>();

		for (i in 0...4) {
			out.push(pair("d", i, cpu.d[i]) + "   " + pair("d", i + 4, cpu.d[i + 4])
				+ "   " + pair("a", i, cpu.a[i]) + "   " + pair("a", i + 4, cpu.a[i + 4]));
		}

		out.push("");
		out.push("pc " + hex(debugger.at(), 6) + "   sr " + hex(cpu.getSr(), 4)
			+ "   " + flags(cpu) + "   mask " + cpu.imask + (cpu.s ? "   supervisor" : "   user"));

		final place = debugger.site();
		out.push("");
		out.push(place == null
			? "no Haxe behind this address"
			: haxe.io.Path.withoutDirectory(place.file) + ":" + place.line + "  " + place.name);

		out.push("");
		out.push("cycles " + debugger.machine.cycles + "   frame " + debugger.machine.vdp.frame
			+ "   line " + debugger.machine.vdp.line);

		return out.slice(0, rows);
	}

	static function flags(cpu:hx68k.cpu.m68k.M68000):String {
		return (cpu.xf ? "X" : "x") + (cpu.nf ? "N" : "n") + (cpu.zf ? "Z" : "z")
			+ (cpu.vf ? "V" : "v") + (cpu.cf ? "C" : "c");
	}

	static inline function pair(kind:String, index:Int, value:Int):String {
		return kind + index + " " + hex(value, 8);
	}

	static inline function hex(value:Int, digits:Int):String {
		return StringTools.hex(value, digits);
	}
}

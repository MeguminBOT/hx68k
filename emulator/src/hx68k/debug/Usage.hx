package hx68k.debug;

import hx68k.debug.Row.Kind;
import hx68k.debug.Row.Part;
import hx68k.md.Machine;
import hx68k.md.Vdp;

class Usage implements View {
	static inline final BAR = 24;

	final machine:Machine;
	final viewer:Viewer;

	var lastFrame:Int = -1;
	var lastWrites:Int = 0;
	var lastReads:Int = 0;
	var lastCycles:Int = 0;

	var writesPerFrame:Int = 0;
	var readsPerFrame:Int = 0;
	var cyclesPerFrame:Int = 0;
	var statesPerFrame:Int = 0;
	var lastStates:Int = 0;

	public function new(debugger:Debugger) {
		this.machine = debugger.machine;
		this.viewer = new Viewer(debugger.machine.vdp);
	}

	public function title():String {
		return "usage";
	}

	public function rows(limit:Int):Array<Row> {
		sample();

		final vdp = machine.vdp;
		final out = new Array<Row>();

		out.push(Row.said("memory, counting the bytes that are not zero", Label));
		out.push(memory("work RAM", used(machine.ram), machine.ram.length));
		out.push(memory("z80 RAM", used(machine.z80Ram), machine.z80Ram.length));
		out.push(memory("VRAM", used(vdp.vram), vdp.vram.length));
		out.push(memory("CRAM", set(vdp.cram) * 2, vdp.cram.length * 2));
		out.push(memory("VSRAM", set(vdp.vsram) * 2, vdp.vsram.length * 2));

		out.push(Row.blank());
		out.push(new Row([
			label("cartridge"), value(commas(machine.rom.length) + " bytes"),
			label("of"), value(commas(0x400000)),
			label("used"), value(share(machine.rom.length, 0x400000))
		]));

		out.push(Row.blank());
		out.push(Row.said("the video chip, over the last frame it finished", Label));
		out.push(new Row([
			label("writes"), value(commas(writesPerFrame)),
			label("reads"), value(commas(readsPerFrame))
		]));
		out.push(new Row([
			label("sprites"), value(viewer.spriteList().length + " of " + (viewer.layout().wide ? 80 : 64)),
			label("display"), value(viewer.layout().display ? "on" : "off")
		]));

		out.push(Row.blank());
		out.push(Row.said("the 68000, which never idles and so is always spending all of these", Label));
		out.push(new Row([
			label("cycles a frame"), value(commas(cyclesPerFrame)),
			label("of"), value(commas(perFrame()))
		]));
		out.push(new Row([
			label("interrupts"), value(commas(machine.interrupts)),
			label("frame"), value(commas(vdp.frame))
		]));

		out.push(Row.blank());
		out.push(Row.said("the z80, whose share is what decides how fast a sound driver runs", Label));
		out.push(new Row([
			label("states a frame"), value(commas(statesPerFrame)),
			label("of"), value(commas(Std.int(Vdp.MASTER_PER_LINE * Vdp.LINES_NTSC / 15)))
		]));
		out.push(new Row([
			label("held in reset"), value(commas(machine.stoppedFor)),
			label("bus taken"), value(commas(machine.requestedFor))
		]));

		return out.slice(0, limit);
	}

	function sample():Void {
		final vdp = machine.vdp;
		if (vdp.frame == lastFrame) return;

		if (lastFrame >= 0) {
			writesPerFrame = vdp.writes - lastWrites;
			readsPerFrame = vdp.reads - lastReads;
			cyclesPerFrame = machine.cycles - lastCycles;
			statesPerFrame = machine.z80Bus.states - lastStates;
		}

		lastFrame = vdp.frame;
		lastWrites = vdp.writes;
		lastReads = vdp.reads;
		lastCycles = machine.cycles;
		lastStates = machine.z80Bus.states;
	}

	static inline function perFrame():Int {
		return Std.int(hx68k.md.Vdp.MASTER_PER_LINE * hx68k.md.Vdp.LINES_NTSC / Machine.MASTER_PER_68K);
	}

	function memory(what:String, taken:Int, whole:Int):Row {
		return new Row([
			label(what),
			value(commas(taken)),
			label("of"),
			value(commas(whole)),
			label("left"),
			value(commas(whole - taken)),
			{text: bar(taken, whole), kind: Value},
			value(share(taken, whole))
		]);
	}

	static function bar(taken:Int, whole:Int):String {
		final full = whole == 0 ? 0 : Std.int(BAR * taken / whole);
		var out = "";
		for (i in 0...BAR) out += i < full ? "#" : ".";
		return out;
	}

	static function share(taken:Int, whole:Int):String {
		if (whole == 0) return "";
		return Std.string(Math.round(1000.0 * taken / whole) / 10) + "%";
	}

	static function used(bytes:haxe.io.Bytes):Int {
		var count = 0;
		for (i in 0...bytes.length) if (bytes.get(i) != 0) count++;
		return count;
	}

	static function set(values:haxe.ds.Vector<Int>):Int {
		var count = 0;
		for (i in 0...values.length) if (values[i] != 0) count++;
		return count;
	}

	static function commas(value:Int):String {
		final digits = Std.string(value);
		var out = "";

		for (i in 0...digits.length) {
			if (i > 0 && (digits.length - i) % 3 == 0) out += ",";
			out += digits.charAt(i);
		}

		return out;
	}

	static inline function label(text:String):Part {
		return {text: text, kind: Label};
	}

	static inline function value(text:String):Part {
		return {text: text, kind: Value};
	}
}

package hx68k.debug;

import hx68k.debug.Row.RowKind;
import hx68k.debug.Row.RowPart;

class RegistersView implements View {
	final debugger:Debugger;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
	}

	public function title():String {
		return "registers";
	}

	public function rows(limit:Int):Array<Row> {
		final cpu = debugger.machine.cpu;
		final out = new Array<Row>();

		for (i in 0...4) {
			out.push(new Row([
				name("d" + i), value(cpu.d[i]),
				name("d" + (i + 4)), value(cpu.d[i + 4]),
				name("a" + i), value(cpu.a[i]),
				name("a" + (i + 4)), value(cpu.a[i + 4])
			]));
		}

		out.push(Row.blank());
		out.push(new Row([
			name("pc"), {text: StringTools.hex(debugger.at(), 6), kind: Place},
			name("sr"), value(cpu.getSr(), 4),
			name("flags"), {text: flags(cpu), kind: Value},
			name("mask"), {text: Std.string(cpu.imask), kind: Value}
		]));

		out.push(new Row([
			name("mode"), {text: cpu.s ? "supervisor" : "user", kind: Value},
			name("cycles"), {text: Std.string(debugger.machine.cycles), kind: Value},
			name("frame"), {text: Std.string(debugger.machine.vdp.frame), kind: Value},
			name("line"), {text: Std.string(debugger.machine.vdp.line), kind: Value}
		]));

		final place = debugger.site();
		out.push(Row.blank());
		out.push(Row.said(place == null
			? "no Haxe behind this address"
			: haxe.io.Path.withoutDirectory(place.file) + ":" + place.line + "  " + place.name,
			place == null ? Aside : Here));

		return out.slice(0, limit);
	}

	static function flags(cpu:hx68k.cpu.m68k.M68000):String {
		return (cpu.xf ? "X" : "x") + (cpu.nf ? "N" : "n") + (cpu.zf ? "Z" : "z")
			+ (cpu.vf ? "V" : "v") + (cpu.cf ? "C" : "c");
	}

	static inline function name(text:String):RowPart {
		return {text: text, kind: Label};
	}

	static inline function value(number:Int, digits:Int = 8):RowPart {
		return {text: StringTools.hex(number, digits), kind: Value};
	}
}

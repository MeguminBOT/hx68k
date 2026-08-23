package hx68k.debug;

import hx68k.map.SourceMap;
import hx68k.md.Vdp;

typedef Touch = {
	final line:Int;
	final writes:Int;
	final reads:Int;
	final name:String;
	final place:Null<Place>;
}

typedef Beam = {
	final touches:Array<Touch>;
	final writes:Int;
	final reads:Int;
	final active:Int;
	final blanked:Int;
	final offscreen:Int;
	final lines:Int;
	final instructions:Int;
}

class Raster {
	public final debugger:Debugger;

	final names:Names;

	public function new(debugger:Debugger) {
		this.debugger = debugger;
		this.names = new Names(debugger.map);
	}

	public function frames(count:Int):Beam {
		final machine = debugger.machine;
		final vdp = machine.vdp;
		final target = vdp.frame + count;
		final touches = new Array<Touch>();

		var writes = 0;
		var reads = 0;
		var active = 0;
		var blanked = 0;
		var offscreen = 0;
		var highest = 0;
		var instructions = 0;

		while (vdp.frame != target) {
			final at = debugger.at();
			final line = vdp.line;
			final beforeWrites = vdp.writes;
			final beforeReads = vdp.reads;
			final showing = (vdp.registers[1] & 0x40) != 0;

			machine.step();
			instructions++;

			final wrote = vdp.writes - beforeWrites;
			final read = vdp.reads - beforeReads;
			if (wrote == 0 && read == 0) continue;

			writes += wrote;
			reads += read;
			if (line > highest) highest = line;
			if (!showing) offscreen += wrote;
			else if (line < activeLines(vdp)) active += wrote;
			else blanked += wrote;

			touches.push({
				line: line,
				writes: wrote,
				reads: read,
				name: names.at(at),
				place: debugger.map.resolve(at)
			});
		}

		return {
			touches: touches,
			writes: writes,
			reads: reads,
			active: active,
			blanked: blanked,
			offscreen: offscreen,
			lines: highest + 1,
			instructions: instructions
		};
	}

	public static function perLine(beam:Beam, lines:Int):Array<Int> {
		final out = new Array<Int>();
		for (_ in 0...lines) out.push(0);
		for (touch in beam.touches) if (touch.line < lines) out[touch.line] += touch.writes;
		return out;
	}

	static inline function activeLines(vdp:Vdp):Int {
		return (vdp.registers[1] & 0x08) != 0 ? 240 : 224;
	}
}

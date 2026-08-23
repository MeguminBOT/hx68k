package hx68k.debug;

class Video implements View {
	final viewer:Viewer;

	public function new(debugger:Debugger) {
		this.viewer = new Viewer(debugger.machine.vdp);
	}

	public function title():String {
		return "video";
	}

	public function lines(rows:Int):Array<String> {
		final shape = viewer.layout();
		final out = new Array<String>();

		out.push("display " + (shape.display ? "on" : "off") + "   " + (shape.wide ? "H40" : "H32")
			+ "   " + (shape.tall ? "V30" : "V28") + (shape.effects ? "   shadow and highlight" : "")
			+ "   plane " + shape.columns + "x" + shape.rows);
		out.push("plane A " + hex(shape.planeA) + "   plane B " + hex(shape.planeB)
			+ "   window " + hex(shape.window) + "   sprites " + hex(shape.sprites));
		out.push("");

		final cram = viewer.vdp.cram;
		for (row in 0...4) {
			var line = "palette " + row + "  ";
			for (column in 0...16) line += StringTools.hex(cram[row * 16 + column], 4) + " ";
			out.push(line);
		}

		out.push("");
		var use = "vram    ";
		for (written in viewer.vramUse()) use += written == 0 ? "." : (written >= 0x800 ? "#" : "-");
		out.push(use);

		out.push("");
		final sprites = viewer.spriteList();
		out.push("sprites " + sprites.length + " in the link chain");

		for (sprite in sprites) {
			if (out.length >= rows) break;
			out.push("  " + StringTools.lpad(Std.string(sprite.index), " ", 3)
				+ "  at " + StringTools.lpad(Std.string(sprite.x), " ", 4)
				+ "," + StringTools.lpad(Std.string(sprite.y), " ", 4)
				+ "  " + sprite.width + "x" + sprite.height
				+ "  tile " + StringTools.lpad(Std.string(sprite.tile), " ", 4)
				+ "  palette " + sprite.palette + (sprite.priority ? "  front" : ""));
		}

		return out.slice(0, rows);
	}

	static inline function hex(value:Int):String {
		return "$" + StringTools.hex(value, 4);
	}
}

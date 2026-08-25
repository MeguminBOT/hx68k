package hx68k.debug;

import hx68k.debug.Row.Kind;
import hx68k.debug.Row.Part;

class Video implements View {
	final viewer:Viewer;

	public function new(debugger:Debugger) {
		this.viewer = new Viewer(debugger.machine.vdp);
	}

	public function title():String {
		return "video";
	}

	public function rows(limit:Int):Array<Row> {
		final shape = viewer.layout();
		final out = new Array<Row>();

		out.push(new Row([
			said("display"), value(shape.display ? "on" : "off"),
			said("width"), value(shape.wide ? "H40" : "H32"),
			said("height"), value(shape.tall ? "V30" : "V28"),
			said("plane"), value(shape.columns + "x" + shape.rows)
		]));

		out.push(new Row([
			said("plane A"), place(shape.planeA),
			said("plane B"), place(shape.planeB),
			said("window"), place(shape.window),
			said("sprites"), place(shape.sprites)
		]));

		out.push(Row.blank());

		final cram = viewer.vdp.cram;
		for (row in 0...4) {
			for (half in 0...2) {
				final cells:Array<Part> = [said(half == 0 ? "palette " + row : "")];
				for (column in 0...8) {
					cells.push(value(StringTools.hex(cram[row * 16 + half * 8 + column], 4)));
				}
				out.push(new Row(cells));
			}
		}

		out.push(Row.blank());

		var use = "";
		for (written in viewer.vramUse()) use += written == 0 ? "." : (written >= 0x800 ? "#" : "-");
		out.push(new Row([said("vram"), value(use)]));

		out.push(Row.blank());

		final sprites = viewer.spriteList();
		out.push(Row.said(sprites.length + " sprites in the link chain"));

		for (sprite in sprites) {
			if (out.length >= limit) break;
			out.push(new Row([
				{text: Std.string(sprite.index), kind: Label},
				value(sprite.x + "," + sprite.y),
				value(sprite.width + "x" + sprite.height),
				said("tile"), value(Std.string(sprite.tile)),
				said("palette"), value(Std.string(sprite.palette)),
				{text: sprite.priority ? "front" : "", kind: Aside}
			]));
		}

		return out.slice(0, limit);
	}

	static inline function said(text:String):Part {
		return {text: text, kind: Label};
	}

	static inline function value(text:String):Part {
		return {text: text, kind: Value};
	}

	static inline function place(address:Int):Part {
		return {text: "$" + StringTools.hex(address, 4), kind: Place};
	}
}

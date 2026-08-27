package md;

import md.hw.Vdp as Ports;

class Font {
	public static inline final FIRST = 32;

	public static inline final GLYPHS = 96;

	static var glyph:UInt16 = 0;

	static var writtenTo:Plane = Plane.A;

	static var palette:UInt16 = 0;

	static var raised:Bool = false;

	public static inline function loadNormal(at:UInt16):Bool {
		return load(at, md.res.Fonts.normal);
	}

	public static function load(at:UInt16, from:md.res.TileSet):Bool {
		if (!Patterns.load(at, from)) return false;
		glyph = at;
		return true;
	}

	public static inline function base():UInt16 {
		return glyph;
	}

	public static inline function setBase(at:UInt16):Void {
		glyph = at;
	}

	public static inline function plane():Plane {
		return writtenTo;
	}

	public static inline function setPlane(to:Plane):Void {
		writtenTo = to;
	}

	public static inline function setPalette(which:UInt16):Void {
		palette = which & 3;
	}

	public static inline function setPriority(on:Bool):Void {
		raised = on;
	}

	static inline function room(x:UInt16, width:UInt16):Int {
		final columns:Int = writtenTo == Plane.Window ? Tilemap.windowColumnCount()
			: Tilemap.columns();
		final left:Int = columns - x;
		return width < left ? width : left;
	}

	static inline function offPlane(x:UInt16, y:UInt16):Bool {
		final columns:Int = writtenTo == Plane.Window ? Tilemap.windowColumnCount()
			: Tilemap.columns();
		final rows:Int = writtenTo == Plane.Window ? 32 : Tilemap.rows();
		return x >= columns || y >= rows;
	}

	public static function write(text:String, x:UInt16, y:UInt16):Void {
		if (offPlane(x, y)) return;

		final left:Int = room(x, md.Text.length(text));
		if (left <= 0) return;

		Ports.autoIncrement(2);
		Ports.address(Ports.VRAM_WRITE, Tilemap.address(writtenTo, x, y));

		final attributes:Int = ((palette & 3) << 13) | (raised ? Patterns.PRIORITY : 0);
		var step:Int = 0;

		while (step < left) {
			final code:Int = md.Text.charAt(text, step);
			if (code == 0) break;
			Ports.write(attributes | ((glyph + (code - FIRST)) & Patterns.INDEX));
			step++;
		}
	}

	public static function clear(x:UInt16, y:UInt16, width:UInt16):Void {
		if (offPlane(x, y)) return;

		final count:Int = room(x, width);
		if (count <= 0) return;

		Ports.autoIncrement(2);
		Ports.address(Ports.VRAM_WRITE, Tilemap.address(writtenTo, x, y));

		final blank:Int = ((palette & 3) << 13) | (raised ? Patterns.PRIORITY : 0)
			| (glyph & Patterns.INDEX);

		var step:Int = 0;
		while (step < count) {
			Ports.write(blank);
			step++;
		}
	}

	public static function clearArea(x:UInt16, y:UInt16, width:UInt16, height:UInt16):Void {
		final rows:Int = writtenTo == Plane.Window ? 32 : Tilemap.rows();
		final left:Int = rows - y;
		final tall:Int = height < left ? height : left;

		for (step in 0...tall) clear(x, y + step, width);
	}

	public static inline function clearLine(y:UInt16):Void {
		clear(0, y, writtenTo == Plane.Window ? Tilemap.windowColumnCount() : Tilemap.columns());
	}
}

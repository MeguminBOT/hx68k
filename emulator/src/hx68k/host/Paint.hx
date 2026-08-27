package hx68k.host;

import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Canvas;
import hx68k.host.sdl.Texture;

@:unreflective
class Paint {
	static inline final FLOATS_PER_VERTEX = 8;

	public var font(default, null):Font;

	var renderer:cpp.Star<Canvas>;

	var batch:Array<Single> = new Array<Single>();
	var used:Int = 0;

	var clipped:Bool = false;

	function new() {}

	public static function on(renderer:cpp.Star<Canvas>, font:Font):Paint {
		final paint = new Paint();
		paint.renderer = renderer;
		paint.font = font;
		return paint;
	}

	public function clip(x:Float, y:Float, width:Float, height:Float, windowHeight:Int):Void {
		flush();
		Sdl.setClip(renderer, Std.int(Math.max(0, x)), Std.int(Math.max(0, y)),
			Std.int(Math.max(0, width)), Std.int(Math.max(0, height)));
		clipped = true;
	}

	public function release(windowHeight:Int):Void {
		if (!clipped) return;
		flush();
		Sdl.clearClip(renderer);
		clipped = false;
	}

	public function rectangle(x:Float, y:Float, width:Float, height:Float, colour:Int,
			alpha:Float = 1):Void {
		final u = font.solidU / font.atlasWidth;
		final v = font.solidV / font.atlasHeight;
		quad(x, y, x + width, y + height, u, v, u, v, colour, alpha);
	}

	public function outline(x:Float, y:Float, width:Float, height:Float, colour:Int,
			alpha:Float = 1):Void {
		rectangle(x, y, width, 1, colour, alpha);
		rectangle(x, y + height - 1, width, 1, colour, alpha);
		rectangle(x, y, 1, height, colour, alpha);
		rectangle(x + width - 1, y, 1, height, colour, alpha);
	}

	public function text(value:String, x:Float, y:Float, colour:Int, alpha:Float = 1):Float {
		var pen = x;
		final top = y - font.ascent;
		final bottom = top + font.height;

		for (i in 0...value.length) {
			final code = value.charCodeAt(i);
			if (code < Glyphs.FIRST || code > Glyphs.LAST) continue;

			final u0 = font.cellOf(code) / font.atlasWidth;
			final u1 = (font.cellOf(code) + font.advance) / font.atlasWidth;
			quad(pen, top, pen + font.advance, bottom, u0, 0, u1, font.height / font.atlasHeight,
				colour, alpha);
			pen += font.advance;
		}

		return pen;
	}

	public function pending():Int {
		return used;
	}

	public function flush():Void {
		if (used == 0) return;
		Sdl.renderGeometry(renderer, font.texture, cpp.Pointer.ofArray(batch).raw,
			Std.int(used / FLOATS_PER_VERTEX));
		used = 0;
	}

	function quad(left:Float, top:Float, right:Float, bottom:Float, u0:Float, v0:Float, u1:Float,
			v1:Float, colour:Int, alpha:Float):Void {
		final r = ((colour >> 16) & 0xFF) / 255;
		final g = ((colour >> 8) & 0xFF) / 255;
		final b = (colour & 0xFF) / 255;

		push(left, top, r, g, b, alpha, u0, v0);
		push(right, top, r, g, b, alpha, u1, v0);
		push(left, bottom, r, g, b, alpha, u0, v1);
		push(left, bottom, r, g, b, alpha, u0, v1);
		push(right, top, r, g, b, alpha, u1, v0);
		push(right, bottom, r, g, b, alpha, u1, v1);
	}

	inline function push(x:Float, y:Float, r:Float, g:Float, b:Float, a:Float, u:Float,
			v:Float):Void {
		if (used + FLOATS_PER_VERTEX > batch.length) batch.resize(batch.length + 4096);

		batch[used] = x;
		batch[used + 1] = y;
		batch[used + 2] = r;
		batch[used + 3] = g;
		batch[used + 4] = b;
		batch[used + 5] = a;
		batch[used + 6] = u;
		batch[used + 7] = v;
		used += FLOATS_PER_VERTEX;
	}
}

package hx68k.host.ui;

import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Canvas;
import hx68k.host.sdl.Texture;

@:unreflective
class Font {
	public static inline final LEAST_SCALE = 1;
	public static inline final MOST_SCALE = 3;

	static inline final ASCENT_ROWS = 12;
	static inline final GLYPHS = Glyphs.LAST - Glyphs.FIRST + 1;
	static inline final SOLID_COLUMN = GLYPHS;

	public final scale:Int;
	public final height:Int;
	public final advance:Float;
	public final ascent:Float;

	public final atlasWidth:Float;
	public final atlasHeight:Float;

	public final solidU:Float;
	public final solidV:Float;

	public var texture(default, null):cpp.Star<Texture>;

	function new(scale:Int) {
		this.scale = scale;
		this.height = Glyphs.HEIGHT * scale;
		this.advance = Glyphs.WIDTH * scale;
		this.ascent = ASCENT_ROWS * scale;
		this.atlasWidth = (GLYPHS + 1) * Glyphs.WIDTH * scale;
		this.atlasHeight = Glyphs.HEIGHT * scale;
		this.solidU = (SOLID_COLUMN + 0.5) * Glyphs.WIDTH * scale;
		this.solidV = Glyphs.HEIGHT * scale * 0.5;
	}

	public static inline function held(scale:Int):Int {
		return scale < LEAST_SCALE ? LEAST_SCALE : (scale > MOST_SCALE ? MOST_SCALE : scale);
	}

	public static function on(renderer:cpp.Star<Canvas>, scale:Int = 2):Font {
		final font = new Font(held(scale));
		final cellWidth = Glyphs.WIDTH * font.scale;
		final cellHeight = Glyphs.HEIGHT * font.scale;
		final width = (GLYPHS + 1) * cellWidth;
		final height = cellHeight;

		final pixels = new Array<cpp.UInt8>();
		for (i in 0...width * height * 4) pixels[i] = 0;

		for (code in Glyphs.FIRST...Glyphs.LAST + 1) {
			shelve(pixels, width, code - Glyphs.FIRST, code, font.scale);
		}
		fillSolid(pixels, width, font.scale);

		font.texture = Sdl.createTexture(renderer, width, height);
		Sdl.updateTexture(font.texture, cpp.Pointer.ofArray(pixels).raw, width, height);
		return font;
	}

	public inline function cellOf(code:Int):Float {
		final index = code >= Glyphs.FIRST && code <= Glyphs.LAST ? code - Glyphs.FIRST : 0;
		return index * advance;
	}

	public inline function measure(text:String):Float {
		return text.length * advance;
	}

	static function shelve(pixels:Array<cpp.UInt8>, atlasWidth:Int, column:Int, code:Int,
			scale:Int):Void {
		final rows = Glyphs.of(code);
		final atX = column * Glyphs.WIDTH * scale;

		for (row in 0...Glyphs.HEIGHT) {
			final byte = rows.get(row);
			for (col in 0...Glyphs.WIDTH) {
				final on = (byte & (0x80 >> col)) != 0;
				if (!on) continue;

				for (dy in 0...scale) for (dx in 0...scale) {
					final x = atX + col * scale + dx;
					final y = row * scale + dy;
					paint(pixels, atlasWidth, x, y);
				}
			}
		}
	}

	static function fillSolid(pixels:Array<cpp.UInt8>, atlasWidth:Int, scale:Int):Void {
		final atX = SOLID_COLUMN * Glyphs.WIDTH * scale;
		for (y in 0...Glyphs.HEIGHT * scale) for (x in 0...Glyphs.WIDTH * scale) {
			paint(pixels, atlasWidth, atX + x, y);
		}
	}

	static inline function paint(pixels:Array<cpp.UInt8>, atlasWidth:Int, x:Int, y:Int):Void {
		final at = (y * atlasWidth + x) * 4;
		pixels[at] = 255;
		pixels[at + 1] = 255;
		pixels[at + 2] = 255;
		pixels[at + 3] = 255;
	}
}

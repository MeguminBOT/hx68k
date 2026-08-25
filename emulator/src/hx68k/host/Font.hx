package hx68k.host;

import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Renderer;
import hx68k.host.sdl.Texture;

@:unreflective
class Font {
	static inline final SCALE = 2;
	static inline final CELL_WIDTH = Glyphs.WIDTH * SCALE;
	static inline final CELL_HEIGHT = Glyphs.HEIGHT * SCALE;
	static inline final ASCENT = 12 * SCALE;
	static inline final GLYPHS = Glyphs.LAST - Glyphs.FIRST + 1;
	static inline final SOLID_COLUMN = GLYPHS;

	public final height:Int = CELL_HEIGHT;
	public final advance:Float = CELL_WIDTH;
	public final ascent:Float = ASCENT;

	public final atlasWidth:Float = (GLYPHS + 1) * CELL_WIDTH;
	public final atlasHeight:Float = CELL_HEIGHT;

	public final solidU:Float = SOLID_COLUMN * CELL_WIDTH + CELL_WIDTH * 0.5;
	public final solidV:Float = CELL_HEIGHT * 0.5;

	public var texture(default, null):cpp.Star<Texture>;

	function new() {}

	public static function on(renderer:cpp.Star<Renderer>):Font {
		final font = new Font();
		final width = (GLYPHS + 1) * CELL_WIDTH;
		final height = CELL_HEIGHT;
		final pixels = new Array<cpp.UInt8>();
		for (i in 0...width * height * 4) pixels[i] = 0;

		for (code in Glyphs.FIRST...Glyphs.LAST + 1) shelve(pixels, width, code - Glyphs.FIRST, code);
		fillSolid(pixels, width);

		font.texture = Sdl.createTexture(renderer, width, height);
		Sdl.updateTexture(font.texture, cpp.Pointer.ofArray(pixels).raw, width, height);
		return font;
	}

	public inline function cellOf(code:Int):Float {
		final index = code >= Glyphs.FIRST && code <= Glyphs.LAST ? code - Glyphs.FIRST : 0;
		return index * CELL_WIDTH;
	}

	public inline function measure(text:String):Float {
		return text.length * advance;
	}

	static function shelve(pixels:Array<cpp.UInt8>, atlasWidth:Int, column:Int, code:Int):Void {
		final rows = Glyphs.of(code);
		final atX = column * CELL_WIDTH;

		for (row in 0...Glyphs.HEIGHT) {
			final byte = rows.get(row);
			for (col in 0...Glyphs.WIDTH) {
				final on = (byte & (0x80 >> col)) != 0;
				if (!on) continue;

				for (dy in 0...SCALE) for (dx in 0...SCALE) {
					final x = atX + col * SCALE + dx;
					final y = row * SCALE + dy;
					paint(pixels, atlasWidth, x, y);
				}
			}
		}
	}

	static function fillSolid(pixels:Array<cpp.UInt8>, atlasWidth:Int):Void {
		final atX = SOLID_COLUMN * CELL_WIDTH;
		for (y in 0...CELL_HEIGHT) for (x in 0...CELL_WIDTH) paint(pixels, atlasWidth, atX + x, y);
	}

	static inline function paint(pixels:Array<cpp.UInt8>, atlasWidth:Int, x:Int, y:Int):Void {
		final at = (y * atlasWidth + x) * 4;
		pixels[at] = 255;
		pixels[at + 1] = 255;
		pixels[at + 2] = 255;
		pixels[at + 3] = 255;
	}
}

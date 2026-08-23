package hx68k.host;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLTexture;
import lime.utils.UInt8Array;

typedef Cell = {
	var u:Float;
	var v:Float;
	var width:Float;
	var height:Float;
	var bearingX:Float;
	var bearingY:Float;
	var advance:Float;
}

class Font {
	static inline final FIRST = 32;
	static inline final LAST = 126;
	static inline final SIDE = 512;

	public final height:Int;
	public final advance:Float;
	public final texture:GLTexture;
	public final solid:Cell;

	public var atlasWidth(default, null):Float = SIDE;
	public var atlasHeight(default, null):Float = SIDE;

	final gl:WebGLRenderContext;
	final cells:Map<Int, Cell> = [];

	public function new(gl:WebGLRenderContext, path:String, size:Int) {
		this.gl = gl;

		final font = lime.text.Font.fromFile(path);
		if (font == null) throw "no font at " + path;

		final images:Map<Int, lime.graphics.Image> = [];
		var widest = 0.0;
		var tallest = 0;

		for (code in FIRST...LAST + 1) {
			final glyph = font.getGlyph(String.fromCharCode(code));
			final image = font.renderGlyph(glyph, size);

			final step = font.getGlyphMetrics(glyph).advance.x / 64.0;
			if (step > widest) widest = step;

			if (image != null) {
				images.set(code, image);
				if (image.height > tallest) tallest = image.height;
			}

			cells.set(code, {
				u: 0, v: 0,
				width: image == null ? 0 : image.width,
				height: image == null ? 0 : image.height,
				bearingX: image == null ? 0 : image.x,
				bearingY: image == null ? 0 : image.y,
				advance: step
			});
		}

		this.advance = widest;
		this.height = Std.int(size * 1.35);
		this.solid = {
			u: SIDE - 4, v: SIDE - 4, width: 2, height: 2,
			bearingX: 0, bearingY: 0, advance: 0
		};
		this.texture = shelve(images, tallest);
	}

	public function cellOf(code:Int):Null<Cell> {
		return cells.get(code);
	}

	public function measure(text:String):Float {
		var total = 0.0;
		for (i in 0...text.length) {
			final cell = cells.get(text.charCodeAt(i));
			if (cell != null) total += cell.advance;
		}
		return total;
	}

	function shelve(images:Map<Int, lime.graphics.Image>, tallest:Int):GLTexture {
		final pixels = new UInt8Array(SIDE * SIDE * 4);
		for (i in 0...pixels.length) pixels[i] = 0;

		var penX = 0;
		var penY = 0;

		for (code in FIRST...LAST + 1) {
			final image = images.get(code);
			final cell = cells.get(code);
			if (image == null || cell == null || image.width == 0) continue;

			if (penX + image.width >= SIDE) {
				penX = 0;
				penY += tallest + 1;
			}

			cell.u = penX;
			cell.v = penY;
			blit(pixels, image, penX, penY);
			penX += image.width + 1;
		}

		if (penY + tallest >= SIDE - 8) throw "the glyphs did not fit the atlas at this size";

		for (y in 0...2) {
			for (x in 0...2) {
				final at = ((Std.int(solid.v) + y) * SIDE + Std.int(solid.u) + x) * 4;
				pixels[at] = 0xFF;
				pixels[at + 1] = 0xFF;
				pixels[at + 2] = 0xFF;
				pixels[at + 3] = 0xFF;
			}
		}

		final made = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, made);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, SIDE, SIDE, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels);

		return made;
	}

	function blit(pixels:UInt8Array, image:lime.graphics.Image, atX:Int, atY:Int):Void {
		final data = image.buffer.data;

		for (y in 0...image.height) {
			for (x in 0...image.width) {
				final from = (y * image.width + x) * 4;
				final to = ((atY + y) * SIDE + atX + x) * 4;
				pixels[to] = data[from];
				pixels[to + 1] = data[from + 1];
				pixels[to + 2] = data[from + 2];
				pixels[to + 3] = data[from + 3];
			}
		}
	}
}

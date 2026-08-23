package hx68k.host;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.text.Glyph;
import lime.utils.Float32Array;
import lime.utils.UInt8Array;

private typedef Cell = {
	var u:Float;
	var v:Float;
	final width:Float;
	final height:Float;
	final bearingX:Float;
	final bearingY:Float;
	final advance:Float;
}

class Font {
	static inline final FIRST = 32;
	static inline final LAST = 126;

	static inline final VERTEX = "
		attribute vec2 corner;
		attribute vec2 coord;
		uniform vec2 screen;
		varying vec2 uv;
		void main() {
			uv = coord;
			gl_Position = vec4(corner.x / screen.x * 2.0 - 1.0, 1.0 - corner.y / screen.y * 2.0, 0.0, 1.0);
		}
	";

	static inline final FRAGMENT = "
		varying vec2 uv;
		uniform sampler2D glyphs;
		uniform vec4 tint;
		void main() {
			gl_FragColor = vec4(tint.rgb, tint.a * texture2D(glyphs, uv).a);
		}
	";

	public final height:Int;
	public final advance:Float;

	final gl:WebGLRenderContext;
	final texture:GLTexture;
	final program:GLProgram;
	final vertices:GLBuffer;
	final corner:Int;
	final coord:Int;
	final screen:Int;
	final tint:Int;
	final cells:Map<Int, Cell> = [];

	var batch:Array<Float> = [];
	var atlasWidth:Float = 1;
	var atlasHeight:Float = 1;

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

			final metrics = font.getGlyphMetrics(glyph);
			final step = metrics.advance.x / 64.0;
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

		program = Shader.link(gl, VERTEX, FRAGMENT);
		corner = gl.getAttribLocation(program, "corner");
		coord = gl.getAttribLocation(program, "coord");
		screen = gl.getUniformLocation(program, "screen");
		tint = gl.getUniformLocation(program, "tint");

		vertices = gl.createBuffer();
		texture = shelve(images, tallest);
	}

	public function measure(text:String):Float {
		var total = 0.0;
		for (i in 0...text.length) {
			final cell = cells.get(text.charCodeAt(i));
			if (cell != null) total += cell.advance;
		}
		return total;
	}

	public function write(text:String, x:Float, y:Float):Void {
		var pen = x;

		for (i in 0...text.length) {
			final cell = cells.get(text.charCodeAt(i));
			if (cell == null) continue;

			if (cell.width > 0 && cell.height > 0) {
				final left = pen + cell.bearingX;
				final top = y - cell.bearingY;
				quad(left, top, cell);
			}

			pen += cell.advance;
		}
	}

	public function flush(width:Int, height:Int, colour:Int, alpha:Float = 1):Void {
		if (batch.length == 0) return;

		gl.enable(gl.BLEND);
		gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

		gl.useProgram(program);
		gl.uniform2f(screen, width, height);
		gl.uniform4f(tint, ((colour >> 16) & 0xFF) / 255, ((colour >> 8) & 0xFF) / 255,
			(colour & 0xFF) / 255, alpha);

		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_2D, texture);

		gl.bindBuffer(gl.ARRAY_BUFFER, vertices);
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(batch), gl.DYNAMIC_DRAW);

		gl.enableVertexAttribArray(corner);
		gl.enableVertexAttribArray(coord);
		gl.vertexAttribPointer(corner, 2, gl.FLOAT, false, 16, 0);
		gl.vertexAttribPointer(coord, 2, gl.FLOAT, false, 16, 8);
		gl.drawArrays(gl.TRIANGLES, 0, Std.int(batch.length / 4));

		gl.disableVertexAttribArray(corner);
		gl.disableVertexAttribArray(coord);
		gl.disable(gl.BLEND);

		batch = [];
	}

	function quad(left:Float, top:Float, cell:Cell):Void {
		final right = left + cell.width;
		final bottom = top + cell.height;

		final u0 = cell.u / atlasWidth;
		final v0 = cell.v / atlasHeight;
		final u1 = (cell.u + cell.width) / atlasWidth;
		final v1 = (cell.v + cell.height) / atlasHeight;

		push(left, top, u0, v0);
		push(right, top, u1, v0);
		push(left, bottom, u0, v1);
		push(left, bottom, u0, v1);
		push(right, top, u1, v0);
		push(right, bottom, u1, v1);
	}

	inline function push(x:Float, y:Float, u:Float, v:Float):Void {
		batch.push(x);
		batch.push(y);
		batch.push(u);
		batch.push(v);
	}

	function shelve(images:Map<Int, lime.graphics.Image>, tallest:Int):GLTexture {
		atlasWidth = 512;
		atlasHeight = 512;

		final pixels = new UInt8Array(Std.int(atlasWidth * atlasHeight) * 4);
		for (i in 0...pixels.length) pixels[i] = 0;

		var penX = 0;
		var penY = 0;

		for (code in FIRST...LAST + 1) {
			final image = images.get(code);
			final cell = cells.get(code);
			if (image == null || cell == null || image.width == 0) continue;

			if (penX + image.width >= atlasWidth) {
				penX = 0;
				penY += tallest + 1;
			}

			cell.u = penX;
			cell.v = penY;
			blit(pixels, image, penX, penY);
			penX += image.width + 1;
		}

		if (penY + tallest >= atlasHeight) throw "the glyphs did not fit the atlas at this size";

		final made = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, made);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, Std.int(atlasWidth), Std.int(atlasHeight), 0,
			gl.RGBA, gl.UNSIGNED_BYTE, pixels);

		return made;
	}

	function blit(pixels:UInt8Array, image:lime.graphics.Image, atX:Int, atY:Int):Void {
		final data = image.buffer.data;

		for (y in 0...image.height) {
			for (x in 0...image.width) {
				final from = (y * image.width + x) * 4;
				final to = (Std.int((atY + y) * atlasWidth) + atX + x) * 4;
				pixels[to] = data[from];
				pixels[to + 1] = data[from + 1];
				pixels[to + 2] = data[from + 2];
				pixels[to + 3] = data[from + 3];
			}
		}
	}
}

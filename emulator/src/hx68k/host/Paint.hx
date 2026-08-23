package hx68k.host;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.utils.Float32Array;

class Paint {
	static inline final FLOATS_PER_VERTEX = 8;

	static inline final VERTEX = "
		attribute vec2 corner;
		attribute vec2 coord;
		attribute vec4 shade;
		uniform vec2 screen;
		varying vec2 uv;
		varying vec4 colour;
		void main() {
			uv = coord;
			colour = shade;
			gl_Position = vec4(corner.x / screen.x * 2.0 - 1.0, 1.0 - corner.y / screen.y * 2.0, 0.0, 1.0);
		}
	";

	static inline final FRAGMENT = "
		varying vec2 uv;
		varying vec4 colour;
		uniform sampler2D atlas;
		void main() {
			gl_FragColor = vec4(colour.rgb, colour.a * texture2D(atlas, uv).a);
		}
	";

	public final font:Font;

	final gl:WebGLRenderContext;
	final program:GLProgram;
	final vertices:GLBuffer;
	final corner:Int;
	final coord:Int;
	final shade:Int;
	final screen:Int;

	var batch:Array<Float> = [];

	public function new(gl:WebGLRenderContext, font:Font) {
		this.gl = gl;
		this.font = font;

		program = Shader.link(gl, VERTEX, FRAGMENT);
		corner = gl.getAttribLocation(program, "corner");
		coord = gl.getAttribLocation(program, "coord");
		shade = gl.getAttribLocation(program, "shade");
		screen = gl.getUniformLocation(program, "screen");
		vertices = gl.createBuffer();
	}

	public function rectangle(x:Float, y:Float, width:Float, height:Float, colour:Int,
			alpha:Float = 1):Void {
		final texel = font.solid;
		final u = (texel.u + 0.5) / font.atlasWidth;
		final v = (texel.v + 0.5) / font.atlasHeight;
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

		for (i in 0...value.length) {
			final cell = font.cellOf(value.charCodeAt(i));
			if (cell == null) continue;

			if (cell.width > 0 && cell.height > 0) {
				final left = pen + cell.bearingX;
				final top = y - cell.bearingY;
				quad(left, top, left + cell.width, top + cell.height,
					cell.u / font.atlasWidth, cell.v / font.atlasHeight,
					(cell.u + cell.width) / font.atlasWidth, (cell.v + cell.height) / font.atlasHeight,
					colour, alpha);
			}

			pen += cell.advance;
		}

		return pen;
	}

	public function flush(width:Int, height:Int):Void {
		if (batch.length == 0) return;

		gl.enable(gl.BLEND);
		gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

		gl.useProgram(program);
		gl.uniform2f(screen, width, height);
		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_2D, font.texture);

		gl.bindBuffer(gl.ARRAY_BUFFER, vertices);
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(batch), gl.DYNAMIC_DRAW);

		final stride = FLOATS_PER_VERTEX * 4;
		gl.enableVertexAttribArray(corner);
		gl.enableVertexAttribArray(coord);
		gl.enableVertexAttribArray(shade);
		gl.vertexAttribPointer(corner, 2, gl.FLOAT, false, stride, 0);
		gl.vertexAttribPointer(coord, 2, gl.FLOAT, false, stride, 8);
		gl.vertexAttribPointer(shade, 4, gl.FLOAT, false, stride, 16);
		gl.drawArrays(gl.TRIANGLES, 0, Std.int(batch.length / FLOATS_PER_VERTEX));

		gl.disableVertexAttribArray(corner);
		gl.disableVertexAttribArray(coord);
		gl.disableVertexAttribArray(shade);
		gl.disable(gl.BLEND);

		batch = [];
	}

	function quad(left:Float, top:Float, right:Float, bottom:Float, u0:Float, v0:Float, u1:Float,
			v1:Float, colour:Int, alpha:Float):Void {
		final r = ((colour >> 16) & 0xFF) / 255;
		final g = ((colour >> 8) & 0xFF) / 255;
		final b = (colour & 0xFF) / 255;

		push(left, top, u0, v0, r, g, b, alpha);
		push(right, top, u1, v0, r, g, b, alpha);
		push(left, bottom, u0, v1, r, g, b, alpha);
		push(left, bottom, u0, v1, r, g, b, alpha);
		push(right, top, u1, v0, r, g, b, alpha);
		push(right, bottom, u1, v1, r, g, b, alpha);
	}

	inline function push(x:Float, y:Float, u:Float, v:Float, r:Float, g:Float, b:Float,
			a:Float):Void {
		batch.push(x);
		batch.push(y);
		batch.push(u);
		batch.push(v);
		batch.push(r);
		batch.push(g);
		batch.push(b);
		batch.push(a);
	}
}

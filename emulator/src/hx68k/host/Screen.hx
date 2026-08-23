package hx68k.host;

import hx68k.md.Renderer;
import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.utils.Float32Array;
import lime.utils.UInt8Array;

class Screen {
	static inline final VERTEX = "
		attribute vec2 corner;
		varying vec2 uv;
		void main() {
			uv = corner * vec2(0.5, -0.5) + 0.5;
			gl_Position = vec4(corner, 0.0, 1.0);
		}
	";

	static inline final FRAGMENT = "
		varying vec2 uv;
		uniform sampler2D frame;
		uniform float rows;
		void main() {
			gl_FragColor = texture2D(frame, vec2(uv.x, uv.y * rows));
		}
	";

	final gl:WebGLRenderContext;
	final texture:GLTexture;
	final program:GLProgram;
	final quad:GLBuffer;
	final corner:Int;
	final rows:Int;
	final upload:UInt8Array = new UInt8Array(Renderer.MAX_WIDTH * Renderer.MAX_HEIGHT * 4);

	public function new(gl:WebGLRenderContext) {
		this.gl = gl;

		program = build();
		corner = gl.getAttribLocation(program, "corner");
		rows = gl.getUniformLocation(program, "rows");

		quad = gl.createBuffer();
		gl.bindBuffer(gl.ARRAY_BUFFER, quad);
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
			-1.0, -1.0, 1.0, -1.0, -1.0, 1.0,
			-1.0, 1.0, 1.0, -1.0, 1.0, 1.0
		]), gl.STATIC_DRAW);

		texture = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, Renderer.MAX_WIDTH, Renderer.MAX_HEIGHT, 0,
			gl.RGBA, gl.UNSIGNED_BYTE, null);
	}

	public function draw(renderer:Renderer, width:Int, height:Int):Void {
		fill(renderer);

		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, Renderer.MAX_WIDTH, Renderer.MAX_HEIGHT,
			gl.RGBA, gl.UNSIGNED_BYTE, upload);

		final scale = Std.int(Math.min(width * 3, height * 4));
		final shown = Std.int(scale / 3);
		final tall = Std.int(scale / 4);

		gl.clearColor(0, 0, 0, 1);
		gl.clear(gl.COLOR_BUFFER_BIT);
		gl.viewport(Std.int((width - shown) / 2), Std.int((height - tall) / 2), shown, tall);

		gl.useProgram(program);
		gl.uniform1f(rows, renderer.height / Renderer.MAX_HEIGHT);

		gl.bindBuffer(gl.ARRAY_BUFFER, quad);
		gl.enableVertexAttribArray(corner);
		gl.vertexAttribPointer(corner, 2, gl.FLOAT, false, 0, 0);
		gl.drawArrays(gl.TRIANGLES, 0, 6);
		gl.disableVertexAttribArray(corner);
	}

	function fill(renderer:Renderer):Void {
		final pixels = renderer.pixels;
		var at = 0;

		for (i in 0...Renderer.MAX_WIDTH * Renderer.MAX_HEIGHT) {
			final pixel = pixels[i];
			upload[at++] = (pixel >> 16) & 0xFF;
			upload[at++] = (pixel >> 8) & 0xFF;
			upload[at++] = pixel & 0xFF;
			upload[at++] = 0xFF;
		}
	}

	function build():GLProgram {
		final vertex = compile(gl.VERTEX_SHADER, VERTEX);
		final fragment = compile(gl.FRAGMENT_SHADER, FRAGMENT);
		final linked = gl.createProgram();

		gl.attachShader(linked, vertex);
		gl.attachShader(linked, fragment);
		gl.linkProgram(linked);

		if (gl.getProgramParameter(linked, gl.LINK_STATUS) == 0)
			throw "the framebuffer program did not link: " + gl.getProgramInfoLog(linked);

		return linked;
	}

	function compile(kind:Int, source:String) {
		final shader = gl.createShader(kind);
		gl.shaderSource(shader, source);
		gl.compileShader(shader);

		if (gl.getShaderParameter(shader, gl.COMPILE_STATUS) == 0)
			throw "a framebuffer shader did not compile: " + gl.getShaderInfoLog(shader);

		return shader;
	}
}

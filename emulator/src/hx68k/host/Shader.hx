package hx68k.host;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLShader;

class Shader {
	public static function link(gl:WebGLRenderContext, vertex:String, fragment:String):GLProgram {
		final program = gl.createProgram();

		gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, vertex));
		gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, fragment));
		gl.linkProgram(program);

		if (gl.getProgramParameter(program, gl.LINK_STATUS) == 0)
			throw "a drawing program did not link: " + gl.getProgramInfoLog(program);

		return program;
	}

	static function compile(gl:WebGLRenderContext, kind:Int, source:String):GLShader {
		final shader = gl.createShader(kind);
		gl.shaderSource(shader, source);
		gl.compileShader(shader);

		if (gl.getShaderParameter(shader, gl.COMPILE_STATUS) == 0)
			throw "a shader did not compile: " + gl.getShaderInfoLog(shader);

		return shader;
	}
}

package hx68k.host;

import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Canvas;
import hx68k.host.sdl.Texture;
import hx68k.md.Renderer as MdRenderer;

@:unreflective
class Screen {
	var texture:cpp.Star<Texture>;

	final upload:Array<cpp.UInt8> = new Array<cpp.UInt8>();

	function new() {}

	public static function on(renderer:cpp.Star<Canvas>):Screen {
		final screen = new Screen();
		screen.texture = Sdl.createTexture(renderer, MdRenderer.MAX_WIDTH, MdRenderer.MAX_HEIGHT);
		for (i in 0...MdRenderer.MAX_WIDTH * MdRenderer.MAX_HEIGHT * 4) screen.upload[i] = 0;
		return screen;
	}

	public function draw(sdlRenderer:cpp.Star<Canvas>, renderer:MdRenderer, atX:Int, atY:Int,
			width:Int, height:Int):Void {
		fill(renderer);
		Sdl.updateTexture(texture, cpp.Pointer.ofArray(upload).raw, MdRenderer.MAX_WIDTH, MdRenderer.MAX_HEIGHT);

		final scale = Std.int(Math.min(width * 3, height * 4));
		final shown = Std.int(scale / 3);
		final tall = Std.int(scale / 4);
		final dstX = atX + Std.int((width - shown) / 2);
		final dstY = atY + Std.int((height - tall) / 2);

		Sdl.renderTextureRegion(sdlRenderer, texture, MdRenderer.MAX_WIDTH, renderer.height,
			dstX, dstY, shown, tall);
	}

	function fill(renderer:MdRenderer):Void {
		final pixels = renderer.pixels;
		var at = 0;

		for (i in 0...MdRenderer.MAX_WIDTH * MdRenderer.MAX_HEIGHT) {
			final pixel = pixels[i];
			upload[at++] = (pixel >> 16) & 0xFF;
			upload[at++] = (pixel >> 8) & 0xFF;
			upload[at++] = pixel & 0xFF;
			upload[at++] = 0xFF;
		}
	}
}

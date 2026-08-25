package hx68k.test;

import hx68k.host.Native;
import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Window;
import hx68k.host.sdl.Renderer;
import hx68k.host.sdl.Texture;
import hx68k.host.sdl.HostEvent;

class WindowCheck {
	static function main():Void {
		Native.init();

		if (Sdl.init() == 0) {
			Sys.println("SDL failed to init");
			Sys.exit(1);
		}

		final window = Sdl.createWindow("hx68k window check", 640, 480);
		if (window == null) {
			Sys.println("window failed to open");
			Sys.exit(1);
		}

		final renderer = Sdl.createRenderer(window, 1);
		if (renderer == null) {
			Sys.println("renderer failed to create");
			Sys.exit(1);
		}

		final texture = Sdl.createTexture(renderer, 8, 8);
		final pixels = new Array<cpp.UInt8>();
		for (y in 0...8) for (x in 0...8) {
			final on = ((x + y) & 1) == 0;
			final at = (y * 8 + x) * 4;
			pixels[at] = on ? 255 : 40;
			pixels[at + 1] = on ? 255 : 40;
			pixels[at + 2] = on ? 255 : 40;
			pixels[at + 3] = 255;
		}
		Sdl.updateTexture(texture, cpp.Pointer.ofArray(pixels).raw, 8, 8);

		Sys.println("window open: escape or the close button ends it, resize it if you like");

		var running = true;
		var frames = 0;
		final started = haxe.Timer.stamp();

		while (running && haxe.Timer.stamp() - started < 3) {
			final event = new HostEvent();
			while (Sdl.pollEvent(cpp.Pointer.addressOf(event).raw) != 0) {
				switch (event.type) {
					case Sdl.EVENT_QUIT | Sdl.EVENT_WINDOW_CLOSE:
						running = false;
					case Sdl.EVENT_KEY_DOWN:
						Sys.println("key down: " + event.code);
						if (event.code == 27) running = false;
					case Sdl.EVENT_WINDOW_RESIZED:
						Sys.println("resized to " + event.code + "x" + event.value);
					case _:
				}
			}

			Sdl.renderClear(renderer, 0.05, 0.06, 0.08, 1);
			Sdl.renderTexture(renderer, texture, 40, 40, 256, 256);

			final verts = new Array<Single>();
			final tri = [
				360.0, 60.0, 1, 0.3, 0.3, 1, 0, 0,
				460.0, 260.0, 0.3, 1, 0.3, 1, 0, 0,
				320.0, 260.0, 0.3, 0.3, 1, 1, 0, 0
			];
			for (i in 0...tri.length) verts[i] = tri[i];
			Sdl.renderGeometry(renderer, null, cpp.Pointer.ofArray(verts).raw, 3);

			Sdl.renderPresent(renderer);
			frames++;
		}

		Sys.println("drew " + frames + " frames");

		Sdl.destroyTexture(texture);
		Sdl.destroyRenderer(renderer);
		Sdl.destroyWindow(window);
		Sdl.quit();
	}
}

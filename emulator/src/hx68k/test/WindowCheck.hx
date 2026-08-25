package hx68k.test;

import hx68k.host.Keys;
import hx68k.host.Native;
import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Window;
import hx68k.host.sdl.Renderer;
import hx68k.host.sdl.Texture;
import hx68k.host.sdl.HostEvent;

class WindowCheck {
	static inline final MINIMUM_WIDTH = 640;
	static inline final MINIMUM_HEIGHT = 480;

	static function surface(window:cpp.Star<Window>):Bool {
		final scale:Float = Sdl.windowDisplayScale(window);
		final width = Sdl.windowWidth(window);
		final height = Sdl.windowHeight(window);
		final pixelWidth = Sdl.windowPixelWidth(window);
		final pixelHeight = Sdl.windowPixelHeight(window);

		Sys.println("display scale " + Math.round(scale * 100) / 100
			+ ", logical " + width + "x" + height + ", physical " + pixelWidth + "x" + pixelHeight
			+ ", so the two are " + (width == pixelWidth && height == pixelHeight ? "equal here"
				: "apart, and a resize event carries the logical pair"));

		Sdl.setWindowMinimumSize(window, MINIMUM_WIDTH, MINIMUM_HEIGHT);
		Sdl.setWindowSize(window, 320, 240);

		final heldWidth = Sdl.windowWidth(window);
		final heldHeight = Sdl.windowHeight(window);

		if (heldWidth < MINIMUM_WIDTH || heldHeight < MINIMUM_HEIGHT) {
			Sys.println("the minimum window size is not held: asked for 320x240 under a "
				+ MINIMUM_WIDTH + "x" + MINIMUM_HEIGHT + " minimum and got "
				+ heldWidth + "x" + heldHeight);
			return false;
		}

		Sys.println("minimum window size held: 320x240 was clamped to " + heldWidth + "x" + heldHeight);

		Sdl.setWindowSize(window, 640, 480);
		Sdl.startTextInput(window);
		Sys.println("text input started, so typing prints a text event beside its key event");
		return true;
	}

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

		if (!surface(window)) Sys.exit(1);

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
						Sys.println("key down: " + event.code + " as " + Keys.name(event.code, event.mods));
						if (event.code == 27) running = false;
					case Sdl.EVENT_TEXT:
						Sys.println("text: " + Std.string(Sdl.eventText(cpp.Pointer.addressOf(event).constRaw)));
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

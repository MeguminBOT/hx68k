package hx68k.host;

import hx68k.md.Machine;
import hx68k.md.Vdp;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.Window;

class Console extends Application {
	static inline final PAD_UP = 0x01;
	static inline final PAD_DOWN = 0x02;
	static inline final PAD_LEFT = 0x04;
	static inline final PAD_RIGHT = 0x08;
	static inline final PAD_B = 0x10;
	static inline final PAD_C = 0x20;
	static inline final PAD_A = 0x40;
	static inline final PAD_START = 0x80;

	static inline final CATCH_UP = 4;

	final machine:Machine = new Machine();

	var screen:Null<Screen> = null;
	var font:Null<Font> = null;
	var loaded:Bool = false;
	var paused:Bool = false;
	var frames:Int = 0;
	var since:Float = 0;
	var owed:Float = 0;
	var rate:Int = 0;

	public function new() {
		super();
	}

	override function onWindowCreate():Void {
		final rom = romPath();
		if (rom == null) {
			Sys.println("usage: the window takes a ROM, as `run-window.sh <rom.bin>`");
			return;
		}

		machine.load(rom);
		loaded = true;
		since = haxe.Timer.stamp();

		window.title = "hx68k  " + haxe.io.Path.withoutDirectory(rom);
		Sys.println("running " + rom + ", escape quits and space pauses");
	}

	override function update(deltaTime:Int):Void {
		if (!loaded || paused) return;

		final period = (Vdp.MASTER_PER_LINE * Vdp.LINES_NTSC) / Vdp.MASTER_HZ;
		owed += deltaTime / 1000.0;

		var ran = 0;
		while (owed >= period && ran < CATCH_UP) {
			machine.runFrame();
			owed -= period;
			frames++;
			ran++;
		}

		if (owed >= period * CATCH_UP) owed = 0;

		final now = haxe.Timer.stamp();
		if (now - since >= 1) {
			rate = frames;
			frames = 0;
			since = now;
		}
	}

	override function render(context:RenderContext):Void {
		final gl = context.webgl;
		if (gl == null) return;

		if (screen == null) {
			screen = new Screen(gl);
			font = new Font(gl, monospace(), 15);
		}

		screen.draw(machine.vdp.renderer, window.width, window.height);

		gl.viewport(0, 0, window.width, window.height);
		font.write("hx68k  " + rate + " frames a second", 10, 10 + font.height);
		font.flush(window.width, window.height, 0xE8E8E8);
	}

	static function monospace():String {
		final candidates = [
			"C:/Windows/Fonts/consola.ttf", "C:/Windows/Fonts/lucon.ttf", "C:/Windows/Fonts/cour.ttf",
			"/System/Library/Fonts/Menlo.ttc", "/Library/Fonts/Courier New.ttf",
			"/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
			"/usr/share/fonts/TTF/DejaVuSansMono.ttf"
		];

		for (path in candidates) if (sys.FileSystem.exists(path)) return path;
		throw "no monospace font found in any of: " + candidates.join(", ");
	}

	override function onKeyDown(code:KeyCode, modifier:KeyModifier):Void {
		switch (code) {
			case ESCAPE: window.close();
			case SPACE: paused = !paused;
			case _: press(code, true);
		}
	}

	override function onKeyUp(code:KeyCode, modifier:KeyModifier):Void {
		press(code, false);
	}

	function press(code:KeyCode, held:Bool):Void {
		final button = switch (code) {
			case UP: PAD_UP;
			case DOWN: PAD_DOWN;
			case LEFT: PAD_LEFT;
			case RIGHT: PAD_RIGHT;
			case Z: PAD_A;
			case X: PAD_B;
			case C: PAD_C;
			case RETURN: PAD_START;
			case _: 0;
		}

		if (button == 0) return;
		machine.buttons[0] = held ? machine.buttons[0] | button : machine.buttons[0] & ~button;
	}

	function romPath():Null<String> {
		for (argument in Sys.args()) {
			if (argument.charAt(0) == "-") continue;
			if (sys.FileSystem.exists(argument)) return argument;
		}
		return null;
	}
}

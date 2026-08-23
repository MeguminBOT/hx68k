package hx68k.host;

import hx68k.host.Panel.Dock;
import hx68k.debug.Debugger;
import hx68k.debug.View;
import hx68k.debug.Views;
import hx68k.md.Machine;
import hx68k.md.Vdp;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.MouseButton;

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

	static inline final REBUILD = 0.05;

	final machine:Machine = new Machine();

	var views:Array<View> = [];
	var said:Map<String, Array<String>> = [];

	var screen:Null<Screen> = null;
	var paint:Null<Paint> = null;
	var ui:Null<Ui> = null;

	var loaded:Bool = false;
	var paused:Bool = false;
	var unlimited:Bool = false;

	var frames:Int = 0;
	var rate:Int = 0;
	var since:Float = 0;
	var owed:Float = 0;
	var rebuilt:Float = 0;

	var emulating:Float = 0;
	var drawing:Float = 0;

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

		views = Views.of(new Debugger(machine, null));

		window.title = "hx68k  " + haxe.io.Path.withoutDirectory(rom);
		Sys.println("running " + rom + ", escape quits, space pauses, tab runs it flat out");
	}

	override function update(deltaTime:Int):Void {
		if (!loaded) return;

		final started = haxe.Timer.stamp();

		if (!paused) {
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

			if (unlimited) {
				for (_ in 0...8) {
					machine.runFrame();
					frames++;
				}
			}
		}

		emulating = (haxe.Timer.stamp() - started) * 1000;

		final now = haxe.Timer.stamp();
		if (now - since >= 1) {
			rate = frames;
			frames = 0;
			since = now;
		}
	}

	override function render(context:RenderContext):Void {
		final gl = context.webgl;
		if (gl == null || !loaded) return;

		if (screen == null) {
			screen = new Screen(gl);
			paint = new Paint(gl, new Font(gl, monospace(), 14));
			ui = new Ui(paint);
			arrange();
		}

		final started = haxe.Timer.stamp();
		rebuild();

		gl.clearColor(0.04, 0.05, 0.06, 1);
		gl.clear(gl.COLOR_BUFFER_BIT);

		final left = Std.int(ui.taken(Left));
		final right = Std.int(ui.taken(Right));
		final bottom = Std.int(ui.taken(Bottom));
		screen.draw(machine.vdp.renderer, left, bottom,
			window.width - left - right, window.height - bottom);

		gl.viewport(0, 0, window.width, window.height);
		ui.begin(window.width, window.height);
		panels();
		ui.finish();
		paint.flush(window.width, window.height);

		drawing = (haxe.Timer.stamp() - started) * 1000;
	}

	function arrange():Void {
		var y = 30.0;
		for (view in views) {
			ui.offer(view.title(), view.title(), 30, y, paint.font.advance * 62, 230);
			y += 44;
		}
		ui.offer("options", "options", 30, y, paint.font.advance * 34, 200);
	}

	function rebuild():Void {
		final now = haxe.Timer.stamp();
		if (now - rebuilt < REBUILD) return;
		rebuilt = now;

		for (view in views) said.set(view.title(), view.lines(40));
	}

	function panels():Void {
		for (panel in ui.order()) {
			if (panel.id == "options") {
				options();
				continue;
			}

			if (!ui.panel(panel.id)) continue;
			final lines = said.get(panel.id);
			if (lines == null) continue;

			final room = ui.room();
			for (i in 0...lines.length) {
				if (i >= room) break;
				ui.line(lines[i]);
			}
		}
	}

	function options():Void {
		if (!ui.panel("options")) return;

		paused = ui.toggle("paused", paused);
		unlimited = ui.toggle("run it flat out", unlimited);
		ui.line("");

		for (view in views) {
			final panel = ui.offer(view.title(), view.title(), 0, 0, 0, 0);
			panel.open = ui.toggle(view.title(), panel.open);
		}

		ui.line("");
		ui.line(rate + " frames a second", Ui.DIM);
		ui.line(round(emulating) + " ms emulating", Ui.DIM);
		ui.line(round(drawing) + " ms drawing", Ui.DIM);
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 100) / 100);
	}

	override function onMouseMove(x:Float, y:Float):Void {
		if (ui != null) ui.moved(x, y);
	}

	override function onMouseDown(x:Float, y:Float, button:MouseButton):Void {
		if (ui == null) return;
		ui.moved(x, y);
		ui.button(true);
	}

	override function onMouseUp(x:Float, y:Float, button:MouseButton):Void {
		if (ui == null) return;
		ui.moved(x, y);
		ui.button(false);
	}

	override function onKeyDown(code:KeyCode, modifier:KeyModifier):Void {
		switch (code) {
			case ESCAPE: window.close();
			case SPACE: paused = !paused;
			case TAB: unlimited = !unlimited;
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

	function romPath():Null<String> {
		for (argument in Sys.args()) {
			if (argument.charAt(0) == "-") continue;
			if (sys.FileSystem.exists(argument)) return argument;
		}
		return null;
	}
}

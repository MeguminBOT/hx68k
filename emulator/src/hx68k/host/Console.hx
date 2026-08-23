package hx68k.host;

import hx68k.host.Panel.Dock;
import hx68k.debug.Debugger;
import hx68k.map.Elf;
import hx68k.map.SourceMap;
import hx68k.debug.View;
import hx68k.debug.Views;
import hx68k.md.Machine;
import hx68k.md.Vdp;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
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

	static inline final NOW = 0.0;

	static inline final SCREEN = "screen";

	final machine:Machine = new Machine();

	var views:Array<View> = [];
	var debugger:Null<Debugger> = null;
	var apart:Map<String, Detached> = [];
	var said:Map<String, Array<hx68k.debug.Row>> = [];

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

		since = haxe.Timer.stamp();

		debugger = new Debugger(machine, map());
		views = Views.of(debugger);
		insert(rom);

		window.onRender.add(drawMain);
		window.title = "hx68k  " + haxe.io.Path.withoutDirectory(rom);
		Sys.println("escape quits, space pauses, tab runs it flat out, f10 and f11 step");
		Sys.println(debugger.map == null
			? "no source map given, so the panels name addresses rather than Haxe"
			: "source map loaded, so the panels name the Haxe behind an address");
	}

	function insert(rom:Null<String>):Void {
		if (rom == null || !sys.FileSystem.exists(rom)) {
			window.title = "hx68k  no ROM";
			return;
		}

		machine.reset();
		machine.load(rom);

		loaded = true;
		owed = 0;
		frames = 0;
		rebuilt = 0;

		window.title = "hx68k  " + haxe.io.Path.withoutDirectory(rom);
		Sys.println("running " + rom);
	}

	function choose():Void {
		final dialog = new FileDialog();
		dialog.onSelect.add(path -> insert(path));
		dialog.browse(FileDialogType.OPEN, "bin,md,gen,smd", null, "Open a Mega Drive ROM");
	}

	function map():Null<SourceMap> {
		final given = positional();
		if (given.length < 3) return null;

		try {
			return new SourceMap(new Elf(given[1]), given[2]);
		} catch (e:String) {
			Sys.println("no source map for " + given[1] + ": " + e);
			return null;
		}
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

	override function render(context:RenderContext):Void {}

	function drawMain(context:RenderContext):Void {
		final gl = context.webgl;
		if (gl == null) return;

		if (screen == null) {
			screen = new Screen(gl);
			paint = new Paint(gl, new Font(gl, monospace(), 14));
			ui = new Ui(paint);
			arrange();
		}

		final started = haxe.Timer.stamp();
		if (loaded) rebuild();

		gl.clearColor(0.04, 0.05, 0.06, 1);
		gl.clear(gl.COLOR_BUFFER_BIT);
		gl.viewport(0, 0, window.width, window.height);

		ui.begin(window.width, window.height);
		toolbar();
		panels(gl);
		ui.finish();
		paint.flush(window.width, window.height);

		drawing = (haxe.Timer.stamp() - started) * 1000;
	}

	function arrange():Void {
		final top = ui.reserved + 8;
		final column = Math.max(paint.font.advance * 46, window.width * 0.36);
		final split = window.width - column - 12;

		ui.offer(SCREEN, "screen", 8, top, split - 8, window.height - top - 8);

		final each = (window.height - top - 8) / views.length;
		var y = top;

		for (view in views) {
			ui.offer(view.title(), view.title(), split + 4, y, column, each - 6);
			y += each;
		}
	}

	function rebuild():Void {
		final now = haxe.Timer.stamp();
		if (now - rebuilt < REBUILD) return;
		rebuilt = now;

		for (view in views) said.set(view.title(), view.rows(60));

		for (title in apart.keys()) {
			final window = apart.get(title);
			if (window.closed) {
				apart.remove(title);
				continue;
			}
			window.say(said.get(title));
		}
	}

	function toolbar():Void {
		ui.toolbar();

		if (ui.tool("open a ROM", false)) choose();
		ui.gap(8);

		if (ui.tool(paused ? "running" : "paused", paused)) paused = !paused;
		if (ui.tool("flat out", unlimited)) unlimited = !unlimited;
		ui.gap();

		for (view in views) {
			final panel = ui.offer(view.title(), view.title(), 0, 0, 0, 0);
			if (ui.tool(view.title(), panel.open)) panel.open = !panel.open;
		}

		ui.gap();

		for (view in views) {
			final title = view.title();
			final out = apart.exists(title);
			if (!ui.tool(title + " apart", out)) continue;

			if (out) {
				apart.get(title).shut();
				apart.remove(title);
			} else {
				apart.set(title, new Detached(this, view, monospace()));
			}
		}

		ui.note(rate + " a second     " + round(emulating) + " ms emulating     "
			+ round(drawing) + " ms drawing" + (paused ? "     f10 f11 step" : ""));
	}

	function panels(gl:lime.graphics.WebGLRenderContext):Void {
		for (panel in ui.order()) {
			if (panel.id == SCREEN) {
				picture(gl, panel);
				continue;
			}

			if (!ui.panel(panel.id)) continue;
			final rows = said.get(panel.id);
			if (rows != null) ui.table(rows);
		}
	}

	function picture(gl:lime.graphics.WebGLRenderContext, panel:Panel):Void {
		if (!ui.panel(panel.id)) return;

		if (!loaded) {
			ui.line("no ROM in the machine");
			ui.line("open one from the toolbar", Ui.DIM);
			return;
		}

		final top = panel.y + ui.bar;
		final high = panel.height - ui.bar;

		ui.done();

		screen.draw(machine.vdp.renderer, Std.int(panel.x),
			Std.int(window.height - panel.y - panel.height), Std.int(panel.width), Std.int(high));

		gl.viewport(0, 0, window.width, window.height);
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 100) / 100);
	}

	override function onMouseMove(x:Float, y:Float):Void {
		if (ui != null) ui.moved(x, y);
	}

	override function onMouseWheel(deltaX:Float, deltaY:Float, mode:lime.ui.MouseWheelMode):Void {
		if (ui != null) ui.turn(deltaY);
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
			case F10: step(false);
			case F11: step(true);
			case _: press(code, true);
		}
	}

	function step(wholeLine:Bool):Void {
		if (!paused || debugger == null) return;

		if (wholeLine && debugger.map != null) debugger.stepLine();
		else debugger.step();

		rebuilt = NOW;
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
		final given = positional();
		return given.length == 0 ? null : given[0];
	}

	static function positional():Array<String> {
		final out = [];
		for (argument in Sys.args()) if (argument.charAt(0) != "-") out.push(argument);
		return out;
	}
}

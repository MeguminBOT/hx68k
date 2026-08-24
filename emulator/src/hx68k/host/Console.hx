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

	static inline final BACKLOG = 12;

	static inline final LEAD = 2;

	static inline final REBUILD = 0.1;

	static inline final NOW = 0.0;

	static inline final SCREEN = "screen";

	final machine:Machine = new Machine();

	var views:Array<View> = [];
	var debugger:Null<Debugger> = null;
	var apart:Map<String, Detached> = [];
	var said:Map<String, Array<hx68k.debug.Row>> = [];

	var screen:Null<Screen> = null;
	var speaker:Null<Speaker> = null;
	var paint:Null<Paint> = null;
	var ui:Null<Ui> = null;

	var loaded:Bool = false;
	var paused:Bool = false;
	var unlimited:Bool = false;
	var quiet:Bool = false;

	var frames:Int = 0;
	var since:Float = 0;
	var owed:Float = 0;
	var last:Float = -1;
	var madeLast:Int = 0;
	var perSecond:Int = 0;

	var sixtyEight:Int = 0;
	var eighty:Int = 0;
	var taken:Int = 0;
	var exactly:Float = 0;

	var cyclesLast:Int = 0;
	var statesLast:Int = 0;
	var requestedLast:Int = 0;

	var slowest:Float = 0;
	var worst:Float = 0;

	var gaveUp:Float = 0;
	var behind:Float = 0;
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

	function popOut(title:String):Void {
		final already = apart.get(title);
		if (already != null) {
			already.shut();
			apart.remove(title);
			return;
		}

		for (view in views) {
			if (view.title() != title) continue;
			apart.set(title, new Detached(this, view, monospace()));
			return;
		}
	}

	function insert(rom:Null<String>):Void {
		if (rom == null || !sys.FileSystem.exists(rom)) {
			window.title = "hx68k  no ROM";
			return;
		}

		machine.reset();
		machine.load(rom);

		if (speaker == null) speaker = new Speaker();
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

		final elapsed = last < 0 ? 0.0 : started - last;
		last = started;

		if (quiet && speaker != null && speaker.playing) speaker.silence();

		if (!paused) {
			final period = (Vdp.MASTER_PER_LINE * Vdp.LINES_NTSC) / Vdp.MASTER_HZ;
			owed += elapsed;

			final following = !unlimited && !quiet && speaker != null && speaker.playing;

			var ran = 0;
			while (ran < CATCH_UP) {
				final owing = owed >= period;
				final needed = following && owed > -period * LEAD && machine.sound.short();
				if (!owing && !needed) break;

				machine.runFrame();
				owed -= period;
				frames++;
				ran++;
			}

			if (owed > period * BACKLOG) {
				gaveUp += owed - period * BACKLOG;
				owed = period * BACKLOG;
			}

			if (owed < -period * LEAD) owed = -period * LEAD;

			if (unlimited) {
				for (_ in 0...8) {
					machine.runFrame();
					frames++;
				}
			}
		}

		if (speaker != null && !quiet) speaker.feed(machine.sound);

		emulating = (haxe.Timer.stamp() - started) * 1000;

		final took = (haxe.Timer.stamp() - started) * 1000;
		if (took > slowest) slowest = took;

		final now = haxe.Timer.stamp();
		if (now - since >= 1) {
			frames = 0;
			perSecond = machine.sound.made - madeLast;
			madeLast = machine.sound.made;

			final over = now - since;
			exactly = frames / over;
			sixtyEight = share(machine.cycles - cyclesLast, Vdp.MASTER_HZ / 7, over);
			eighty = share(machine.z80Bus.states - statesLast, Vdp.MASTER_HZ / 15, over);

			taken = share(machine.requestedFor - requestedLast, Vdp.MASTER_HZ, over);

			cyclesLast = machine.cycles;
			statesLast = machine.z80Bus.states;
			requestedLast = machine.requestedFor;

			worst = slowest;
			slowest = 0;
			behind = gaveUp * 1000;
			gaveUp = 0;
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

		for (view in views) {
			final title = view.title();
			if (!ui.showing(title) && !apart.exists(title)) continue;
			said.set(title, view.rows(60));
		}

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
		if (ui.tool(quiet ? "silent" : "sound", !quiet)) quiet = !quiet;
		ui.gap();

		for (view in views) {
			final panel = ui.offer(view.title(), view.title(), 0, 0, 0, 0);
			if (ui.tool(view.title(), panel.open)) panel.open = !panel.open;
		}

		ui.note(round(exactly) + " fps   68k " + sixtyEight + "%   z80 " + eighty + "%"
			+ (taken > 0 ? " + " + taken + "% bus" : "") + "   "
			+ round(emulating) + " + " + round(drawing) + " ms, worst " + round(worst)
			+ (behind >= 1 ? ", gave up " + round(behind) : "") + "   "
			+ sound() + (paused ? "   f10 f11 step" : ""));
	}

	static function share(did:Int, wanted:Float, over:Float):Int {
		return over <= 0 ? 0 : Math.round(100 * (did | 0) / (wanted * over));
	}

	function sound():String {
		if (speaker == null) return "";

		return "sound " + Math.round(100.0 * perSecond / hx68k.md.Sound.RATE) + "%, "
			+ (speaker.delay() + Std.int(1000 * machine.sound.ready() / hx68k.md.Sound.RATE))
			+ " ms" + (speaker.starved > 0 ? ", " + speaker.starved + " dry" : "")
			+ (machine.sound.lost > 0 ? ", " + machine.sound.lost + " lost" : "");
	}

	function panels(gl:lime.graphics.WebGLRenderContext):Void {
		for (panel in ui.order()) {
			if (panel.id == SCREEN) {
				picture(gl, panel);
				continue;
			}

			if (!ui.panel(panel.id)) continue;

			if (panel.wantsApart) {
				panel.wantsApart = false;
				popOut(panel.id);
			}

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

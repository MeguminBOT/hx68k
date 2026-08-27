package hx68k.host;

import hx68k.host.Zone.Side;

import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Window;
import hx68k.host.sdl.Canvas;
import hx68k.host.sdl.Event;
import hx68k.debug.Debugger;
import hx68k.debug.Gdb;
import hx68k.map.Elf;
import hx68k.map.SourceMap;
import hx68k.debug.View;
import hx68k.debug.Views;
import hx68k.debug.Rewind;
import hx68k.host.Focus.Holder;
import hx68k.md.Machine;
import hx68k.md.Savestate;
import hx68k.md.Vdp;

class Workbench {
	static inline final PAD_UP = 0x01;
	static inline final PAD_DOWN = 0x02;
	static inline final PAD_LEFT = 0x04;
	static inline final PAD_RIGHT = 0x08;
	static inline final PAD_B = 0x10;
	static inline final PAD_C = 0x20;
	static inline final PAD_A = 0x40;
	static inline final PAD_START = 0x80;

	static inline final KEY_RETURN = 0x0000000d;
	static inline final KEY_ESCAPE = 0x0000001b;
	static inline final KEY_Z = 0x0000007a;
	static inline final KEY_BACKSPACE = 0x00000008;
	static inline final KEY_DELETE = 0x0000007f;
	static inline final KEY_HOME = 0x4000004a;
	static inline final KEY_END = 0x4000004d;
	static inline final KEY_A = 0x00000061;
	static inline final KEY_RIGHT = 0x4000004f;
	static inline final KEY_LEFT = 0x40000050;
	static inline final KEY_DOWN = 0x40000051;

	static inline final CATCH_UP = 4;

	static inline final BACKLOG = 12;

	static inline final REBUILD = 0.1;

	static inline final NOW = 0.0;

	static inline final SCREEN = "screen";

	static inline final PREFERENCES = "preferences";

	static inline final FILTER = "filter";

	static inline final REWIND_FRAMES = 120;

	static inline final NOTICE = 4.0;

	static inline final LOOK = 1.0;

	static inline final READABLE_COLUMN = 46;

	static inline final MOST_TOOL_ROWS = 4;

	static inline final MINIMUM_WIDTH = 640;
	static inline final MINIMUM_HEIGHT = 480;

	static inline final SPIN = 0.0015;

	static final VALUED = ["--scale", "--measure"];

	static inline final SETTLE = 240;

	final machine:Machine = new Machine();

	var views:Array<View> = [];
	var debugger:Null<Debugger> = null;
	var remote:Null<Gdb> = null;
	var remotePort:Int = 2159;
	var apart:Map<String, Detached> = [];
	var said:Map<String, Array<hx68k.debug.Row>> = [];

	var window:cpp.Star<Window>;
	var renderer:cpp.Star<Canvas>;
	var windowID:Int;
	var width:Int = 960;
	var height:Int = 672;

	var screen:Null<Screen> = null;
	var speaker:Null<Speaker> = null;
	var paint:Null<Paint> = null;
	var ui:Null<Ui> = null;

	var scale:Int = 1;
	var keyed:Int = 0;
	var tapped:Int = 0;
	var handed:Int = -1;
	var padSeen:Bool = false;
	var keyLog:Bool = false;
	var viewportSide:Side = Left;

	var grid:Grid = new Grid();
	var floating:Floating = new Floating();
	var tiled:Bool = true;

	final focus:Focus = new Focus();
	final settings:SettingsFile = new SettingsFile();

	var widgets:Null<Widgets> = null;

	final bindings:Shortcuts = new Shortcuts();
	final preferences:SettingsPage = new SettingsPage();

	var reading:Bool = false;

	var rewind:Null<Rewind> = null;
	var winding:Bool = false;
	var slot:Null<haxe.io.Bytes> = null;
	var watching:Bool = false;
	var keepingState:Bool = false;
	var romStamp:Float = 0;
	var romSettled:Float = 0;
	var lookedAt:Float = 0;
	var notice:String = "";
	var noticeUntil:Float = 0;

	var loaded:Bool = false;
	var paused:Bool = false;
	var unlimited:Bool = false;
	var quiet:Bool = false;
	var running:Bool = true;

	var frames:Int = 0;
	var since:Float = 0;
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

	var emulatingShown:Float = 0;
	var drawingShown:Float = 0;
	var emulatingSum:Float = 0;
	var drawingSum:Float = 0;
	var measured:Int = 0;

	var due:Float = -1;

	public function new() {}

	static function main():Void {
		final console = new Workbench();
		console.run();
	}

	function run():Void {
		Native.init();

		if (Sdl.init() == 0) {
			Sys.println("SDL failed to start");
			Sys.exit(1);
		}

		Clock.fine();

		final rom = romPath();
		remembered();

		window = Sdl.createWindow("hx68k", width, height);
		if (window == null) {
			Sys.println("the window failed to open");
			Sys.exit(1);
		}
		windowID = Sdl.windowID(window);

		renderer = Sdl.createRenderer(window, 0);
		if (renderer == null) {
			Sys.println("the renderer failed to create");
			Sys.exit(1);
		}

		final refresh:Float = Sdl.displayRefresh(window);
		final interval = Sdl.rendererVsync(renderer);
		Sys.println("drawing through " + Std.string(Sdl.rendererName(renderer))
			+ ", swap interval " + interval + ", display " + Math.round(refresh * 100) / 100 + " Hz");
		Sdl.setWindowMinimumSize(window, MINIMUM_WIDTH, MINIMUM_HEIGHT);
		Sys.println("display scale " + Sdl.windowDisplayScale(window)
			+ ", so the window is measured in logical pixels");

		scale = Font.held(asked() > 1 ? asked() : settings.whole("scale", 1));
		final font = Font.on(renderer, scale);
		screen = Screen.on(renderer);
		paint = Paint.on(renderer, font);
		ui = new Ui(paint);
		widgets = new Widgets(ui);
		since = Clock.stamp();

		debugger = new Debugger(machine, map());
		views = Views.of(debugger);
		insert(rom);

		Sys.println("the machine is " + (machine.vdp.pal ? "PAL" : "NTSC") + " and runs at "
			+ Math.round(native() * 100) / 100
			+ " Hz on its own clock, which is neither the display's nor the sound device's");

		arrange();
		rearranged();

		keyLog = flag("--keylog") != null || Sys.args().indexOf("--keylog") >= 0;
		if (keyLog) Sys.println("key log on: every key event prints, with the pad mask it produced");

		final measuring = flag("--measure");
		if (measuring != null) {
			if (loaded) for (_ in 0...SETTLE) machine.runFrame();
			for (spec in measuring.split(",")) report(spec);
			Sdl.destroyRenderer(renderer);
			Sdl.destroyWindow(window);
			Sdl.quit();
			return;
		}

		setTitle(rom);
		Sys.println("escape quits, and every other key is in the preferences window, which "
			+ bindings.chord("preferences") + " opens");
		for (line in keyLines()) Sys.println(line);
		Sys.println(debugger.map == null
			? "no source map given, so the panels name addresses rather than Haxe"
			: "source map loaded, so the panels name the Haxe behind an address");

		while (running) {
			pollEvents();
			Sdl.padOpen();
			pads();
			watch();
			update();
			draw();
			forDetached();
			idle();
		}

		remember();

		if (speaker != null) speaker.stop();
		Sdl.padClose();
		Sdl.destroyRenderer(renderer);
		Sdl.destroyWindow(window);
		Sdl.quit();
	}

	function setTitle(rom:Null<String>):Void {
		Sdl.setWindowTitle(window, "hx68k  " + (rom == null ? "no ROM" : haxe.io.Path.withoutDirectory(rom)));
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
			apart.set(title, new Detached(view));
			return;
		}
	}

	function insert(rom:Null<String>):Void {
		if (rom == null || !sys.FileSystem.exists(rom)) {
			setTitle(null);
			return;
		}

		machine.reset();
		machine.load(rom);

		if (speaker == null) speaker = new Speaker();
		loaded = true;
		due = -1;
		frames = 0;
		rebuilt = 0;

		setTitle(rom);
		romStamp = stampOf(rom);
		romSettled = romStamp;
		Sys.println("running " + rom);
	}

	function choose():Void {
		final path = Sdl.openFileDialog(window, "Mega Drive ROM", "bin;md;gen;smd");
		if (path != null) insert(path);
	}

	function map():Null<SourceMap> {
		final given = positional();
		if (given.length < 3) return null;

		try {
			return new SourceMap(new Elf(given[1]), given[2]);
		} catch (e:haxe.Exception) {
			Sys.println("no source map for " + given[1] + ": " + e.message);
			return null;
		}
	}

	function update():Void {
		if (!loaded) return;

		if (remote != null) {
			remote.attend(0);
			if (remote.ending) serving(false);
		}

		final started = Clock.stamp();

		last = started;

		if (!paused) {
			final period = 1.0 / native();
			if (due < 0) due = started;

			var ran = 0;
			while (ran < CATCH_UP && started >= due) {
				emulate();
				due += period;
				frames++;
				ran++;
			}

			if (started - due > period * BACKLOG) {
				gaveUp += started - due - period * BACKLOG;
				due = started - period * BACKLOG;
			}

			if (unlimited) {
				for (_ in 0...8) {
					emulate();
					frames++;
				}
				due = started;
			}
		}

		if (speaker != null && !quiet) speaker.feed(machine.sound);

		emulating = (Clock.stamp() - started) * 1000;
		if (emulating > slowest) slowest = emulating;

		emulatingSum += emulating;
		drawingSum += drawing;
		measured++;

		final now = Clock.stamp();
		if (now - since >= 1) {
			perSecond = machine.sound.made - madeLast;
			madeLast = machine.sound.made;

			final over = now - since;
			exactly = frames / over;
			frames = 0;
			final hz = machine.vdp.masterHz;
			sixtyEight = share(machine.cycles - cyclesLast, hz / Machine.MASTER_PER_68K, over);
			eighty = share(machine.z80Bus.states - statesLast, hz / Machine.MASTER_PER_Z80, over);

			taken = share(machine.requestedFor - requestedLast, hz, over);

			cyclesLast = machine.cycles;
			statesLast = machine.z80Bus.states;
			requestedLast = machine.requestedFor;

			emulatingShown = measured == 0 ? 0 : emulatingSum / measured;
			drawingShown = measured == 0 ? 0 : drawingSum / measured;
			emulatingSum = 0;
			drawingSum = 0;
			measured = 0;

			worst = slowest;
			slowest = 0;
			behind = gaveUp * 1000;
			gaveUp = 0;
			since = now;
		}
	}

	function native():Float {
		return machine.vdp.masterHz / (Vdp.MASTER_PER_LINE * machine.vdp.lines);
	}

	function emulate():Void {
		if (remote != null && remote.attached) {
			if (!remote.halted) remote.untilFrame();
			return;
		}

		if (rewind != null) rewind.frame() else machine.runFrame();
	}

	function serving(on:Bool):Void {
		if (!on) {
			if (remote != null) remote.close();
			remote = null;
			tell("the gdb remote is off");
			return;
		}

		if (remote != null) return;

		var at = remotePort;

		while (at < remotePort + 16) {
			try {
				remote = new Gdb(new Debugger(machine, map()), at);
				break;
			} catch (e:Dynamic) {
				at++;
			}
		}

		if (remote == null) {
			tell("no free port between " + remotePort + " and " + (remotePort + 15));
			return;
		}

		tell("gdb remote on 127.0.0.1:" + remote.port + ", target remote to reach it");
	}

	function idle():Void {
		if (!loaded || paused || unlimited || due < 0) return;

		final wait = due - Clock.stamp() - SPIN;
		if (wait > 0) Sys.sleep(wait);
		while (Clock.stamp() < due) {}
	}

	function draw():Void {
		if (loaded) rebuild();

		Sdl.renderClear(renderer, 0.04, 0.05, 0.06, 1);

		ui.rows(toolRows());
		ui.begin(width, height);
		toolbar();
		panels();
		ui.overlay();
		sheet();
		ui.finish();

		final started = Clock.stamp();
		Sdl.renderPresent(renderer);
		drawing = (Clock.stamp() - started) * 1000;
	}

	function forDetached():Void {
		for (title in apart.keys()) {
			final window = apart.get(title);
			if (window.closed) {
				apart.remove(title);
				continue;
			}
			window.draw();
		}
	}

	function arrange():Void {
		place(true);

		ui.nest(SCREEN).add(SCREEN);
		for (view in views) ui.nest(view.title()).add(view.title());

		useLayout();
	}

	function sideName():String {
		return switch (viewportSide) {
			case Right: "right";
			case Middle: "centre";
			case _: "left";
		}
	}

	function useLayout():Void {
		grid.anchor(SCREEN, 0.5, viewportSide, 3 / 4);
		ui.arrangeBy(tiled ? cast grid : cast floating);
	}

	function place(seed:Bool):Void {
		final pad = ui.margin;
		final top = ui.reserved + pad;
		final usable = width - pad * 3;

		final wanted = paint.font.advance * READABLE_COLUMN;
		final column = Math.max(0, Math.min(wanted, usable - width * 0.5));

		final screenWide = usable - column;
		final tall = height - top - pad;

		if (viewportSide == Middle) {
			final half = column * 0.5;
			put(SCREEN, "screen", pad + half + pad, top, usable - column, tall, seed);

			final each = tall / Math.max(1, Math.ceil(views.length * 0.5));
			var leftY = top;
			var rightY = top;

			for (i in 0...views.length) {
				final view = views[i];
				final onLeft = (i & 1) == 0;
				final y = onLeft ? leftY : rightY;
				final x = onLeft ? pad : usable + pad - half;

				put(view.title(), view.title(), x, y, half, each - pad * 0.75, seed);
				if (onLeft) leftY += each else rightY += each;
			}
			return;
		}

		final screenAt = viewportSide == Right ? pad + column + pad : pad;
		final columnAt = viewportSide == Right ? pad : pad + screenWide + pad;

		put(SCREEN, "screen", screenAt, top, screenWide, tall, seed);

		final each = tall / views.length;
		var y = top;

		for (view in views) {
			put(view.title(), view.title(), columnAt, y, column, each - pad * 0.75, seed);
			y += each;
		}
	}

	function put(id:String, title:String, x:Float, y:Float, wide:Float, tall:Float,
			seed:Bool):Void {
		final panel = ui.offer(id, title, x, y, wide, tall);
		if (seed) return;

		panel.x = x;
		panel.y = y;
		panel.width = wide;
		panel.height = tall;
		ui.seat(id, x, y, wide, tall);
	}

	function rebuild():Void {
		final now = Clock.stamp();
		if (now - rebuilt < REBUILD) return;
		rebuilt = now;

		for (view in views) {
			final title = view.title();
			final open = ui.visible(title) && ui.showing(title);
			if (!open && !apart.exists(title)) continue;

			final room = open ? ui.rowsFor(title) : 0;
			said.set(title, view.rows(room > BACKLOG ? room : BACKLOG));
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

	function sequence():Array<String> {
		final out = ["open a ROM", "", paused ? "running" : "paused", "flat out",
			quiet ? "silent" : "sound", "rewind", "gdb", "", "1x", "2x", "3x",
			tiled ? "grid" : "floating", "side", PREFERENCES, ""];
		for (view in views) out.push(view.title());
		return out;
	}

	static function fixed(value:Float, wide:Int, places:Int):String {
		final scaled = Math.pow(10, places);
		var text = Std.string(Math.round(value * scaled) / scaled);

		if (places > 0) {
			final dot = text.indexOf(".");
			if (dot < 0) text += ".";
			while (text.length - text.indexOf(".") <= places) text += "0";
		}

		while (text.length < wide) text = " " + text;
		return text;
	}

	function padShown():String {
		final held = machine.buttons[0];
		final names = ["U", "D", "L", "R", "B", "C", "A", "S"];

		var out = "";
		for (i in 0...8) out += (held & (1 << i)) != 0 ? names[i] : ".";
		return out;
	}

	function status():String {
		if (notice != "" && Clock.stamp() > noticeUntil) notice = "";
		if (notice != "") return notice;

		return "pad " + padShown() + "   " + fixed(exactly, 6, 2) + " fps   68k " + fixed(sixtyEight, 3, 0)
			+ "%   z80 " + fixed(eighty, 3, 0) + "% + " + fixed(taken, 2, 0) + "% bus   "
			+ fixed(emulatingShown, 5, 2) + " + " + fixed(drawingShown, 5, 2)
			+ " ms, worst " + fixed(worst, 5, 2)
			+ "   sound " + fixed(perSecond * 100.0 / hx68k.md.Sound.RATE, 3, 0) + "%"
			+ (paused ? "   f10 f11 step" : "");
	}

	function keeping():Float {
		return Math.min(paint.font.measure(status()), width * 0.4);
	}

	function toolRows():Int {
		final want = sequence();
		final keep = keeping();
		final extra = rewind == null ? 0 : 1;

		for (rows in 1...MOST_TOOL_ROWS + 1) if (ui.fits(want, rows, keep, width)) return rows + extra;
		return MOST_TOOL_ROWS + extra;
	}

	function toolbar():Void {
		ui.toolbar();
		ui.keeping(keeping());

		if (ui.tool("open a ROM", false)) choose();
		ui.gap();

		if (ui.tool(paused ? "running" : "paused", paused)) paused = !paused;
		if (ui.tool("flat out", unlimited)) unlimited = !unlimited;
		if (ui.tool(quiet ? "silent" : "sound", !quiet)) quiet = !quiet;
		if (ui.tool("rewind", winding)) winds(!winding);
		if (ui.tool("gdb", remote != null)) serving(remote == null);
		ui.gap();

		var wanted = scale;
		if (ui.tool("1x", scale == 1)) wanted = 1;
		if (ui.tool("2x", scale == 2)) wanted = 2;
		if (ui.tool("3x", scale == 3)) wanted = 3;

		if (ui.tool(tiled ? "grid" : "floating", true)) {
			tiled = !tiled;
			useLayout();
		}

		if (ui.tool(sideName(), viewportSide != Left)) {
			viewportSide = viewportSide == Left ? Middle : (viewportSide == Middle ? Right : Left);
			place(false);
			useLayout();
		}

		if (ui.tool(PREFERENCES, focus.has(PREFERENCES))) {
			if (focus.has(PREFERENCES)) dismiss(PREFERENCES) else take(Holder.Modal, PREFERENCES);
		}
		ui.gap();

		for (view in views) {
			final title = view.title();
			final shown = ui.visible(title);
			if (ui.tool(title, shown)) {
				if (shown) ui.conceal(title) else ui.reveal(title);
			}
		}

		ui.note(status());
		scrubbing();

		if (wanted != scale) rescale(wanted);
	}

	function sheet():Void {
		if (!focus.has(PREFERENCES)) return;

		ui.done();

		preferences.bindings = bindings;
		preferences.scale = scale;
		preferences.viewport = viewportSide;
		preferences.tiled = tiled;
		preferences.sound = !quiet;
		preferences.rewind = winding;
		preferences.watching = watching;
		preferences.keeping = keepingState;
		preferences.romName = romPath() == null ? "" : haxe.io.Path.withoutDirectory(romPath());

		preferences.titles = [for (view in views) view.title()];
		preferences.open = [for (view in views) ui.visible(view.title())];

		final away = ui.clicking() && !focus.capturing();
		preferences.draw(widgets, ui, focus, width, height);

		if (preferences.shut) {
			dismiss(PREFERENCES);
			return;
		}

		if (preferences.scale != scale) rescale(preferences.scale);

		if (preferences.viewport != viewportSide) {
			viewportSide = preferences.viewport;
			place(false);
			useLayout();
		}

		if (preferences.tiled != tiled) {
			tiled = preferences.tiled;
			useLayout();
		}

		quiet = !preferences.sound;
		if (preferences.rewind != winding) winds(preferences.rewind);

		keepingState = preferences.keeping;
		if (preferences.watching != watching) {
			watching = preferences.watching;
			romStamp = watching && romPath() != null ? stampOf(romPath()) : 0;
			romSettled = romStamp;
		}

		if (preferences.reload) {
			reload();
			return;
		}

		if (preferences.reset) {
			place(true);
			useLayout();
			tell("the arrangement was started again");
		}

		if (preferences.toggled >= 0) {
			final title = preferences.titles[preferences.toggled];
			if (ui.visible(title)) ui.conceal(title) else ui.reveal(title);
		}

		if (preferences.restore) {
			bindings.reset();
			preferences.clash = "";
			tell("every key is back to what it was");
		}

		if (preferences.capture != "") {
			take(Holder.Capture, preferences.capture);
			return;
		}

		if (preferences.tookField) take(Holder.Field, FILTER);
		else if (away && focus.on(FILTER)) escaped();
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

	function panels():Void {
		for (panel in ui.order()) {
			if (panel.id == SCREEN) {
				picture(panel);
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

	function picture(panel:Panel):Void {
		if (!ui.panel(panel.id)) return;

		if (!loaded) {
			ui.line("no ROM in the machine");
			ui.line("open one from the toolbar", Ui.DIM);
			return;
		}

		final top = panel.y + ui.bar;
		final high = panel.height - ui.bar;

		ui.done();

		screen.draw(renderer, machine.vdp.renderer, Std.int(panel.x), Std.int(top),
			Std.int(panel.width), Std.int(high));
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 100) / 100);
	}

	function pollEvents():Void {
		final event = new Event();

		while (Sdl.pollEvent(cpp.Pointer.addressOf(event).raw) != 0) {
			if (event.windowID != windowID && event.windowID != 0) {
				forwardToDetached(event);
				continue;
			}

			switch (event.type) {
				case Sdl.EVENT_QUIT | Sdl.EVENT_WINDOW_CLOSE:
					running = false;
				case Sdl.EVENT_KEY_DOWN:
					onKeyDown(event.code, event.value != 0, event.mods);
				case Sdl.EVENT_KEY_UP:
					press(event.code, false);
				case Sdl.EVENT_TEXT:
					if (focus.top() == Holder.Field) {
						preferences.field().insert(
							Std.string(Sdl.eventText(cpp.Pointer.addressOf(event).constRaw)));
					}
				case Sdl.EVENT_MOUSE_MOVE:
					if (ui != null) ui.moved(event.x, event.y);
				case Sdl.EVENT_MOUSE_DOWN:
					if (ui != null) {
						ui.moved(event.x, event.y);
						ui.button(true);
					}
				case Sdl.EVENT_MOUSE_UP:
					if (ui != null) {
						ui.moved(event.x, event.y);
						ui.button(false);
					}
				case Sdl.EVENT_MOUSE_WHEEL:
					if (ui != null) ui.turn(event.y);
				case Sdl.EVENT_WINDOW_RESIZED:
					width = event.code;
					height = event.value;
				case _:
			}
		}
	}

	function forwardToDetached(event:Event):Void {
		for (title in apart.keys()) {
			final window = apart.get(title);
			if (window.id != event.windowID) continue;

			if (event.type == Sdl.EVENT_QUIT || event.type == Sdl.EVENT_WINDOW_CLOSE) window.shut();
			return;
		}
	}

	function onKeyDown(code:Int, again:Bool, mods:Int):Void {
		switch (focus.top()) {
			case Holder.Capture: captured(code, again, mods);
			case Holder.Field: typed(code, mods);
			case Holder.Modal: if (!again && code == KEY_ESCAPE) escaped();
			case _: commanded(code, again, mods);
		}
	}

	function commanded(code:Int, again:Bool, mods:Int):Void {
		if (again) {
			press(code, true);
			return;
		}

		if (code == KEY_ESCAPE) {
			escaped();
			return;
		}

		switch (bindings.commandFor(code, mods)) {
			case "pause": paused = !paused;
			case "flat out": unlimited = !unlimited;
			case "step an instruction": step(false);
			case "step a line": step(true);
			case "keep a state": keep();
			case "restore a state": restore();
			case "back a frame": back();
			case "preferences":
				if (focus.has(PREFERENCES)) dismiss(PREFERENCES) else take(Holder.Modal, PREFERENCES);
			case _: press(code, true);
		}
	}

	function captured(code:Int, again:Bool, mods:Int):Void {
		if (again || Keys.modifier(code)) return;
		if (code == KEY_ESCAPE) {
			preferences.clash = "";
			escaped();
			return;
		}

		final action = focus.holding();
		final chord = Keys.name(code, mods);
		if (chord == "") return;

		final taken = bindings.clash(action, chord);
		if (taken != "") {
			preferences.clash = taken;
			return;
		}

		preferences.clash = "";
		bindings.bind(action, chord);
		escaped();
	}

	function typed(code:Int, mods:Int):Void {
		final selecting = mods & Keys.MOD_SHIFT != 0;
		final byWord = mods & Keys.MOD_CTRL != 0;

		switch (code) {
			case KEY_ESCAPE: escaped();
			case KEY_RETURN:
				preferences.field().commit();
				escaped();
			case KEY_BACKSPACE: preferences.field().backspace();
			case KEY_DELETE: preferences.field().erase();
			case KEY_LEFT: preferences.field().left(selecting, byWord);
			case KEY_RIGHT: preferences.field().right(selecting, byWord);
			case KEY_HOME: preferences.field().home(selecting);
			case KEY_END: preferences.field().end(selecting);
			case KEY_A: if (byWord) preferences.field().all();
			case _:
		}
	}

	function take(kind:Holder, name:String):Void {
		focus.take(kind, name);
		settle();
	}

	function escaped():Void {
		switch (focus.escape()) {
			case Holder.Field: preferences.field().revert();
			case Holder.Application: running = false;
			case _:
		}
		settle();
	}

	function dismiss(name:String):Void {
		while (focus.has(name)) focus.escape();
		settle();
	}

	function settle():Void {
		final wants = focus.typing();
		if (wants != reading) {
			reading = wants;
			if (wants) {
				keyed = 0;
				tapped = 0;
				Sdl.startTextInput(window);
			} else {
				Sdl.stopTextInput(window);
			}
		}

		if (ui != null) ui.sealed = focus.has(PREFERENCES);
		preferences.capturing = focus.capturing() ? focus.holding() : "";
	}

	function stampOf(path:String):Float {
		try {
			return sys.FileSystem.stat(path).mtime.getTime();
		} catch (e:haxe.Exception) {
			return 0;
		}
	}

	function watch():Void {
		if (!watching || !loaded) return;

		final now = Clock.stamp();
		if (now - lookedAt < LOOK) return;
		lookedAt = now;

		final rom = romPath();
		if (rom == null) return;

		final stamp = stampOf(rom);
		if (stamp == 0 || stamp == romStamp) return;

		if (stamp != romSettled) {
			romSettled = stamp;
			return;
		}

		reload();
	}

	function reload():Void {
		final rom = romPath();
		if (rom == null || !sys.FileSystem.exists(rom)) {
			tell("there is no ROM to load again");
			return;
		}

		final kept = keepingState ? slot : null;

		insert(rom);
		romStamp = stampOf(rom);
		romSettled = romStamp;

		debugger = new Debugger(machine, map());
		views = Views.of(debugger);
		said = [];
		if (rewind != null) rewind = new Rewind(machine, REWIND_FRAMES);

		if (kept == null) {
			tell("loaded " + haxe.io.Path.withoutDirectory(rom) + " again");
			return;
		}

		try {
			Savestate.into(machine, kept);
			tell("loaded it again and put the kept state back");
		} catch (e:haxe.Exception) {
			tell("loaded it again, but the kept state does not fit it: " + e.message);
		}
	}

	function tell(what:String):Void {
		notice = what;
		noticeUntil = Clock.stamp() + NOTICE;
	}

	function statePath():Null<String> {
		final rom = romPath();
		return rom == null ? null : rom + ".state";
	}

	function keep():Void {
		if (!loaded) return;

		slot = Savestate.of(machine);
		tell("state kept, " + Math.round(slot.length / 1024) + " KB");

		final path = statePath();
		if (path == null) return;

		try {
			sys.io.File.saveBytes(path, slot);
			tell(notice + ", written beside the ROM");
		} catch (e:haxe.Exception) {
			tell("the state could not be written: " + e.message);
		}
	}

	function restore():Void {
		if (!loaded) return;

		var bytes = slot;
		final path = statePath();

		if (bytes == null && path != null && sys.FileSystem.exists(path)) {
			bytes = sys.io.File.getBytes(path);
		}

		if (bytes == null) {
			tell("no state to go back to");
			return;
		}

		try {
			Savestate.into(machine, bytes);
			slot = bytes;
			tell("state restored");
			if (rewind != null) rewind = new Rewind(machine, REWIND_FRAMES);
		} catch (e:haxe.Exception) {
			tell("that state does not fit this machine: " + e.message);
		}
	}

	function back():Void {
		if (rewind == null) {
			tell("rewind is off, so there is nothing behind this frame");
			return;
		}

		if (!rewind.back(1)) {
			tell("there is nothing kept behind this frame");
			return;
		}

		paused = true;
		tell("back one frame, " + rewind.behind() + " behind it");
	}

	function scrubbing():Void {
		if (rewind == null) return;

		final span = rewind.depth;
		final picked = ui.timeline(span, span - 1 - rewind.at, timeShown());
		if (picked < 0) return;

		final wanted = span - 1 - picked;
		if (wanted == rewind.at) return;

		rewind.seek(wanted);
		paused = true;
	}

	function timeShown():String {
		if (rewind.depth == 0) return "nothing kept yet";
		if (rewind.at == 0) return "now, " + rewind.behind() + " frames behind it";
		return "-" + rewind.at + " frames, " + rewind.behind() + " behind";
	}

	function winds(on:Bool):Void {
		winding = on;
		rewind = on ? new Rewind(machine, REWIND_FRAMES) : null;
		tell(on ? "rewind on, keeping " + REWIND_FRAMES + " frames" : "rewind off");
	}

	function step(wholeLine:Bool):Void {
		if (!paused || debugger == null) return;

		if (wholeLine && debugger.map != null) debugger.stepLine();
		else debugger.step();

		rebuilt = NOW;
	}

	function press(code:Int, held:Bool):Void {
		if (focus.typing()) return;

		final button = bindings.buttonMask(code);
		if (button == 0) return;

		keyed = held ? keyed | button : keyed & ~button;
		if (held) tapped |= button;

		if (keyLog) {
			Sys.println("key " + StringTools.hex(code, 8) + (held ? " down" : " up  ")
				+ "  pad now " + StringTools.hex(keyed, 2));
		}
	}

	function pads():Void {
		final gamepad = Sdl.padState();
		if (gamepad != 0 && !padSeen) {
			padSeen = true;
			Sys.println("a gamepad is answering, so the pad is no longer limited by keyboard rollover");
		}

		final now = keyed | tapped | gamepad;
		tapped = 0;
		machine.buttons[0] = now;

		if (keyLog && now != handed) {
			Sys.println("machine sees " + StringTools.hex(now, 2) + "  " + padShown());
			handed = now;
		}
	}

	function flag(name:String):Null<String> {
		final args = Sys.args();
		for (i in 0...args.length) {
			if (args[i] == name && i + 1 < args.length) return args[i + 1];
		}
		return null;
	}

	function pass():Void {
		ui.rows(toolRows());
		ui.begin(width, height);
		toolbar();
		rebuilt = Clock.stamp() - REBUILD * 2;
		rebuild();
		panels();
		ui.overlay();
		sheet();
		ui.finish();
	}

	function padCheck():Void {
		keyed = 0;

		onKeyDown(KEY_RIGHT, false, 0);
		pads();
		final one = machine.buttons[0];

		onKeyDown(KEY_Z, false, 0);
		pads();
		final two = machine.buttons[0];

		onKeyDown(KEY_DOWN, false, 0);
		pads();
		final three = machine.buttons[0];

		press(KEY_Z, false);
		pads();
		final back = machine.buttons[0];

		Sys.println("    pad state: right " + one + ", +A " + two + ", +down " + three
			+ ", A released " + back
			+ (two == (PAD_RIGHT | PAD_A) && three == (PAD_RIGHT | PAD_A | PAD_DOWN)
				&& back == (PAD_RIGHT | PAD_DOWN) ? "  holds together" : "  ONLY ONE AT A TIME"));

		keyed = 0;
		machine.writeByte(0xA10009, 0x40);

		final names = ["up", "down", "left", "right", "B", "C", "A", "start"];
		final combos = [
			[PAD_LEFT, PAD_DOWN], [PAD_RIGHT, PAD_DOWN], [PAD_LEFT, PAD_UP],
			[PAD_RIGHT, PAD_UP], [PAD_LEFT, PAD_B], [PAD_LEFT, PAD_DOWN, PAD_B],
			[PAD_RIGHT, PAD_DOWN, PAD_B]
		];

		for (combo in combos) {
			var want = 0;
			var said = "";
			for (bit in combo) {
				want |= bit;
				for (i in 0...8) if (bit == 1 << i) said += (said == "" ? "" : "+") + names[i];
			}

			machine.buttons[0] = want;

			machine.writeByte(0xA10003, 0x40);
			final high = machine.read(0xA10002, 0, false, true) & 0x7F;
			machine.writeByte(0xA10003, 0x00);
			final low = machine.read(0xA10002, 0, false, true) & 0x7F;

			var saw = 0;
			if (high & 0x01 == 0) saw |= PAD_UP;
			if (high & 0x02 == 0) saw |= PAD_DOWN;
			if (high & 0x04 == 0) saw |= PAD_LEFT;
			if (high & 0x08 == 0) saw |= PAD_RIGHT;
			if (high & 0x10 == 0) saw |= PAD_B;
			if (high & 0x20 == 0) saw |= PAD_C;
			if (low & 0x10 == 0) saw |= PAD_A;
			if (low & 0x20 == 0) saw |= PAD_START;

			Sys.println("    pad " + StringTools.rpad(said, " ", 18)
				+ " wanted " + StringTools.hex(want, 2) + " saw " + StringTools.hex(saw, 2)
				+ (saw == want ? "  ok" : "  WRONG"));
		}

		machine.buttons[0] = 0;
	}

	function dragCheck():Void {
		final held = ui.offer("video", "video", 0, 0, 0, 0);
		final onto = ui.offer("registers", "registers", 0, 0, 0, 0);

		ui.moved(held.x + held.width * 0.5, held.y + ui.bar * 0.5);
		ui.button(true);
		pass();

		ui.moved(onto.x + onto.width * 0.5, onto.y + onto.height * 0.5);
		pass();

		final left = paint.pending();

		ui.button(false);
		pass();

		Sys.println("    drag overlay: " + (left == 0
			? "every frame fully drawn"
			: "UNFLUSHED, " + left + " floats land a frame late and behind the panels"));
	}

	function scrollCheck():Void {
		for (view in views) {
			final title = view.title();
			if (!ui.scrollsDown(title)) continue;

			final panel = ui.offer(title, title, 0, 0, 0, 0);
			final limit = ui.contentOf(title) - ui.roomOf(title);

			panel.scroll = 0;
			ui.moved(panel.x + panel.width * 0.5, panel.y + ui.bar + 4);
			for (_ in 0...60) {
				ui.turn(-1);
				pass();
			}
			final byWheel = panel.scroll;

			panel.scroll = 0;
			final trackX = panel.x + panel.width - ui.scrollThickness() * 0.5 - 1;

			ui.moved(trackX, panel.y + ui.bar + (panel.height - ui.bar) * 0.5);
			ui.button(true);
			pass();

			ui.moved(trackX, panel.y + panel.height * 2);
			pass();
			final byThumb = panel.scroll;

			ui.button(false);
			pass();

			Sys.println("    " + title + " scroll: wheel to end " + Math.round(byWheel)
				+ ", thumb to end " + Math.round(byThumb) + ", limit " + Math.round(limit)
				+ (Math.abs(byWheel - byThumb) <= 1 && Math.abs(byWheel - limit) <= 1
					? "  agree" : "  DISAGREE"));

			panel.scroll = 0;
			return;
		}
	}

	function shared(rows:Array<hx68k.debug.Row>):Float {
		final widths = new Array<Float>();

		for (row in rows) {
			if (row.apart) continue;
			for (column in 0...row.parts.length) {
				final wide = paint.font.measure(row.parts[column].text);
				if (column >= widths.length) widths.push(wide);
				else if (wide > widths[column]) widths[column] = wide;
			}
		}

		var total = 0.0;
		for (wide in widths) total += wide + ui.columnGapOf();
		return Math.max(0, total - ui.columnGapOf());
	}

	function report(spec:String):Void {
		final at = spec.indexOf("x");
		final wide = Std.parseInt(spec.substr(0, at));
		final high = Std.parseInt(spec.substr(at + 1));
		if (wide == null || high == null) return;

		width = wide;
		height = high;

		ui.regroup();
		ui.rows(toolRows());
		ui.begin(width, height);
		place(false);
		pass();

		final viewport = ui.offer(SCREEN, "screen", 0, 0, 0, 0);
		var rows = 0;
		var least = -1.0;

		for (view in views) {
			final panel = ui.offer(view.title(), view.title(), 0, 0, 0, 0);
			rows += ui.rowsFor(view.title());
			final body = panel.height - ui.bar;
			if (least < 0 || body < least) least = body;
		}

		Sys.println(spec + " scale " + scale
			+ ": viewport " + sideName() + " at " + Math.round(viewport.x)
			+ ", " + Math.round(100 * viewport.width / width) + "% of width"
			+ ", " + rows + " rows of view content"
			+ ", smallest body " + Math.round(least) + " px"
			+ " (" + Std.int(least / paint.font.height) + " rows)"
			+ ", toolbar " + toolRows() + " row(s)"
			+ (ui.overflowing() ? ", CONTROLS DROPPED" : ", every control drawn"));

		final body = viewport.height - ui.bar;
		final fit = Math.min(viewport.width * 3, body * 4);
		final shownWide = fit / 3;
		final shownTall = fit / 4;

		Sys.println("    screen: panel " + Math.round(viewport.width) + "x" + Math.round(body)
			+ ", picture " + Math.round(shownWide) + "x" + Math.round(shownTall)
			+ ", letterbox " + Math.round(body - shownTall) + " px tall, "
			+ Math.round(100 - 100 * shownWide * shownTall / (viewport.width * body)) + "% of it dark");

		for (view in views) {
			final title = view.title();
			final rowsGiven = said.exists(title) ? said.get(title).length : 0;

			final panel = ui.offer(title, title, 0, 0, 0, 0);
			final across = ui.reachOf(title);
			final fits = panel.width - ui.margin * 2;

			final was = said.exists(title) ? shared(said.get(title)) : 0;


			Sys.println("    " + title + ": " + rowsGiven + " rows, widest line "
				+ Math.round(across) + " px (one shared column set gave " + Math.round(was) + ")"
				+ " in " + Math.round(fits) + " px"
				+ (across > fits + 1 ? "  CUT BY " + Math.round(across - fits) : "  fits"));
		}

		scrollCheck();
		dragCheck();
		padCheck();
	}

	function remembered():Void {
		if (!settings.read(SettingsFile.path())) {
			if (settings.problem != "") Sys.println(settings.problem);
			return;
		}

		if (settings.problem != "") Sys.println(settings.problem);
		Sys.println("settings read from " + SettingsFile.path());

		final wide = settings.whole("window.width", width);
		final high = settings.whole("window.height", height);
		if (wide >= MINIMUM_WIDTH) width = wide;
		if (high >= MINIMUM_HEIGHT) height = high;

		viewportSide = switch (settings.text("viewport", "left")) {
			case "right": Right;
			case "centre": Middle;
			case _: Left;
		}
		tiled = settings.text("arrangement", "grid") != "floating";
		quiet = !settings.flag("sound", true);
		watching = settings.flag("watch", false);
		keepingState = settings.flag("keep", false);
		bindings.read(settings);
	}

	function rearranged():Void {
		if (settings.flag("rewind", false)) winds(true);
		remotePort = settings.whole("gdb.port", 2159);
		if (settings.flag("gdb", false)) serving(true);

		final open = settings.text("panels", "");
		if (open != "") {
			final wanted = open.split(",");
			for (view in views) {
				final title = view.title();
				if (wanted.indexOf(title) >= 0) ui.reveal(title) else ui.conceal(title);
			}
		}

		Group.restore(ui.groups(), settings.text("groups", ""));

		final tree = settings.text(tiled ? "layout.grid" : "layout.floating", "");
		if (tree != "") {
			if (tiled) grid.load(tree, ui.groups()) else floating.load(tree, ui.groups());
		}

		useLayout();
	}

	function remember():Void {
		settings.setWhole("window.width", Std.int(width));
		settings.setWhole("window.height", Std.int(height));
		settings.setWhole("scale", scale);
		settings.set("viewport", sideName());
		settings.set("arrangement", tiled ? "grid" : "floating");
		settings.setFlag("sound", !quiet);
		settings.setFlag("rewind", winding);
		settings.setFlag("gdb", remote != null);
		settings.setWhole("gdb.port", remotePort);
		settings.setFlag("watch", watching);
		settings.setFlag("keep", keepingState);

		final open = new Array<String>();
		for (view in views) if (ui.visible(view.title())) open.push(view.title());
		settings.set("panels", open.join(","));

		settings.set("groups", Group.written(ui.groups()));
		settings.set(tiled ? "layout.grid" : "layout.floating",
			tiled ? grid.save() : floating.save());
		bindings.write(settings);

		if (settings.write(SettingsFile.path())) Sys.println("settings written to " + SettingsFile.path());
		else Sys.println(settings.problem);
	}

	function keyLines():Array<String> {
		final out = new Array<String>();
		var line = "  ";

		for (action in Shortcuts.actions()) {
			final said = action + " " + bindings.chord(action) + "   ";
			if (line.length + said.length > 100) {
				out.push(line);
				line = "  ";
			}
			line += said;
		}

		if (StringTools.trim(line) != "") out.push(line);
		return out;
	}

	function asked():Int {
		final args = Sys.args();
		for (i in 0...args.length) {
			if (args[i] != "--scale" || i + 1 >= args.length) continue;
			final value = Std.parseInt(args[i + 1]);
			if (value != null) return value;
		}
		return 1;
	}

	function rescale(wanted:Int):Void {
		final held = Font.held(wanted);
		if (held == scale) return;

		scale = held;
		final font = Font.on(renderer, scale);
		paint = Paint.on(renderer, font);
		ui.reface(paint);
		place(false);
	}

	function romPath():Null<String> {
		final given = positional();
		return given.length == 0 ? null : given[0];
	}

	static function positional():Array<String> {
		final out = [];
		final args = Sys.args();
		var i = 0;

		while (i < args.length) {
			if (args[i].charAt(0) == "-") {
				i += VALUED.indexOf(args[i]) >= 0 ? 2 : 1;
				continue;
			}
			out.push(args[i]);
			i++;
		}

		return out;
	}
}

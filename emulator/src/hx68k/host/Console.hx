package hx68k.host;

import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Window;
import hx68k.host.sdl.Renderer;
import hx68k.host.sdl.HostEvent;
import hx68k.debug.Debugger;
import hx68k.map.Elf;
import hx68k.map.SourceMap;
import hx68k.debug.View;
import hx68k.debug.Views;
import hx68k.md.Machine;
import hx68k.md.Vdp;

class Console {
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
	static inline final KEY_TAB = 0x00000009;
	static inline final KEY_SPACE = 0x00000020;
	static inline final KEY_C = 0x00000063;
	static inline final KEY_X = 0x00000078;
	static inline final KEY_Z = 0x0000007a;
	static inline final KEY_F10 = 0x40000043;
	static inline final KEY_F11 = 0x40000044;
	static inline final KEY_RIGHT = 0x4000004f;
	static inline final KEY_LEFT = 0x40000050;
	static inline final KEY_DOWN = 0x40000051;
	static inline final KEY_UP = 0x40000052;

	static inline final CATCH_UP = 4;

	static inline final BACKLOG = 12;

	static inline final REBUILD = 0.1;

	static inline final NOW = 0.0;

	static inline final SCREEN = "screen";

	static inline final READABLE_COLUMN = 46;

	static inline final MOST_TOOL_ROWS = 4;

	static inline final MINIMUM_WIDTH = 640;
	static inline final MINIMUM_HEIGHT = 480;

	static inline final Left = 0;
	static inline final Right = 1;

	static inline final NATIVE = Vdp.MASTER_HZ / (Vdp.MASTER_PER_LINE * Vdp.LINES_NTSC);

	static inline final SPIN = 0.0015;

	static final VALUED = ["--scale", "--measure"];

	static inline final SETTLE = 240;

	final machine:Machine = new Machine();

	var views:Array<View> = [];
	var debugger:Null<Debugger> = null;
	var apart:Map<String, Detached> = [];
	var said:Map<String, Array<hx68k.debug.Row>> = [];

	var window:cpp.Star<Window>;
	var renderer:cpp.Star<Renderer>;
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
	var viewportSide:Int = Left;

	var grid:Grid = new Grid();
	var floating:Floating = new Floating();
	var tiled:Bool = true;

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
		final console = new Console();
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
		Sys.println("the machine runs at " + Math.round(NATIVE * 100) / 100
			+ " Hz on its own clock, which is neither the display's nor the sound device's");

		Sdl.setWindowMinimumSize(window, MINIMUM_WIDTH, MINIMUM_HEIGHT);
		Sys.println("display scale " + Sdl.windowDisplayScale(window)
			+ ", so the window is measured in logical pixels");

		scale = Font.held(asked());
		final font = Font.on(renderer, scale);
		screen = Screen.on(renderer);
		paint = Paint.on(renderer, font);
		ui = new Ui(paint);
		since = Clock.stamp();

		debugger = new Debugger(machine, map());
		views = Views.of(debugger);
		insert(rom);
		arrange();

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
		Sys.println("escape quits, space pauses, tab runs it flat out, f10 and f11 step");
		Sys.println(debugger.map == null
			? "no source map given, so the panels name addresses rather than Haxe"
			: "source map loaded, so the panels name the Haxe behind an address");

		while (running) {
			pollEvents();
			Sdl.padOpen();
			pads();
			update();
			draw();
			forDetached();
			idle();
		}

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

		final started = Clock.stamp();

		last = started;

		if (!paused) {
			final period = (Vdp.MASTER_PER_LINE * Vdp.LINES_NTSC) / Vdp.MASTER_HZ;
			if (due < 0) due = started;

			var ran = 0;
			while (ran < CATCH_UP && started >= due) {
				machine.runFrame();
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
					machine.runFrame();
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
			sixtyEight = share(machine.cycles - cyclesLast, Vdp.MASTER_HZ / 7, over);
			eighty = share(machine.z80Bus.states - statesLast, Vdp.MASTER_HZ / 15, over);

			taken = share(machine.requestedFor - requestedLast, Vdp.MASTER_HZ, over);

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

	function useLayout():Void {
		grid.anchor(SCREEN, 0.5, viewportSide == Left, 3 / 4);
		ui.arrangeBy(tiled ? cast grid : cast floating);
	}

	function place(seed:Bool):Void {
		final pad = ui.margin;
		final top = ui.reserved + pad;
		final usable = width - pad * 3;

		final wanted = paint.font.advance * READABLE_COLUMN;
		final column = Math.max(0, Math.min(wanted, usable - width * 0.5));

		final screenWide = usable - column;
		final screenAt = viewportSide == Right ? pad + column + pad : pad;
		final columnAt = viewportSide == Right ? pad : pad + screenWide + pad;

		final tall = height - top - pad;

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
			quiet ? "silent" : "sound", "", "1x", "2x", "3x", tiled ? "grid" : "floating", "side", ""];
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

		for (rows in 1...MOST_TOOL_ROWS + 1) if (ui.fits(want, rows, keep, width)) return rows;
		return MOST_TOOL_ROWS;
	}

	function toolbar():Void {
		ui.toolbar();
		ui.keeping(keeping());

		if (ui.tool("open a ROM", false)) choose();
		ui.gap();

		if (ui.tool(paused ? "running" : "paused", paused)) paused = !paused;
		if (ui.tool("flat out", unlimited)) unlimited = !unlimited;
		if (ui.tool(quiet ? "silent" : "sound", !quiet)) quiet = !quiet;
		ui.gap();

		var wanted = scale;
		if (ui.tool("1x", scale == 1)) wanted = 1;
		if (ui.tool("2x", scale == 2)) wanted = 2;
		if (ui.tool("3x", scale == 3)) wanted = 3;

		if (ui.tool(tiled ? "grid" : "floating", true)) {
			tiled = !tiled;
			useLayout();
		}

		if (ui.tool("side", viewportSide == Right)) {
			viewportSide = viewportSide == Left ? Right : Left;
			place(false);
			useLayout();
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

		if (wanted != scale) rescale(wanted);
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
		final event = new HostEvent();

		while (Sdl.pollEvent(cpp.Pointer.addressOf(event).raw) != 0) {
			if (event.windowID != windowID && event.windowID != 0) {
				forwardToDetached(event);
				continue;
			}

			switch (event.type) {
				case Sdl.EVENT_QUIT | Sdl.EVENT_WINDOW_CLOSE:
					running = false;
				case Sdl.EVENT_KEY_DOWN:
					onKeyDown(event.code, event.value != 0);
				case Sdl.EVENT_KEY_UP:
					press(event.code, false);
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

	function forwardToDetached(event:HostEvent):Void {
		for (title in apart.keys()) {
			final window = apart.get(title);
			if (window.id != event.windowID) continue;

			if (event.type == Sdl.EVENT_QUIT || event.type == Sdl.EVENT_WINDOW_CLOSE) window.shut();
			return;
		}
	}

	function onKeyDown(code:Int, again:Bool):Void {
		if (again) {
			press(code, true);
			return;
		}

		switch (code) {
			case KEY_ESCAPE: running = false;
			case KEY_SPACE: paused = !paused;
			case KEY_TAB: unlimited = !unlimited;
			case KEY_F10: step(false);
			case KEY_F11: step(true);
			case _: press(code, true);
		}
	}

	function step(wholeLine:Bool):Void {
		if (!paused || debugger == null) return;

		if (wholeLine && debugger.map != null) debugger.stepLine();
		else debugger.step();

		rebuilt = NOW;
	}

	function press(code:Int, held:Bool):Void {
		final button = switch (code) {
			case KEY_UP: PAD_UP;
			case KEY_DOWN: PAD_DOWN;
			case KEY_LEFT: PAD_LEFT;
			case KEY_RIGHT: PAD_RIGHT;
			case KEY_Z: PAD_A;
			case KEY_X: PAD_B;
			case KEY_C: PAD_C;
			case KEY_RETURN: PAD_START;
			case _: 0;
		}

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
		ui.finish();
	}

	function padCheck():Void {
		keyed = 0;

		onKeyDown(KEY_RIGHT, false);
		pads();
		final one = machine.buttons[0];

		onKeyDown(KEY_Z, false);
		pads();
		final two = machine.buttons[0];

		onKeyDown(KEY_DOWN, false);
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
			+ ": viewport " + Math.round(100 * viewport.width / width) + "% of width"
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

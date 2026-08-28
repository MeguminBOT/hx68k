package hx68k.host;

import haxe.io.Bytes;
import hx68k.host.sdl.Canvas;
import hx68k.host.sdl.Event;
import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Window;
import hx68k.host.ui.Font;
import hx68k.host.ui.Paint;
import hx68k.host.ui.PlayerSettings;
import hx68k.host.ui.Ui;
import hx68k.host.ui.Widgets;
import hx68k.md.Machine;
import hx68k.md.Vdp;

class Player {
	static inline final KEY_ESCAPE = 0x0000001b;

	static inline final CATCH_UP = 4;

	static inline final BACKLOG = 12;

	static inline final SPIN = 0.0015;

	static inline final MINIMUM_WIDTH = 320;
	static inline final MINIMUM_HEIGHT = 240;

	final machine:Machine = new Machine();
	final settings:SettingsFile = new SettingsFile();
	final bindings:Shortcuts = new Shortcuts(Shortcuts.PLAYING);
	final pad:Gamepad = new Gamepad();
	final page:PlayerSettings = new PlayerSettings();

	var window:cpp.Star<Window>;
	var renderer:cpp.Star<Canvas>;
	var windowID:Int;
	var width:Int = 960;
	var height:Int = 720;

	var screen:Null<Screen> = null;
	var speaker:Null<Speaker> = null;
	var paint:Null<Paint> = null;
	var ui:Null<Ui> = null;
	var widgets:Null<Widgets> = null;

	var scale:Int = 1;
	var keyed:Int = 0;
	var tapped:Int = 0;
	var padWas:Int = 0;
	var padSeen:Bool = false;

	var title:String = "hx68k";
	var loaded:Bool = false;
	var running:Bool = true;
	var showing:Bool = false;
	var paused:Bool = false;
	var fullscreen:Bool = false;
	var level:Int = 3;

	var capturing:String = "";
	var capturingPad:String = "";

	var due:Float = -1;

	public function new() {}

	static function main():Void {
		new Player().run();
	}

	function run():Void {
		Native.init();

		if (Sdl.init() == 0) {
			Sys.println("SDL failed to start");
			Sys.exit(1);
		}

		Clock.fine();
		remembered();

		final cartridge = rom();
		if (cartridge == null) {
			Sys.println("no ROM: build one in with 'haxelib run hx68k player <rom>', or name one here");
			Sys.exit(1);
		}

		window = Sdl.createWindow(title, width, height);
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

		Sdl.setWindowMinimumSize(window, MINIMUM_WIDTH, MINIMUM_HEIGHT);
		if (fullscreen) Sdl.setWindowFullscreen(window, 1);

		final font = Font.on(renderer, scale);
		screen = Screen.on(renderer);
		paint = Paint.on(renderer, font);
		ui = new Ui(paint);
		widgets = new Widgets(ui);

		insert(cartridge);

		Sys.println("running " + title + " on a " + (machine.vdp.pal ? "PAL" : "NTSC")
			+ " machine at " + Math.round(native() * 100) / 100 + " Hz");
		Sys.println("escape opens the settings, and every key is in them");

		while (running) {
			pollEvents();
			Sdl.padOpen();
			pads();
			update();
			draw();
			idle();
		}

		remember();

		if (speaker != null) speaker.stop();
		Sdl.padClose();
		Sdl.destroyRenderer(renderer);
		Sdl.destroyWindow(window);
		Sdl.quit();
	}

	function rom():Null<Bytes> {
		final baked = haxe.Resource.listNames();
		if (baked.length > 0) {
			title = baked[0];
			return haxe.Resource.getBytes(baked[0]);
		}

		for (given in Sys.args()) {
			if (StringTools.startsWith(given, "-")) continue;
			if (!sys.FileSystem.exists(given)) continue;
			title = haxe.io.Path.withoutDirectory(given);
			return sys.io.File.getBytes(given);
		}

		return null;
	}

	function insert(cartridge:Bytes):Void {
		machine.reset();
		machine.insert(cartridge);

		if (speaker == null) speaker = new Speaker();
		speaker.gain = PlayerSettings.GAINS[level];

		loaded = true;
		due = -1;
		Sdl.setWindowTitle(window, title);
	}

	function native():Float {
		return machine.vdp.masterHz / (Vdp.MASTER_PER_LINE * machine.vdp.lines);
	}

	function update():Void {
		if (!loaded) return;

		final started = Clock.stamp();

		if (paused) {
			due = started;
			if (speaker != null) speaker.silence();
			return;
		}

		final period = 1.0 / native();
		if (due < 0) due = started;

		var ran = 0;
		while (ran < CATCH_UP && started >= due) {
			machine.runFrame();
			due += period;
			ran++;
		}

		if (started - due > period * BACKLOG) due = started - period * BACKLOG;

		if (speaker != null) speaker.feed(machine.sound);
	}

	function draw():Void {
		Sdl.renderClear(renderer, 0, 0, 0, 1);
		screen.draw(renderer, machine.vdp.renderer, 0, 0, width, height);

		ui.begin(width, height);
		if (showing) sheet();
		ui.finish();

		Sdl.renderPresent(renderer);
	}

	function sheet():Void {
		page.bindings = bindings;
		page.pad = pad;
		page.capturing = capturing;
		page.capturingPad = capturingPad;
		page.padSeen = padSeen;
		page.romName = title;
		page.scale = scale;
		page.fullscreen = fullscreen;
		page.level = level;

		page.draw(widgets, ui, width, height);

		if (page.shut) {
			close();
			return;
		}

		if (page.scale != scale) rescale(page.scale);
		if (page.fullscreen != fullscreen) whole(page.fullscreen);

		if (page.level != level) {
			level = page.level;
			if (speaker != null) speaker.gain = PlayerSettings.GAINS[level];
		}

		if (page.restore) {
			bindings.reset();
			page.clash = "";
		}

		if (page.restorePad) {
			pad.reset();
			page.clash = "";
		}

		if (page.capture != "") {
			capturing = page.capture;
			capturingPad = "";
			page.clash = "";
		}

		if (page.capturePad != "") {
			capturingPad = page.capturePad;
			capturing = "";
			page.clash = "";
			padWas = Sdl.padRaw();
		}

		if (page.restart) {
			machine.reset();
			due = -1;
			paused = false;
			close();
		}

		if (page.quit) running = false;
	}

	function rescale(wanted:Int):Void {
		scale = Font.held(wanted);
		final font = Font.on(renderer, scale);
		paint = Paint.on(renderer, font);
		ui.reface(paint);
		widgets = new Widgets(ui);
	}

	function whole(wanted:Bool):Void {
		fullscreen = wanted;
		Sdl.setWindowFullscreen(window, fullscreen ? 1 : 0);
		width = Sdl.windowWidth(window);
		height = Sdl.windowHeight(window);
	}

	function open():Void {
		showing = true;
		capturing = "";
		capturingPad = "";
		page.clash = "";
		keyed = 0;
		tapped = 0;
	}

	function close():Void {
		showing = false;
		capturing = "";
		capturingPad = "";
		page.clash = "";
	}

	function pollEvents():Void {
		final event = new Event();

		while (Sdl.pollEvent(cpp.Pointer.addressOf(event).raw) != 0) {
			if (event.windowID != windowID && event.windowID != 0) continue;

			switch (event.type) {
				case Sdl.EVENT_QUIT | Sdl.EVENT_WINDOW_CLOSE:
					running = false;
				case Sdl.EVENT_KEY_DOWN:
					onKeyDown(event.code, event.value != 0, event.mods);
				case Sdl.EVENT_KEY_UP:
					press(event.code, false);
				case Sdl.EVENT_MOUSE_MOVE:
					ui.moved(event.x, event.y);
				case Sdl.EVENT_MOUSE_DOWN:
					ui.moved(event.x, event.y);
					ui.button(true);
				case Sdl.EVENT_MOUSE_UP:
					ui.moved(event.x, event.y);
					ui.button(false);
				case Sdl.EVENT_MOUSE_WHEEL:
					ui.turn(event.y);
				case Sdl.EVENT_WINDOW_RESIZED:
					width = event.code;
					height = event.value;
				case Sdl.EVENT_WINDOW_FOCUS_LOST:
					keyed = 0;
				case _:
			}
		}
	}

	function onKeyDown(code:Int, again:Bool, mods:Int):Void {
		if (capturing != "") {
			if (!again) captured(code, mods);
			return;
		}

		if (again) {
			if (!showing) press(code, true);
			return;
		}

		if (code == KEY_ESCAPE) {
			if (showing) close() else open();
			return;
		}

		if (showing) return;

		switch (bindings.commandFor(code, mods)) {
			case "pause": paused = !paused;
			case "fullscreen": whole(!fullscreen);
			case "restart": machine.reset();
			case "settings": open();
			case _: press(code, true);
		}
	}

	function captured(code:Int, mods:Int):Void {
		if (Keys.modifier(code)) return;

		if (code == KEY_ESCAPE) {
			capturing = "";
			page.clash = "";
			return;
		}

		final chord = Keys.name(code, mods);
		if (chord == "") return;

		final taken = bindings.clash(capturing, chord);
		if (taken != "") {
			page.clash = taken;
			return;
		}

		bindings.bind(capturing, chord);
		page.clash = "";
		capturing = "";
	}

	function press(code:Int, down:Bool):Void {
		final mask = bindings.buttonMask(code);
		if (mask == 0) return;

		if (down) {
			keyed |= mask;
			tapped |= mask;
		} else {
			keyed &= ~mask;
		}
	}

	function pads():Void {
		final raw = Sdl.padRaw();
		if (raw != 0) padSeen = true;

		if (capturingPad != "") {
			bindingPad(raw);
			padWas = raw;
			machine.buttons[0] = 0;
			return;
		}

		padWas = raw;

		if (showing) {
			machine.buttons[0] = 0;
			return;
		}

		machine.buttons[0] = keyed | tapped | pad.maskOf(raw);
		tapped = 0;
	}

	function bindingPad(raw:Int):Void {
		final pressed = Gamepad.pressedIn(raw, padWas);
		if (pressed == "") return;

		final taken = pad.clash(capturingPad, pressed);
		if (taken != "") {
			page.clash = taken;
			return;
		}

		pad.bind(capturingPad, pressed);
		page.clash = "";
		capturingPad = "";
	}

	function idle():Void {
		if (!loaded || due < 0) return;

		final wait = due - Clock.stamp() - SPIN;
		if (wait > 0) Sys.sleep(wait);
		while (Clock.stamp() < due) {}
	}

	function remembered():Void {
		if (!settings.read(SettingsFile.path())) return;

		scale = Font.held(settings.whole("scale", 1));
		fullscreen = settings.flag("fullscreen", false);
		level = settings.whole("volume", 3);
		if (level < 0 || level >= PlayerSettings.GAINS.length) level = 3;

		width = settings.whole("width", width);
		height = settings.whole("height", height);

		bindings.read(settings);
		pad.read(settings);
	}

	function remember():Void {
		settings.setWhole("scale", scale);
		settings.setFlag("fullscreen", fullscreen);
		settings.setWhole("volume", level);

		if (!fullscreen) {
			settings.setWhole("width", width);
			settings.setWhole("height", height);
		}

		bindings.write(settings);
		pad.write(settings);
		settings.write(SettingsFile.path());
	}
}

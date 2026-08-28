package hx68k.host.ui;

import hx68k.host.Gamepad;
import hx68k.host.Shortcuts;

class PlayerSettings {
	public static final SECTIONS = ["display", "sound", "keys", "controller", "cartridge"];

	public static final LEVELS = ["silent", "quiet", "half", "loud", "full"];

	public static final GAINS = [0, 6, 12, 21, 32];

	public var section:Int = 0;

	var cut:Int = 0;

	public var scale:Int = 1;
	public var fullscreen:Bool = false;
	public var level:Int = 3;
	public var romName:String = "";
	public var padSeen:Bool = false;

	public var bindings:Null<Shortcuts> = null;
	public var pad:Null<Gamepad> = null;

	public var capturing:String = "";
	public var capturingPad:String = "";
	public var clash:String = "";

	public var shut(default, null):Bool = false;
	public var capture(default, null):String = "";
	public var capturePad(default, null):String = "";
	public var restore(default, null):Bool = false;
	public var restorePad(default, null):Bool = false;
	public var restart(default, null):Bool = false;
	public var quit(default, null):Bool = false;

	public function new() {}

	public function draw(widgets:Widgets, ui:Ui, width:Float, height:Float):Void {
		shut = false;
		capture = "";
		capturePad = "";
		restore = false;
		restorePad = false;
		restart = false;
		quit = false;

		widgets.scrim(width, height);
		widgets.sheet("settings", width, height);

		if (widgets.shut()) {
			shut = true;
			return;
		}

		final column = Math.min(widgets.sheetWide * 0.34,
			Math.max(ui.paint.font.advance * 12, widgets.sheetWide * 0.26));
		final top = widgets.bottom();

		widgets.column(widgets.sheetX + ui.margin, column);
		section = widgets.list(SECTIONS, section, SECTIONS.length);

		widgets.at(top);
		widgets.column(widgets.sheetX + ui.margin + column + ui.margin,
			widgets.sheetWide - column - ui.margin * 3);

		switch (SECTIONS[section]) {
			case "display": display(widgets);
			case "sound": speaker(widgets);
			case "keys": keys(widgets);
			case "controller": controller(widgets);
			case _: cartridge(widgets);
		}
	}

	function display(widgets:Widgets):Void {
		widgets.say("the window is");
		fullscreen = widgets.choice(["a window", "the whole screen"], fullscreen ? 1 : 0) == 1;

		widgets.rule();
		widgets.say("text scale");
		scale = widgets.choice(["1x", "2x", "3x"], scale - 1) + 1;

		widgets.rule();
		widgets.say("the picture keeps its 4:3 shape", Ui.DIM);
		widgets.say("whatever the window does", Ui.DIM);
	}

	function speaker(widgets:Widgets):Void {
		widgets.say("volume");
		level = widgets.choice(LEVELS, level);

		widgets.rule();
		widgets.say("the machine makes sound at its own rate", Ui.DIM);
		widgets.say("and the device is fed from a ring", Ui.DIM);
	}

	function keys(widgets:Widgets):Void {
		final table = bindings;
		if (table == null) return;

		if (clash != "" && capturingPad == "") {
			widgets.say(clash + " already has that key", Widgets.WARN);
		} else if (cut > 0) {
			widgets.say(cut + " more below, make the window taller", Widgets.WARN);
		} else {
			widgets.say("click a key to change it, escape cancels", Ui.DIM);
		}

		if (widgets.button("put every key back")) restore = true;
		widgets.rule();

		for (action in table.actions()) {
			final held = capturing == action;
			if (widgets.chip(action, table.chord(action), held, clash != "" && held)) capture = action;
		}

		cut = widgets.dropped;
	}

	function controller(widgets:Widgets):Void {
		final table = pad;
		if (table == null) return;

		if (!padSeen) widgets.say("no controller is answering yet", Ui.DIM);
		else if (clash != "" && capturingPad != "") {
			widgets.say(clash + " already has that button", Widgets.WARN);
		} else widgets.say("click a button to change it, escape cancels", Ui.DIM);

		if (widgets.button("put every button back")) restorePad = true;
		widgets.rule();

		for (action in Shortcuts.BUTTONS) {
			final held = capturingPad == action;
			if (widgets.chip(action, table.button(action), held, clash != "" && held)) {
				capturePad = action;
			}
		}
	}

	function cartridge(widgets:Widgets):Void {
		widgets.say(romName == "" ? "no ROM in the machine" : romName, Ui.DIM);
		widgets.rule();

		if (widgets.button("start it again")) restart = true;
		widgets.rule();
		if (widgets.button("quit")) quit = true;
	}
}

package hx68k.host.ui;

import hx68k.host.ui.Zone.Side;

class SettingsPage {
	public static final SECTIONS = ["display", "layout", "sound", "panels", "rom", "keys"];

	public var section:Int = 0;
	public var page:Int = 0;

	var cut:Int = 0;

	public var scale:Int = 1;
	public var viewport:Side = Left;
	public var tiled:Bool = true;
	public var sound:Bool = true;
	public var rewind:Bool = false;
	public var watching:Bool = false;
	public var keeping:Bool = false;
	public var romName:String = "";

	public var titles:Array<String> = [];
	public var open:Array<Bool> = [];
	public var picked:Int = 0;

	public var bindings:Null<Shortcuts> = null;
	public var capturing:String = "";
	public var clash:String = "";

	public var shut(default, null):Bool = false;
	public var reset(default, null):Bool = false;
	public var toggled(default, null):Int = -1;
	public var capture(default, null):String = "";
	public var restore(default, null):Bool = false;
	public var reload(default, null):Bool = false;
	public var tookField(default, null):Bool = false;

	final filter:Field = new Field("", 24);

	public function new() {}

	public function field():Field {
		return filter;
	}

	public function draw(widgets:Widgets, ui:Ui, focus:Focus, width:Float, height:Float):Void {
		shut = false;
		reset = false;
		toggled = -1;
		capture = "";
		restore = false;
		reload = false;
		tookField = false;

		widgets.scrim(width, height);
		widgets.sheet("preferences", width, height);

		if (widgets.shut()) {
			shut = true;
			return;
		}

		final column = Math.min(widgets.sheetWide * 0.34,
			Math.max(ui.paint.font.advance * 10, widgets.sheetWide * 0.24));
		final top = widgets.bottom();

		widgets.column(widgets.sheetX + ui.margin, column);
		section = widgets.list(SECTIONS, section, SECTIONS.length);

		widgets.at(top);
		widgets.column(widgets.sheetX + ui.margin + column + ui.margin,
			widgets.sheetWide - column - ui.margin * 3);

		switch (SECTIONS[section]) {
			case "display": display(widgets);
			case "layout": layout(widgets);
			case "sound": speaker(widgets);
			case "panels": panels(widgets, focus);
			case "rom": cartridge(widgets);
			case _: keys(widgets);
		}
	}

	function display(widgets:Widgets):Void {
		widgets.say("font scale");
		scale = widgets.choice(["1x", "2x", "3x"], scale - 1) + 1;

		widgets.say("the viewport sits on the");
		viewport = switch (widgets.choice(["left", "centre", "right"],
			viewport == Right ? 2 : (viewport == Middle ? 1 : 0))) {
			case 2: Right;
			case 1: Middle;
			case _: Left;
		}

		widgets.rule();
		widgets.say("a bigger scale reads better and fits fewer rows", Ui.DIM);
	}

	function layout(widgets:Widgets):Void {
		widgets.say("panels are");
		tiled = widgets.choice(["tiled into a grid", "floating"], tiled ? 0 : 1) == 0;

		widgets.rule();
		widgets.say(tiled ? "the grid holds the viewport at half the width"
			: "floating panels stay where they are put", Ui.DIM);
		widgets.say("the arrangement is kept between runs, one per kind", Ui.DIM);

		widgets.rule();
		if (widgets.button("start the arrangement again")) reset = true;
	}

	function speaker(widgets:Widgets):Void {
		widgets.say("sound is");
		sound = widgets.choice(["on", "silent"], sound ? 0 : 1) == 0;

		widgets.rule();
		widgets.say("rewind keeps every frame, which costs memory");
		rewind = widgets.choice(["off", "on"], rewind ? 1 : 0) == 1;
	}

	function cartridge(widgets:Widgets):Void {
		widgets.say(romName == "" ? "no ROM in the machine" : romName, Ui.DIM);
		widgets.rule();

		widgets.say("watch the file and load it again when it changes");
		watching = widgets.choice(["off", "on"], watching ? 1 : 0) == 1;

		widgets.say("and put the kept state back afterwards");
		keeping = widgets.choice(["off", "on"], keeping ? 1 : 0) == 1;

		widgets.rule();
		widgets.say("a state only fits the ROM it came from, so keeping one across a rebuild", Ui.DIM);
		widgets.say("is worth it while the code has not moved and not otherwise", Ui.DIM);

		widgets.rule();
		if (widgets.button("load it again now")) reload = true;
	}

	function keys(widgets:Widgets):Void {
		final table = bindings;
		if (table == null) return;

		if (clash != "") widgets.say(clash + " already has that key, so nothing changed", Widgets.WARN);
		else if (cut > 0) widgets.say(cut + " more below, make the window taller", Widgets.WARN);
		else widgets.say("click a key to change it, escape leaves it alone", Ui.DIM);

		page = widgets.choice(["commands", "the pad"], page);
		if (widgets.button("put every key back")) restore = true;
		widgets.rule();

		final shown = page == 0 ? Shortcuts.COMMANDS : Shortcuts.BUTTONS;
		for (action in shown) row(widgets, table, action);
		cut = widgets.dropped;
	}

	function row(widgets:Widgets, table:Shortcuts, action:String):Void {
		final held = capturing == action;
		if (widgets.chip(action, table.chord(action), held, clash != "" && held)) capture = action;
	}

	function panels(widgets:Widgets, focus:Focus):Void {
		widgets.say("show a panel, or hide it");
		if (widgets.field(filter, focus.on("filter"), "filter")) tookField = true;

		final shown = new Array<String>();
		final index = new Array<Int>();
		final wanted = filter.text.toLowerCase();

		for (at in 0...titles.length) {
			if (wanted != "" && titles[at].toLowerCase().indexOf(wanted) < 0) continue;
			shown.push((open[at] ? "[x] " : "[ ] ") + titles[at]);
			index.push(at);
		}

		if (shown.length == 0) {
			widgets.say("nothing here is called that", Ui.DIM);
			return;
		}

		var chose = 0;
		for (at in 0...index.length) if (index[at] == picked) chose = at;

		final now = widgets.list(shown, chose, shown.length);
		picked = index[now];

		widgets.rule();
		if (widgets.button(open[picked] ? "hide it" : "show it")) toggled = picked;
	}
}

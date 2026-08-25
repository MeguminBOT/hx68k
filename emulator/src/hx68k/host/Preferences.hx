package hx68k.host;

class Preferences {
	public static final SECTIONS = ["display", "layout", "sound", "panels", "keys"];

	public var section:Int = 0;
	public var page:Int = 0;

	var cut:Int = 0;

	public var scale:Int = 1;
	public var viewportRight:Bool = false;
	public var tiled:Bool = true;
	public var sound:Bool = true;
	public var rewind:Bool = false;

	public var titles:Array<String> = [];
	public var open:Array<Bool> = [];
	public var picked:Int = 0;

	public var bindings:Null<Bindings> = null;
	public var capturing:String = "";
	public var clash:String = "";

	public var shut(default, null):Bool = false;
	public var reset(default, null):Bool = false;
	public var toggled(default, null):Int = -1;
	public var capture(default, null):String = "";
	public var restore(default, null):Bool = false;
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
			case _: keys(widgets);
		}
	}

	function display(widgets:Widgets):Void {
		widgets.say("font scale");
		scale = widgets.choice(["1x", "2x", "3x"], scale - 1) + 1;

		widgets.say("the viewport sits on the");
		viewportRight = widgets.choice(["left", "right"], viewportRight ? 1 : 0) == 1;

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

	function keys(widgets:Widgets):Void {
		final table = bindings;
		if (table == null) return;

		if (clash != "") widgets.say(clash + " already has that key, so nothing changed", Widgets.WARN);
		else if (cut > 0) widgets.say(cut + " more below, make the window taller", Widgets.WARN);
		else widgets.say("click a key to change it, escape leaves it alone", Ui.DIM);

		page = widgets.choice(["commands", "the pad"], page);
		if (widgets.button("put every key back")) restore = true;
		widgets.rule();

		final shown = page == 0 ? Bindings.COMMANDS : Bindings.BUTTONS;
		for (action in shown) row(widgets, table, action);
		cut = widgets.dropped;
	}

	function row(widgets:Widgets, table:Bindings, action:String):Void {
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

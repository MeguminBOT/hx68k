package hx68k.host;

import hx68k.debug.Row;
import hx68k.debug.Row.Kind;

class Ui {
	public static inline final BACKGROUND = 0x14181D;
	public static inline final FRAME = 0x2E3742;
	public static inline final BAR = 0x232B34;
	public static inline final ACTIVE = 0x3B6EA5;
	public static inline final INK = 0xD5DAE0;
	public static inline final DIM = 0x7C8794;

	static inline final CONTROLS = 3;

	public var paint(default, null):Paint;

	public var bar(default, null):Float;

	public var margin(default, null):Float;

	var grip:Float;
	var edge:Float;
	var controlGap:Float;
	var barText:Float;
	var toolText:Float;
	var toolPad:Float;

	var panels:Map<String, Panel> = [];
	var arrangement:Array<Panel> = [];

	var nests:Array<Group> = [];
	var byNest:Map<String, Group> = [];
	var layout:Null<Layout> = null;
	final zone:Zone = new Zone();

	var pointerX:Float = 0;
	var pointerY:Float = 0;
	var pressedX:Float = -1;
	var pressedY:Float = -1;
	var down:Bool = false;
	var pressed:Bool = false;
	var released:Bool = false;

	var dragging:Null<Panel> = null;
	var resizing:Null<Panel> = null;
	var scrubbing:Null<Panel> = null;
	var scrubbingAcross:Null<Panel> = null;
	var acrossFrom:Int = 0;
	var downFrom:Int = 0;
	var grabX:Float = 0;
	var grabY:Float = 0;
	var grabWidth:Float = 0;
	var turned:Float = 0;

	public var reserved(default, null):Float = 0;

	var toolPen:Float = 0;
	var reserve:Float = 0;
	var overflowed:Bool = false;
	var toolInset:Float = 0;
	var toolRows:Int = 1;
	var toolRow:Int = 0;
	var shutting:Null<String> = null;
	var columnGap:Float = 0;
	var scrollThick:Float = 0;
	var scrollLeast:Float = 0;

	var width:Float = 0;
	var height:Float = 0;
	var tall:Int = 0;
	var current:Null<Panel> = null;
	var pen:Float = 0;
	var top:Int = 1;

	public function new(paint:Paint) {
		this.paint = paint;
		measured();
	}

	public function reface(paint:Paint):Void {
		this.paint = paint;
		measured();
	}

	public function measured():Void {
		final font = paint.font;

		margin = Math.max(4, font.advance * 0.5);
		controlGap = Math.max(2, font.advance * 0.25);

		grip = Math.max(4, font.advance * 0.375);
		edge = font.advance * 3;

		bar = font.height + Math.max(4, font.advance * 0.5);
		reserved = bar * toolRows + Math.max(3, font.advance * 0.375);

		barText = (bar - font.height) * 0.5 + font.ascent;
		toolText = (bar - font.height) * 0.5 + font.ascent;
		toolPad = Math.max(4, font.advance * 0.5);
		toolInset = Math.max(2, font.advance * 0.25);
		columnGap = Math.max(4, font.advance * 0.5);
		scrollThick = Math.max(6, font.advance * 0.5);
		scrollLeast = font.height;
	}

	inline function controlAt(panel:Panel, index:Int):Float {
		return panel.x + panel.width - margin - (index + 1) * paint.font.advance
			- index * controlGap;
	}

	public function moved(x:Float, y:Float):Void {
		pointerX = x;
		pointerY = y;
	}

	public function turn(amount:Float):Void {
		turned += amount;
	}

	public function button(held:Bool):Void {
		if (held && !down) {
			pressed = true;
			pressedX = pointerX;
			pressedY = pointerY;
		}
		if (!held && down) released = true;
		down = held;
	}

	function clicked(x:Float, y:Float, wide:Float, tall:Float):Bool {
		if (!released) return false;
		if (pointerX < x || pointerX >= x + wide || pointerY < y || pointerY >= y + tall) return false;
		return pressedX >= x && pressedX < x + wide && pressedY >= y && pressedY < y + tall;
	}

	public function toolbar():Void {
		paint.rectangle(0, 0, width, reserved, BAR);
		paint.rectangle(0, reserved - 1, width, 1, FRAME);
		toolPen = margin;
		toolRow = 0;
		reserve = 0;
		overflowed = false;
	}

	public function toolWidth(label:String):Float {
		return paint.font.measure(label) + toolPad * 2;
	}

	public function fits(sequence:Array<String>, rows:Int, keep:Float, across:Float):Bool {
		var row = 0;
		var pen = margin;

		for (label in sequence) {
			if (label == "") {
				pen += paint.font.advance;
				continue;
			}

			final wide = toolWidth(label);
			if (pen + wide > across - margin - (row == rows - 1 ? keep : 0)) {
				if (row + 1 >= rows) return false;
				row++;
				pen = margin;
			}
			pen += wide + controlGap;
		}

		return true;
	}

	public function rows(count:Int):Void {
		final wanted = count < 1 ? 1 : count;
		if (wanted == toolRows) return;
		toolRows = wanted;
		measured();
	}

	public function tool(label:String, on:Bool):Bool {
		final wide = paint.font.measure(label) + toolPad * 2;

		if (toolPen + wide > width - margin - (toolRow == toolRows - 1 ? reserve : 0)) {
			if (toolRow + 1 >= toolRows) {
				overflowed = true;
				return false;
			}
			toolRow++;
			toolPen = margin;
		}

		final top = toolRow * bar + toolInset;
		final high = bar - toolInset * 2;
		final over = pointerY >= toolRow * bar && pointerY < (toolRow + 1) * bar
			&& pointerX >= toolPen && pointerX < toolPen + wide;

		if (on) paint.rectangle(toolPen, top, wide, high, ACTIVE, 0.75);
		else if (over) paint.rectangle(toolPen, top, wide, high, FRAME);

		paint.text(label, toolPen + toolPad, toolRow * bar + toolText, on ? INK : DIM);
		final hit = clicked(toolPen, top, wide, high);
		toolPen += wide + controlGap;

		return hit;
	}

	public function keeping(room:Float):Void {
		reserve = room;
	}

	public function overflowing():Bool {
		return overflowed;
	}

	public function gap(width:Float = -1):Void {
		toolPen += width < 0 ? paint.font.advance : width;
	}

	public function note(text:String):Void {
		final room = width - margin - toolPen;
		if (room < paint.font.advance) return;

		final said = shorten(text, room);
		paint.text(said, width - paint.font.measure(said) - margin, toolRow * bar + toolText, DIM);
	}

	public function noteRoom():Int {
		return Std.int((width - margin - toolPen) / paint.font.advance);
	}

	public function showing(id:String):Bool {
		final panel = panels.get(id);
		return panel != null && panel.open;
	}

	public function rowsFor(id:String):Int {
		final panel = panels.get(id);
		if (panel == null || !panel.open || panel.collapsed) return 0;

		final body = panel.height - bar - margin;
		if (body <= 0) return 0;
		return Std.int(body / paint.font.height);
	}

	public function scrollThickness():Float {
		return scrollThick;
	}

	public function contentOf(id:String):Float {
		final panel = panels.get(id);
		return panel == null ? 0 : panel.content;
	}

	public function roomOf(id:String):Float {
		final panel = panels.get(id);
		return panel == null ? 0 : roomDown(panel);
	}

	public function columnGapOf():Float {
		return columnGap;
	}

	public function reachOf(id:String):Float {
		final panel = panels.get(id);
		return panel == null ? 0 : panel.reach;
	}

	public function scrollsDown(id:String):Bool {
		final panel = panels.get(id);
		return panel != null && panel.open && downwards(panel);
	}

	public function scrollsAcross(id:String):Bool {
		final panel = panels.get(id);
		return panel != null && panel.open && sideways(panel);
	}

	public function thumbShare(id:String):Float {
		final panel = panels.get(id);
		if (panel == null || !downwards(panel)) return 1;
		return roomDown(panel) / panel.content;
	}

	public function rowsVisible():Int {
		var total = 0;
		for (panel in arrangement) total += rowsFor(panel.id);
		return total;
	}

	public function metrics():Metrics {
		return new Metrics(paint.font.advance, paint.font.height, toolRows);
	}

	public function groups():Array<Group> {
		return nests;
	}

	public function nest(id:String):Group {
		var group = byNest.get(id);
		if (group == null) {
			group = new Group(id);
			byNest.set(id, group);
			nests.push(group);
		}
		return group;
	}

	public function regroup():Void {
		nests = [];
		byNest = [];

		for (panel in arrangement) {
			if (!panel.open && nestOf(panel.id) == null && panel.width == 0) continue;
			nest(panel.id).add(panel.id);
		}

		if (layout != null) layout.adopt(nests);
	}

	public function seat(id:String, x:Float, y:Float, wide:Float, tall:Float):Void {
		final group = nestOf(id);
		if (group == null) return;

		group.x = x;
		group.y = y;
		group.width = wide;
		group.height = tall;
	}

	public function visible(id:String):Bool {
		return nestOf(id) != null;
	}

	public function conceal(id:String):Void {
		final group = nestOf(id);
		if (group == null) return;

		group.drop(id);
		final panel = panels.get(id);
		if (panel != null) panel.open = false;

		if (group.empty() && layout != null) layout.adopt(nests);
	}

	public function reveal(id:String):Void {
		if (nestOf(id) != null) return;

		nest(id).add(id);
		if (layout != null) layout.adopt(nests);
	}

	public function nestOf(panel:String):Null<Group> {
		for (group in nests) if (group.holds(panel)) return group;
		return null;
	}

	public function arrangeBy(layout:Layout):Void {
		this.layout = layout;
		layout.adopt(nests);
	}

	public function offer(id:String, title:String, x:Float, y:Float, wide:Float, tall:Float):Panel {
		var panel = panels.get(id);
		if (panel == null) {
			panel = new Panel(id, title, x, y, wide, tall);
			panel.order = top++;
			panels.set(id, panel);
			arrangement.push(panel);
		}
		return panel;
	}

	public function begin(wide:Float, high:Float):Void {
		if (layout != null && layout.freeform() && width > 0 && height > 0
				&& (wide != width || high != height)) {
			final across = wide / width;
			final downward = high / height;

			for (group in nests) {
				group.x *= across;
				group.y *= downward;
				group.width *= across;
				group.height *= downward;
			}
		}

		width = wide;
		height = high;
		tall = Std.int(high);

		if (layout == null) return;

		layout.place(nests, width, height, metrics());
		mirror();
	}

	function mirror():Void {
		for (group in nests) {
			for (id in group.members) {
				final panel = panels.get(id);
				if (panel == null) continue;

				panel.open = group.showing() == id;
				panel.x = group.x;
				panel.y = group.y;
				panel.width = group.width;
				panel.height = group.height;
			}
		}
	}

	public function tabsOf(id:String):Null<Group> {
		final group = nestOf(id);
		return group != null && group.tabbed() ? group : null;
	}

	public function aiming():Zone {
		return zone;
	}

	public function overlay():Void {
		if (dragging == null) return;

		final moving = nestOf(dragging.id);
		if (moving == null) return;

		paint.release(tall);
		current = null;

		if (zone.landing()) {
			final onto = byNest.get(zone.onto);

			if (onto != null) {
				paint.rectangle(onto.x, onto.y, onto.width, onto.height, BACKGROUND, 0.55);
				hint(onto);
				frame(onto.x, onto.y, onto.width, onto.height);
			}

			paint.rectangle(zone.x, zone.y, zone.width, zone.height, ACTIVE, 0.55);
			frame(zone.x, zone.y, zone.width, zone.height);

			final name = sideName(zone.side);
			final wide = paint.font.measure(name);
			final atX = zone.x + (zone.width - wide) * 0.5;
			final atY = zone.y + zone.height * 0.5;

			paint.rectangle(atX - margin, atY - bar * 0.5, wide + margin * 2, bar, BACKGROUND, 0.9);
			paint.text(name, atX, atY + paint.font.ascent * 0.5 - paint.font.height * 0.25, INK);
		}

		final wide = Math.min(Math.max(moving.width, paint.font.advance * 10),
			paint.font.advance * 24);
		final ghostX = pointerX - wide * 0.5;
		final ghostY = pointerY - bar * 0.5;

		paint.rectangle(ghostX, ghostY, wide, bar, ACTIVE, 0.95);
		frame(ghostX, ghostY, wide, bar);
		paint.text(shorten(dragging.title, wide - margin * 2), ghostX + margin,
			ghostY + barText, INK);
	}

	function frame(x:Float, y:Float, wide:Float, high:Float):Void {
		paint.outline(x, y, wide, high, INK);
		paint.outline(x + 1, y + 1, wide - 2, high - 2, INK, 0.6);
	}

	function hint(onto:Group):Void {
		final third = 0.3;

		band(onto.x, onto.y, onto.width * third, onto.height);
		band(onto.x + onto.width * (1 - third), onto.y, onto.width * third, onto.height);
		band(onto.x, onto.y, onto.width, onto.height * third);
		band(onto.x, onto.y + onto.height * (1 - third), onto.width, onto.height * third);
		band(onto.x + onto.width * third, onto.y + onto.height * third,
			onto.width * (1 - third * 2), onto.height * (1 - third * 2));
	}

	inline function band(x:Float, y:Float, wide:Float, high:Float):Void {
		paint.rectangle(x, y, wide, high, ACTIVE, 0.22);
		paint.outline(x, y, wide, high, ACTIVE, 0.95);
	}

	static function sideName(side:Zone.Side):String {
		return switch (side) {
			case Left: "left";
			case Right: "right";
			case Above: "above";
			case Below: "below";
			case Middle: "as a tab";
			case _: "";
		}
	}

	public function panel(id:String):Bool {
		final panel = panels.get(id);
		if (panel == null || !panel.open) return false;

		current = panel;
		scrub(panel);
		handle(panel);
		wheel(panel);
		hold(panel);

		paint.clip(panel.x, panel.y, panel.width, panel.collapsed ? bar : panel.height, tall);

		paint.rectangle(panel.x, panel.y, panel.width, panel.collapsed ? bar : panel.height,
			BACKGROUND, 0.92);
		paint.rectangle(panel.x, panel.y, panel.width, bar, dragging == panel ? ACTIVE : BAR);
		paint.outline(panel.x, panel.y, panel.width, panel.collapsed ? bar : panel.height, FRAME);

		final baseline = panel.y + barText;
		final titleAt = panel.x + margin + paint.font.advance * 2;

		final group = layout != null ? nestOf(panel.id) : null;

		if (group != null && group.tabbed()) {
			strip(panel, group, baseline);
		} else {
			paint.text(panel.collapsed ? "+" : "-", panel.x + margin, baseline, DIM);
			paint.text("x", controlAt(panel, 0), baseline, DIM);
			paint.text("^", controlAt(panel, 1), baseline, DIM);
			paint.text("=", controlAt(panel, 2), baseline, DIM);

			final titleRoom = controlAt(panel, CONTROLS - 1) - controlGap - titleAt;
			if (titleRoom > 0) paint.text(shorten(panel.title, titleRoom), titleAt, baseline, INK);
		}

		final down = downwards(panel);
		final across = sideways(panel);

		bars(panel, down, across);

		paint.clip(panel.x, panel.y + bar, panel.width - (down ? scrollThick : 0),
			panel.height - bar - (across ? scrollThick : 0), tall);

		pen = panel.y + bar + paint.font.height - panel.scroll;
		panel.widest = 0;
		panel.reach = 0;
		return !panel.collapsed;
	}

	inline function roomDown(panel:Panel):Float {
		return panel.height - bar - margin;
	}

	inline function roomAcross(panel:Panel):Float {
		return panel.width - margin * 2;
	}

	function downwards(panel:Panel):Bool {
		return !panel.collapsed && panel.content > roomDown(panel) + 1;
	}

	function sideways(panel:Panel):Bool {
		return !panel.collapsed && panel.reach > roomAcross(panel) + 1;
	}

	function bars(panel:Panel, down:Bool, across:Bool):Void {
		if (down) {
			final trackY = panel.y + bar;
			final trackHigh = panel.height - bar - (across ? scrollThick : 0);
			final trackX = panel.x + panel.width - scrollThick - 1;

			paint.rectangle(trackX, trackY, scrollThick, trackHigh, BAR, 0.7);

			final room = roomDown(panel);
			final span = Math.max(1, panel.content - room);
			final high = Math.max(scrollLeast, trackHigh * room / panel.content);
			final at = trackY + (trackHigh - high) * (panel.scroll / span);

			paint.rectangle(trackX + 1, at, scrollThick - 2, high,
				scrubbing == panel ? ACTIVE : FRAME);
		}

		if (across) {
			final trackX = panel.x;
			final trackWide = panel.width - (down ? scrollThick : 0);
			final trackY = panel.y + panel.height - scrollThick - 1;

			paint.rectangle(trackX, trackY, trackWide, scrollThick, BAR, 0.7);

			final room = roomAcross(panel);
			final span = Math.max(1, panel.reach - room);
			final wide = Math.max(scrollLeast, trackWide * room / panel.reach);
			final at = trackX + (trackWide - wide) * (panel.scrollAcross / span);

			paint.rectangle(at, trackY + 1, wide, scrollThick - 2,
				scrubbingAcross == panel ? ACTIVE : FRAME);
		}
	}

	function scrub(panel:Panel):Void {
		final down = downwards(panel);
		final across = sideways(panel);

		if (pressed && down) {
			final trackX = panel.x + panel.width - scrollThick - 1;
			final trackY = panel.y + bar;
			final trackHigh = panel.height - bar - (across ? scrollThick : 0);

			if (pointerX >= trackX && pointerX < trackX + scrollThick
					&& pointerY >= trackY && pointerY < trackY + trackHigh) {
				scrubbing = panel;
				panel.order = top++;
			}
		}

		if (pressed && across) {
			final trackY = panel.y + panel.height - scrollThick - 1;
			final trackWide = panel.width - (down ? scrollThick : 0);

			if (pointerY >= trackY && pointerY < trackY + scrollThick
					&& pointerX >= panel.x && pointerX < panel.x + trackWide) {
				scrubbingAcross = panel;
				panel.order = top++;
			}
		}

		if (scrubbing == panel && down) {
			final trackY = panel.y + bar;
			final trackHigh = panel.height - bar - (across ? scrollThick : 0);
			final room = roomDown(panel);
			final high = Math.max(scrollLeast, trackHigh * room / panel.content);
			final travel = trackHigh - high;

			panel.scroll = travel <= 0 ? 0
				: (panel.content - room) * ((pointerY - trackY - high * 0.5) / travel);
		}

		if (scrubbingAcross == panel && across) {
			final trackWide = panel.width - (down ? scrollThick : 0);
			final room = roomAcross(panel);
			final wide = Math.max(scrollLeast, trackWide * room / panel.reach);
			final travel = trackWide - wide;

			panel.scrollAcross = travel <= 0 ? 0
				: (panel.reach - room) * ((pointerX - panel.x - wide * 0.5) / travel);
		}
	}

	function strip(panel:Panel, group:Group, baseline:Float):Void {
		var pen = panel.x;
		final close = controlAt(panel, 0);

		for (i in 0...group.members.length) {
			final id = group.members[i];
			final held = panels.get(id);
			final name = held == null ? id : held.title;
			final wide = paint.font.measure(name) + toolPad * 2;

			if (pen + wide > close - controlGap) {
				paint.text("+" + (group.members.length - i), pen + toolPad, baseline, DIM);
				break;
			}

			final on = i == group.active;
			if (on) paint.rectangle(pen, panel.y, wide, bar, BACKGROUND);
			paint.text(name, pen + toolPad, baseline, on ? INK : DIM);

			if (clicked(pen, panel.y, wide, bar)) group.active = i;
			pen += wide;
			paint.rectangle(pen, panel.y + 2, 1, bar - 4, FRAME);
		}

		if (clicked(close - controlGap, panel.y, paint.font.advance + controlGap * 2, bar)) {
			shutting = group.showing();
		}
		paint.text("x", close, baseline, DIM);
	}

	public function line(text:String, colour:Int = INK):Void {
		final panel = current;
		if (panel == null) return;

		final at = panel.x + margin - panel.scrollAcross;
		final end = paint.text(text, at, pen, colour);
		final ran = end - at;
		if (ran > panel.widest) panel.widest = ran;
		if (ran > panel.reach) panel.reach = ran;

		pen += paint.font.height;
		panel.content = pen + panel.scroll - (panel.y + bar);
	}

	public function table(rows:Array<Row>):Void {
		final panel = current;
		if (panel == null || rows.length == 0) return;

		final room = panel.width - margin * 2 - (downwards(panel) ? scrollThick : 0);
		final left = panel.x + margin - panel.scrollAcross;

		var at = 0;

		while (at < rows.length) {
			if (rows[at].apart) {
				if (rows[at].parts.length == 0) advance(panel);
				else spill(panel, rows[at].parts[0], left, room);
				at++;
				continue;
			}

			final shape = rows[at].parts.length;
			var end = at;
			while (end < rows.length && !rows[end].apart && rows[end].parts.length == shape) end++;

			final widths = measure(rows, at, end);

			var wanted = 0.0;
			for (width in widths) wanted += width + columnGap;
			wanted = Math.max(0, wanted - columnGap);

			if (wanted > panel.reach) panel.reach = wanted;
			if (wanted > panel.widest) panel.widest = wanted;

			for (index in at...end) {
				final parts = rows[index].parts;
				var across = left;

				for (column in 0...parts.length) {
					write(parts[column], across, widths[column]);
					across += widths[column] + columnGap;
				}

				advance(panel);
			}

			at = end;
		}
	}

	function spill(panel:Panel, part:hx68k.debug.Row.Part, left:Float, room:Float):Void {
		if (part.text == "") {
			advance(panel);
			return;
		}

		final each = Std.int(Math.max(1, room / paint.font.advance));
		final colour = colourOf(part.kind);
		var text = part.text;

		while (true) {
			if (text.length <= each) {
				final wide = paint.font.measure(text);
				if (wide > panel.reach) panel.reach = wide;
				if (wide > panel.widest) panel.widest = wide;
				paint.text(text, left, pen, colour);
				advance(panel);
				return;
			}

			var cut = each;
			var back = cut;
			while (back > 0 && text.charAt(back) != " ") back--;
			if (back > each >> 1) cut = back;
			if (cut <= 0) cut = 1;

			paint.text(text.substr(0, cut), left, pen, colour);
			advance(panel);

			text = StringTools.ltrim(text.substr(cut));
			if (text.length == 0) return;
		}
	}

	function advance(panel:Panel):Void {
		pen += paint.font.height;
		panel.content = pen + panel.scroll - (panel.y + bar);
	}

	function write(part:hx68k.debug.Row.Part, x:Float, room:Float):Void {
		if (part.text == "") return;
		paint.text(shorten(part.text, room), x, pen, colourOf(part.kind));
	}

	function measure(rows:Array<Row>, from:Int, to:Int):Array<Float> {
		final widths = new Array<Float>();

		for (index in from...to) {
			final row = rows[index];
			for (column in 0...row.parts.length) {
				final wide = paint.font.measure(row.parts[column].text);
				if (column >= widths.length) widths.push(wide);
				else if (wide > widths[column]) widths[column] = wide;
			}
		}

		return widths;
	}

	function shorten(text:String, room:Float):String {
		if (paint.font.measure(text) <= room) return text;

		var cut = text.length;
		while (cut > 1 && paint.font.measure(text.substr(0, cut) + ".") > room) cut--;
		return text.substr(0, cut) + ".";
	}

	static function colourOf(kind:Kind):Int {
		return switch (kind) {
			case Label: DIM;
			case Place: 0x9AB8D8;
			case Aside: DIM;
			case Here: 0xE8C07A;
			case _: INK;
		}
	}

	public function toggle(label:String, value:Bool):Bool {
		final panel = current;
		if (panel == null || pen > panel.y + panel.height - 4) return value;

		final row = pen - paint.font.height + 4;
		final over = pointerX >= panel.x && pointerX < panel.x + panel.width
			&& pointerY >= row && pointerY < row + paint.font.height;

		if (over) paint.rectangle(panel.x + 1, row, panel.width - 2, paint.font.height, FRAME, 0.6);

		paint.text(value ? "[x]" : "[ ]", panel.x + margin, pen, value ? INK : DIM);
		paint.text(label, panel.x + margin + paint.font.advance * 4, pen, INK);
		final hit = clicked(panel.x, row, panel.width, paint.font.height);
		pen += paint.font.height;

		return hit ? !value : value;
	}

	public function done():Void {
		paint.release(tall);
		current = null;
	}

	public function room():Int {
		final panel = current;
		if (panel == null) return 0;
		return Std.int((panel.y + panel.height - 4 - pen) / paint.font.height);
	}

	public function finish():Void {
		paint.release(tall);
		paint.flush();
		current = null;

		if (shutting != null) {
			conceal(shutting);
			shutting = null;
		}
		turned = 0;
		if (released) {
			dragging = null;
			resizing = null;
			scrubbing = null;
			scrubbingAcross = null;
		}
		pressed = false;
		released = false;
	}

	public function order():Array<Panel> {
		arrangement.sort((a, b) -> a.order - b.order);
		return arrangement;
	}

	function handle(panel:Panel):Void {
		if (scrubbing != null || scrubbingAcross != null) return;

		final held = panel.grip(pointerX, pointerY, grip);
		final onEdge = held.across != 0 || held.down != 0;

		if (dragging == null && resizing == null && pressed
				&& (panel.holds(pointerX, pointerY, bar) || onEdge)) {
			panel.order = top++;

			if (onEdge) {
				resizing = panel;
				acrossFrom = held.across;
				downFrom = held.down;
				grabX = pointerX;
				grabWidth = panel.width;
			} else if (panel.onBar(pointerX, pointerY, bar)) {
				if (pointerX < panel.x + margin + paint.font.advance * 1.5) {
					panel.collapsed = !panel.collapsed;
				} else if (pointerX >= controlAt(panel, 0) - controlGap * 0.5) {
					if (layout != null) conceal(panel.id) else panel.open = false;
				}
				else if (pointerX >= controlAt(panel, 1) - controlGap * 0.5) panel.wantsApart = true;
				else if (pointerX >= controlAt(panel, 2) - controlGap * 0.5) fit(panel);
				else {
					dragging = panel;
					grabX = pointerX - panel.x;
					grabY = pointerY - panel.y;
				}
			}
		}

		if (dragging == panel) {
			if (layout != null) {
				final group = nestOf(panel.id);
				if (group != null) {
					layout.aim(nests, group, pointerX, pointerY, width, height, metrics(), zone);

					if (layout.freeform()) {
						group.x = pointerX - grabX;
						group.y = Math.max(reserved, pointerY - grabY);
					}

					if (released) {
						layout.settle(nests, group, zone);
						zone.clear();
					}
				}
			}
		}

		if (resizing == panel) resize(panel);
	}

	function resize(panel:Panel):Void {
		if (layout != null && !layout.freeform()) return;

		final group = layout != null ? nestOf(panel.id) : null;
		if (group != null) {
			if (acrossFrom > 0) group.width = Math.max(paint.font.advance * 12, pointerX - group.x);
			else if (acrossFrom < 0) {
				final right = group.x + group.width;
				group.x = Math.min(pointerX, right - paint.font.advance * 12);
				group.width = right - group.x;
			}
			if (downFrom > 0) group.height = Math.max(bar * 3, pointerY - group.y);
			return;
		}

		final least = paint.font.advance * 12;

		if (acrossFrom > 0) panel.width = Math.max(least, pointerX - panel.x);
		else if (acrossFrom < 0) {
			final right = panel.x + panel.width;
			panel.x = Math.min(pointerX, right - least);
			panel.width = right - panel.x;
		}

		if (downFrom > 0) panel.height = Math.max(bar * 3, pointerY - panel.y);
	}

	public function fit(panel:Panel):Void {
		if (panel.widest <= 0) return;
		panel.width = panel.widest + margin * 2 + 2;
	}

	function hold(panel:Panel):Void {
		final most = Math.max(0, panel.content - roomDown(panel));
		if (panel.scroll > most) panel.scroll = most;
		if (panel.scroll < 0) panel.scroll = 0;

		final widest = Math.max(0, panel.reach - roomAcross(panel));
		if (panel.scrollAcross > widest) panel.scrollAcross = widest;
		if (panel.scrollAcross < 0) panel.scrollAcross = 0;
	}

	function wheel(panel:Panel):Void {
		if (turned == 0 || !panel.holds(pointerX, pointerY, bar)) return;
		panel.scroll -= turned * paint.font.height;
	}




}

package hx68k.host;

import hx68k.debug.Row;
import hx68k.debug.Row.Kind;
import hx68k.host.Panel.Dock;

class Ui {
	public static inline final BACKGROUND = 0x14181D;
	public static inline final FRAME = 0x2E3742;
	public static inline final BAR = 0x232B34;
	public static inline final ACTIVE = 0x3B6EA5;
	public static inline final INK = 0xD5DAE0;
	public static inline final DIM = 0x7C8794;

	static inline final GRIP = 6.0;
	static inline final EDGE = 48.0;
	static inline final MARGIN = 8.0;

	public final paint:Paint;

	public var bar(default, null):Float;

	var panels:Map<String, Panel> = [];
	var arrangement:Array<Panel> = [];

	var pointerX:Float = 0;
	var pointerY:Float = 0;
	var pressedX:Float = -1;
	var pressedY:Float = -1;
	var down:Bool = false;
	var pressed:Bool = false;
	var released:Bool = false;

	var dragging:Null<Panel> = null;
	var resizing:Null<Panel> = null;
	var acrossFrom:Int = 0;
	var downFrom:Int = 0;
	var grabX:Float = 0;
	var grabY:Float = 0;
	var grabWidth:Float = 0;
	var turned:Float = 0;

	public var reserved(default, null):Float = 0;

	var toolPen:Float = 0;

	var width:Float = 0;
	var height:Float = 0;
	var tall:Int = 0;
	var current:Null<Panel> = null;
	var pen:Float = 0;
	var top:Int = 1;

	public function new(paint:Paint) {
		this.paint = paint;
		this.bar = paint.font.height + 8;
		this.reserved = bar + 6;
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
		toolPen = MARGIN;
	}

	public function tool(label:String, on:Bool):Bool {
		final wide = paint.font.measure(label) + 16;
		if (toolPen + wide > width - MARGIN) return false;
		final over = pointerY < reserved && pointerX >= toolPen && pointerX < toolPen + wide;

		if (on) paint.rectangle(toolPen, 4, wide, reserved - 9, ACTIVE, 0.75);
		else if (over) paint.rectangle(toolPen, 4, wide, reserved - 9, FRAME);

		paint.text(label, toolPen + 8, reserved - 9, on ? INK : DIM);
		final hit = clicked(toolPen, 4, wide, reserved - 9);
		toolPen += wide + 4;

		return hit;
	}

	public function gap(width:Float = 16):Void {
		toolPen += width;
	}

	public function note(text:String):Void {
		final room = width - MARGIN - toolPen;
		if (room <= 0) return;

		var said = text;
		var wide = paint.font.measure(said);

		if (wide > room) {
			said = said.substr(0, Std.int(said.length * room / wide));
			wide = paint.font.measure(said);
			while (said.length > 1 && wide > room) {
				said = said.substr(0, said.length - 1);
				wide = paint.font.measure(said);
			}
		}

		paint.text(said, width - wide - MARGIN, reserved - 9, DIM);
	}

	public function showing(id:String):Bool {
		final panel = panels.get(id);
		return panel != null && panel.open;
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
		if (width > 0 && height > 0 && (wide != width || high != height)) {
			final across = wide / width;
			final downward = high / height;

			for (panel in arrangement) {
				if (panel.docked != Loose) continue;
				panel.x *= across;
				panel.y *= downward;
				panel.width *= across;
				panel.height *= downward;
			}
		}

		width = wide;
		height = high;
		tall = Std.int(high);
		paint.knows(Std.int(wide));

		for (panel in arrangement) if (panel.docked == Loose && panel.y < reserved) panel.y = reserved;
		dock();
	}

	public function panel(id:String):Bool {
		final panel = panels.get(id);
		if (panel == null || !panel.open) return false;

		current = panel;
		handle(panel);
		wheel(panel);
		hold(panel);

		paint.clip(panel.x, panel.y, panel.width, panel.collapsed ? bar : panel.height, tall);

		paint.rectangle(panel.x, panel.y, panel.width, panel.collapsed ? bar : panel.height,
			BACKGROUND, 0.92);
		paint.rectangle(panel.x, panel.y, panel.width, bar, dragging == panel ? ACTIVE : BAR);
		paint.outline(panel.x, panel.y, panel.width, panel.collapsed ? bar : panel.height, FRAME);

		paint.text(panel.collapsed ? "+" : "-", panel.x + 8, panel.y + bar - 7, DIM);
		paint.text(panel.title, panel.x + 24, panel.y + bar - 7, INK);
		paint.text("x", panel.x + panel.width - 16, panel.y + bar - 7, DIM);
		paint.text("^", panel.x + panel.width - 34, panel.y + bar - 7, DIM);
		paint.text("=", panel.x + panel.width - 52, panel.y + bar - 7, DIM);

		if (panel.docked != Loose) paint.text(edgeName(panel.docked), panel.x + panel.width - 60,
			panel.y + bar - 7, DIM);

		paint.clip(panel.x, panel.y + bar, panel.width, panel.height - bar, tall);

		pen = panel.y + bar + paint.font.height - panel.scroll;
		panel.widest = 0;
		return !panel.collapsed;
	}

	public function line(text:String, colour:Int = INK):Void {
		final panel = current;
		if (panel == null) return;

		final end = paint.text(text, panel.x + MARGIN, pen, colour);
		final ran = end - (panel.x + MARGIN);
		if (ran > panel.widest) panel.widest = ran;

		pen += paint.font.height;
		panel.content = pen + panel.scroll - (panel.y + bar);
	}

	public function table(rows:Array<Row>):Void {
		final panel = current;
		if (panel == null || rows.length == 0) return;

		final room = panel.width - MARGIN * 2;
		final widths = measure(rows);
		final showing = fitting(widths, room);

		for (row in rows) {
			if (row.apart) {
				if (row.parts.length > 0) write(row.parts[0], panel.x + MARGIN, room);
				advance(panel);
				continue;
			}

			var at = panel.x + MARGIN;
			for (column in 0...showing) {
				if (column >= row.parts.length) break;

				final last = column == showing - 1;
				if (last && row.parts[column].kind == Label && column + 1 < row.parts.length) break;

				write(row.parts[column], at, widths[column]);
				at += widths[column] + paint.font.advance;
			}

			advance(panel);
		}

		var wanted = 0.0;
		for (width in widths) wanted += width + paint.font.advance;
		if (wanted > panel.widest) panel.widest = wanted;
	}

	function advance(panel:Panel):Void {
		pen += paint.font.height;
		panel.content = pen + panel.scroll - (panel.y + bar);
	}

	function write(part:hx68k.debug.Row.Part, x:Float, room:Float):Void {
		if (part.text == "") return;
		paint.text(shorten(part.text, room), x, pen, colourOf(part.kind));
	}

	function measure(rows:Array<Row>):Array<Float> {
		final widths = new Array<Float>();

		for (row in rows) {
			if (row.apart) continue;
			for (column in 0...row.parts.length) {
				final wide = paint.font.measure(row.parts[column].text);
				if (column >= widths.length) widths.push(wide);
				else if (wide > widths[column]) widths[column] = wide;
			}
		}

		return widths;
	}

	function fitting(widths:Array<Float>, room:Float):Int {
		var used = 0.0;

		for (column in 0...widths.length) {
			used += widths[column] + paint.font.advance;
			if (used > room) return column == 0 ? 1 : column;
		}

		return widths.length;
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

		paint.text(value ? "[x]" : "[ ]", panel.x + MARGIN, pen, value ? INK : DIM);
		paint.text(label, panel.x + MARGIN + paint.font.advance * 4, pen, INK);
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
		current = null;
		turned = 0;
		if (released) {
			dragging = null;
			resizing = null;
		}
		pressed = false;
		released = false;
	}

	public function order():Array<Panel> {
		arrangement.sort((a, b) -> a.order - b.order);
		return arrangement;
	}

	function handle(panel:Panel):Void {
		final edge = panel.grip(pointerX, pointerY, GRIP);
		final onEdge = edge.across != 0 || edge.down != 0;

		if (dragging == null && resizing == null && pressed
				&& (panel.holds(pointerX, pointerY, bar) || onEdge)) {
			panel.order = top++;

			if (onEdge) {
				resizing = panel;
				acrossFrom = edge.across;
				downFrom = edge.down;
				grabX = pointerX;
				grabWidth = panel.width;
			} else if (panel.onBar(pointerX, pointerY, bar)) {
				if (pointerX < panel.x + 20) panel.collapsed = !panel.collapsed;
				else if (pointerX > panel.x + panel.width - 24) panel.open = false;
				else if (pointerX > panel.x + panel.width - 42) panel.wantsApart = true;
				else if (pointerX > panel.x + panel.width - 60) fit(panel);
				else {
					dragging = panel;
					grabX = pointerX - panel.x;
					grabY = pointerY - panel.y;
				}
			}
		}

		if (dragging == panel) {
			panel.docked = Loose;
			panel.x = pointerX - grabX;
			panel.y = Math.max(reserved, pointerY - grabY);
			if (released) settle(panel);
		}

		if (resizing == panel) resize(panel);
	}

	function resize(panel:Panel):Void {
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
		panel.width = panel.widest + MARGIN * 2 + 2;
		panel.docked = Loose;
	}

	function hold(panel:Panel):Void {
		final room = panel.height - bar - 4;
		final most = Math.max(0, panel.content - room);
		if (panel.scroll > most) panel.scroll = most;
		if (panel.scroll < 0) panel.scroll = 0;
	}

	function wheel(panel:Panel):Void {
		if (turned == 0 || !panel.holds(pointerX, pointerY, bar)) return;
		panel.scroll -= turned * paint.font.height;
	}

	function settle(panel:Panel):Void {
		if (pointerX < EDGE) panel.docked = Left;
		else if (pointerX > width - EDGE) panel.docked = Right;
		else if (pointerY > height - EDGE) panel.docked = Bottom;
	}

	function dock():Void {
		for (edge in [Left, Right, Bottom]) {
			final along = [];
			for (panel in order()) if (panel.open && panel.docked == edge) along.push(panel);
			if (along.length == 0) continue;

			final strip = edge == Bottom ? height * 0.3 : width * 0.32;

			for (i in 0...along.length) {
				final panel = along[i];
				if (edge == Bottom) {
					panel.width = width / along.length;
					panel.height = strip;
					panel.x = panel.width * i;
					panel.y = height - strip;
				} else {
					final usable = height - reserved;
					panel.width = strip;
					panel.height = usable / along.length;
					panel.x = edge == Left ? 0 : width - strip;
					panel.y = reserved + panel.height * i;
				}
			}
		}
	}

	public function taken(edge:Dock):Float {
		for (panel in arrangement) if (panel.open && panel.docked == edge) {
			return edge == Bottom ? panel.height : panel.width;
		}
		return 0;
	}

	static function edgeName(edge:Dock):String {
		return switch (edge) {
			case Left: "left";
			case Right: "right";
			case Bottom: "bottom";
			case _: "";
		}
	}
}

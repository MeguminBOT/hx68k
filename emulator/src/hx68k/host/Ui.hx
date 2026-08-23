package hx68k.host;

import hx68k.host.Panel.Dock;

class Ui {
	public static inline final BACKGROUND = 0x14181D;
	public static inline final FRAME = 0x2E3742;
	public static inline final BAR = 0x232B34;
	public static inline final ACTIVE = 0x3B6EA5;
	public static inline final INK = 0xD5DAE0;
	public static inline final DIM = 0x7C8794;

	static inline final GRIP = 14.0;
	static inline final EDGE = 48.0;
	static inline final MARGIN = 8.0;

	public final paint:Paint;

	public var bar(default, null):Float;

	var panels:Map<String, Panel> = [];
	var arrangement:Array<Panel> = [];

	var pointerX:Float = 0;
	var pointerY:Float = 0;
	var down:Bool = false;
	var pressed:Bool = false;
	var released:Bool = false;

	var dragging:Null<Panel> = null;
	var resizing:Null<Panel> = null;
	var grabX:Float = 0;
	var grabY:Float = 0;

	var width:Float = 0;
	var height:Float = 0;
	var current:Null<Panel> = null;
	var pen:Float = 0;
	var top:Int = 1;

	public function new(paint:Paint) {
		this.paint = paint;
		this.bar = paint.font.height + 8;
	}

	public function moved(x:Float, y:Float):Void {
		pointerX = x;
		pointerY = y;
	}

	public function button(held:Bool):Void {
		if (held && !down) pressed = true;
		if (!held && down) released = true;
		down = held;
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

	public function begin(wide:Float, tall:Float):Void {
		width = wide;
		height = tall;
		dock();
	}

	public function panel(id:String):Bool {
		final panel = panels.get(id);
		if (panel == null || !panel.open) return false;

		current = panel;
		handle(panel);

		paint.rectangle(panel.x, panel.y, panel.width, panel.collapsed ? bar : panel.height,
			BACKGROUND, 0.92);
		paint.rectangle(panel.x, panel.y, panel.width, bar, dragging == panel ? ACTIVE : BAR);
		paint.outline(panel.x, panel.y, panel.width, panel.collapsed ? bar : panel.height, FRAME);

		paint.text(panel.collapsed ? "+" : "-", panel.x + 8, panel.y + bar - 7, DIM);
		paint.text(panel.title, panel.x + 24, panel.y + bar - 7, INK);
		paint.text("x", panel.x + panel.width - 16, panel.y + bar - 7, DIM);

		if (panel.docked != Loose) paint.text(edgeName(panel.docked), panel.x + panel.width - 60,
			panel.y + bar - 7, DIM);

		pen = panel.y + bar + paint.font.height;
		return !panel.collapsed;
	}

	public function line(text:String, colour:Int = INK):Void {
		final panel = current;
		if (panel == null || pen > panel.y + panel.height - 4) return;

		paint.text(text, panel.x + MARGIN, pen, colour);
		pen += paint.font.height;
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
		pen += paint.font.height;

		return over && released ? !value : value;
	}

	public function room():Int {
		final panel = current;
		if (panel == null) return 0;
		return Std.int((panel.y + panel.height - 4 - pen) / paint.font.height);
	}

	public function finish():Void {
		current = null;
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
		if (dragging == null && resizing == null && pressed && panel.holds(pointerX, pointerY, bar)) {
			panel.order = top++;

			if (panel.onBar(pointerX, pointerY, bar)) {
				if (pointerX < panel.x + 20) panel.collapsed = !panel.collapsed;
				else if (pointerX > panel.x + panel.width - 24) panel.open = false;
				else {
					dragging = panel;
					grabX = pointerX - panel.x;
					grabY = pointerY - panel.y;
				}
			} else if (panel.onGrip(pointerX, pointerY, GRIP)) {
				resizing = panel;
			}
		}

		if (dragging == panel) {
			panel.docked = Loose;
			panel.x = pointerX - grabX;
			panel.y = pointerY - grabY;
			if (released) settle(panel);
		}

		if (resizing == panel) {
			panel.width = Math.max(paint.font.advance * 16, pointerX - panel.x);
			panel.height = Math.max(bar * 3, pointerY - panel.y);
		}
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
					panel.width = strip;
					panel.height = height / along.length;
					panel.x = edge == Left ? 0 : width - strip;
					panel.y = panel.height * i;
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

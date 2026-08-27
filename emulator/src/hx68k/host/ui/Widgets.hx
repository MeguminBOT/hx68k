package hx68k.host.ui;

@:access(hx68k.host.ui.Ui)
class Widgets {
	public static inline final SHEET = 0x1A2029;
	public static inline final SCRIM = 0x05070A;
	public static inline final WARN = 0xE08A6A;

	public var sheetX(default, null):Float = 0;
	public var sheetY(default, null):Float = 0;
	public var sheetWide(default, null):Float = 0;
	public var sheetHigh(default, null):Float = 0;

	final ui:Ui;

	public var dropped(default, null):Int = 0;

	var left:Float = 0;
	var across:Float = 0;
	var pen:Float = 0;
	var floor:Float = 0;

	public function new(ui:Ui) {
		this.ui = ui;
	}

	public function scrim(width:Float, height:Float):Void {
		ui.paint.rectangle(0, 0, width, height, SCRIM, 0.72);
	}

	public function sheet(title:String, width:Float, height:Float, share:Float = 0.82):Void {
		final paint = ui.paint;
		dropped = 0;

		sheetWide = Math.min(width - paint.font.advance * 4, width * share);
		sheetHigh = Math.min(height - paint.font.height * 4, height * share);
		sheetX = (width - sheetWide) * 0.5;
		sheetY = (height - sheetHigh) * 0.5;

		paint.rectangle(sheetX, sheetY, sheetWide, sheetHigh, SHEET);
		paint.outline(sheetX, sheetY, sheetWide, sheetHigh, Ui.ACTIVE);
		paint.rectangle(sheetX, sheetY, sheetWide, ui.bar, Ui.BAR);
		paint.text(title, sheetX + paint.font.advance * 2, sheetY + ui.barText, Ui.INK);

		floor = sheetY + sheetHigh - ui.margin;
		column(sheetX + ui.margin, sheetWide - ui.margin * 2);
		pen = sheetY + ui.bar + ui.margin;
	}

	public function shut():Bool {
		final paint = ui.paint;
		final wide = paint.font.advance * 2;
		final x = sheetX + sheetWide - ui.margin - wide;

		paint.text("x", x + paint.font.advance * 0.5, sheetY + ui.barText, Ui.DIM);
		return hit(x, sheetY, wide, ui.bar);
	}

	public function column(x:Float, width:Float):Void {
		left = x;
		across = width;
	}

	public function reach(y:Float):Void {
		floor = y;
	}

	public function at(y:Float):Void {
		pen = y;
	}

	public function bottom():Float {
		return pen;
	}

	public function skip(down:Float):Void {
		pen += down;
	}

	public function button(action:String, enabled:Bool = true):Bool {
		final paint = ui.paint;
		final wide = paint.font.measure(action) + paint.font.advance * 2;
		final high = control();
		if (!fits(high)) return false;

		final over = enabled && inside(left, pen, wide, high);
		paint.rectangle(left, pen, wide, high, over ? Ui.ACTIVE : Ui.BAR, over ? 0.8 : 1);
		paint.outline(left, pen, wide, high, Ui.FRAME);
		paint.text(action, left + paint.font.advance, pen + baseline(high), enabled ? Ui.INK : Ui.DIM);

		final took = enabled && hit(left, pen, wide, high);
		step(high);
		return took;
	}

	public function choice(options:Array<String>, chosen:Int):Int {
		final paint = ui.paint;
		final high = control();
		if (!fits(high)) return chosen;

		var x = left;
		var picked = chosen;

		for (index in 0...options.length) {
			final option = options[index];
			final wide = paint.font.measure(option) + paint.font.advance * 2;
			final on = index == chosen;
			final over = inside(x, pen, wide, high);

			paint.rectangle(x, pen, wide, high, on ? Ui.ACTIVE : (over ? Ui.FRAME : Ui.BAR),
				on ? 0.8 : 1);
			paint.outline(x, pen, wide, high, Ui.FRAME);
			paint.text(option, x + paint.font.advance, pen + baseline(high), on ? Ui.INK : Ui.DIM);

			if (hit(x, pen, wide, high)) picked = index;
			x += wide - 1;
		}

		step(high);
		return picked;
	}

	public function list(items:Array<String>, chosen:Int, rows:Int):Int {
		final paint = ui.paint;
		final high = paint.font.height;
		final shown = rows < items.length ? rows : items.length;
		final start = firstShown(items.length, chosen, shown);

		var picked = chosen;

		for (offset in 0...shown) {
			if (!fits(high)) return picked;

			final index = start + offset;
			final on = index == chosen;

			if (on) paint.rectangle(left, pen, across, high, Ui.ACTIVE, 0.7);
			else if (inside(left, pen, across, high)) {
				paint.rectangle(left, pen, across, high, Ui.FRAME, 0.6);
			}

			paint.text(ui.shorten(items[index], across - paint.font.advance * 2),
				left + paint.font.advance, pen + paint.font.ascent, on ? Ui.INK : Ui.DIM);

			if (hit(left, pen, across, high)) picked = index;
			pen += high;
		}

		pen += gap();
		return picked;
	}

	public function field(model:Field, focused:Bool, hint:String = ""):Bool {
		final paint = ui.paint;
		final high = control();
		if (!fits(high)) return false;

		paint.rectangle(left, pen, across, high, Ui.BACKGROUND);
		paint.outline(left, pen, across, high, focused ? Ui.ACTIVE : Ui.FRAME);

		final inset = left + paint.font.advance * 0.5;
		final line = pen + baseline(high);

		if (focused && model.selecting()) {
			paint.rectangle(inset + model.from() * paint.font.advance, pen + 2,
				(model.to() - model.from()) * paint.font.advance, high - 4, Ui.ACTIVE, 0.5);
		}

		if (model.text == "" && hint != "") paint.text(hint, inset, line, Ui.DIM);
		else paint.text(model.text, inset, line, Ui.INK);

		if (focused) paint.rectangle(inset + model.caret * paint.font.advance, pen + 2, 1, high - 4, Ui.INK);

		final took = hit(left, pen, across, high);
		if (took) model.place(Math.round((ui.pointerX - inset) / paint.font.advance));

		step(high);
		return took;
	}

	public function chip(action:String, binding:String, capturing:Bool, clash:Bool = false):Bool {
		final paint = ui.paint;
		final high = control();
		if (!fits(high)) return false;

		final shown = capturing ? "press a key" : (binding == "" ? "unbound" : binding);
		final wide = Math.min(across * 0.55, paint.font.measure("press a key") + paint.font.advance * 2);
		final x = left + across - wide;

		final room = x - left - paint.font.advance;
		paint.text(ui.shorten(action, room), left + paint.font.advance * 0.5, pen + baseline(high),
			clash ? WARN : Ui.INK);
		paint.rectangle(x, pen, wide, high, capturing ? Ui.ACTIVE : Ui.BAR, capturing ? 0.8 : 1);
		paint.outline(x, pen, wide, high, clash ? WARN : Ui.FRAME);
		paint.text(ui.shorten(shown, wide - paint.font.advance * 2), x + paint.font.advance,
			pen + baseline(high), binding == "" && !capturing ? Ui.DIM : Ui.INK);

		final took = hit(x, pen, wide, high);
		step(high);
		return took;
	}

	public function say(text:String, color:Int = Ui.INK):Void {
		final paint = ui.paint;
		if (!fits(paint.font.height)) return;

		final inset = paint.font.advance * 0.5;
		paint.text(ui.shorten(text, across - inset), left + inset, pen + paint.font.ascent, color);
		pen += paint.font.height;
	}

	public function rule():Void {
		final high = Math.max(2, ui.paint.font.height * 0.5);
		if (!fits(high)) return;

		ui.paint.rectangle(left, pen + high * 0.5, across, 1, Ui.FRAME);
		pen += high;
	}

	static function firstShown(count:Int, chosen:Int, shown:Int):Int {
		if (shown >= count) return 0;

		final wanted = chosen - Std.int(shown / 2);
		if (wanted < 0) return 0;
		if (wanted + shown > count) return count - shown;
		return wanted;
	}

	inline function control():Float {
		return ui.paint.font.height + Math.max(2, ui.paint.font.advance * 0.25);
	}

	inline function gap():Float {
		return Math.max(2, ui.paint.font.advance * 0.25);
	}

	inline function step(high:Float):Void {
		pen += high + gap();
	}

	inline function baseline(high:Float):Float {
		return (high - ui.paint.font.height) * 0.5 + ui.paint.font.ascent;
	}

	function fits(high:Float):Bool {
		if (pen + high <= floor) return true;
		dropped++;
		return false;
	}

	inline function inside(x:Float, y:Float, wide:Float, high:Float):Bool {
		return ui.pointerX >= x && ui.pointerX < x + wide
			&& ui.pointerY >= y && ui.pointerY < y + high;
	}

	function hit(x:Float, y:Float, wide:Float, high:Float):Bool {
		if (!ui.freeReleased) return false;
		if (!inside(x, y, wide, high)) return false;
		return ui.freePressedX >= x && ui.freePressedX < x + wide
			&& ui.freePressedY >= y && ui.freePressedY < y + high;
	}
}

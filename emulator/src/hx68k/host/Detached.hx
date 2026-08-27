package hx68k.host;

import hx68k.debug.View;
import hx68k.host.sdl.Sdl;
import hx68k.host.sdl.Window;
import hx68k.host.sdl.Canvas;

@:unreflective
class Detached {
	public final view:View;
	public final id:Int;

	public var closed(default, null):Bool = false;

	final window:cpp.Star<Window>;
	final renderer:cpp.Star<Canvas>;
	final paint:Paint;

	var said:Array<hx68k.debug.Row> = [];

	public function new(view:View) {
		this.view = view;

		window = Sdl.createWindow("hx68k  " + view.title(), 560, 420);
		id = Sdl.windowID(window);
		renderer = Sdl.createRenderer(window, 0);
		paint = Paint.on(renderer, Font.on(renderer));
	}

	public function say(rows:Array<hx68k.debug.Row>):Void {
		said = rows;
	}

	public function shut():Void {
		if (!closed) {
			Sdl.destroyRenderer(renderer);
			Sdl.destroyWindow(window);
		}
		closed = true;
	}

	public function draw():Void {
		if (closed) return;

		Sdl.renderClear(renderer, 0.08, 0.09, 0.11, 1);

		final step = paint.font.height;
		var y = step * 1.5;

		paint.text(view.title(), 10, y, Ui.DIM);
		y += step;

		final height = Sdl.windowHeight(window);

		for (row in said) {
			y += step;
			if (y > height - 4) break;
			paint.text(row.toString(), 10, y, Ui.INK);
		}

		paint.flush();
		Sdl.renderPresent(renderer);
	}
}

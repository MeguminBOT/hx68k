package hx68k.host;

import hx68k.debug.View;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.Window;

class Detached {
	public final view:View;
	public final window:Window;

	public var closed(default, null):Bool = false;

	final path:String;

	var paint:Null<Paint> = null;
	var said:Array<hx68k.debug.Row> = [];

	public function new(application:Application, view:View, path:String) {
		this.view = view;
		this.path = path;

		window = application.createWindow({
			title: "hx68k  " + view.title(),
			width: 560,
			height: 420,
			resizable: true
		});

		window.onRender.add(draw);
		window.onClose.add(() -> closed = true);
	}

	public function say(rows:Array<hx68k.debug.Row>):Void {
		said = rows;
	}

	public function shut():Void {
		if (!closed) window.close();
		closed = true;
	}

	function draw(context:RenderContext):Void {
		final gl = context.webgl;
		if (gl == null || closed) return;

		if (paint == null) paint = new Paint(gl, new Font(gl, path, 14));

		gl.viewport(0, 0, window.width, window.height);
		gl.clearColor(0.08, 0.09, 0.11, 1);
		gl.clear(gl.COLOR_BUFFER_BIT);

		final step = paint.font.height;
		var y = step * 1.5;

		paint.text(view.title(), 10, y, Ui.DIM);
		y += step;

		for (row in said) {
			y += step;
			if (y > window.height - 4) break;
			paint.text(row.toString(), 10, y, Ui.INK);
		}

		paint.flush(window.width, window.height);
	}
}

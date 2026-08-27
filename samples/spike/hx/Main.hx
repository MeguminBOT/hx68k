package;

import md.Boot;
import md.Font;
import md.Colors;
import md.Pool;
import md.System;

class Main {
	static var frame:Int = 0;
	@:md.volatile static var live:Int = 0;
	@:md.volatile static var sum:Int = 0;

	@:md.main
	static function main():Void {
		Boot.begin();
		Font.loadNormal(1);
		Colors.setColor(15, 0x0EEE);
		Font.setPalette(0);
		Font.write("HX68K SPIKE", 12, 12);
		Boot.show();

		var head:Entity = null;
		var i = 0;
		while (i < 64) {
			final e = new Entity(i << 2, i + 1);
			e.next = head;
			head = e;
			i++;
		}
		live = Pool.live(Entity);

		while (true) {
			frame++;

			var e = head;
			var acc = 0;
			while (e != null) {
				e.update();
				acc += e.x;
				e = e.next;
			}
			sum = acc;

			Colors.setColor(0, ramp(frame));
			System.nextFrame();
		}
	}

	static function ramp(t:Int):Int {
		final phase = (t >> 2) & 31;
		final level = phase < 16 ? phase : 31 - phase;
		return level << 1;
	}
}

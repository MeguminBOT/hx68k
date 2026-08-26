package;

import md.Palette;
import md.Pool;
import md.System;
import md.sgdk.Vdp;

class Main {
	static var frame:Int = 0;
	@:md.volatile static var live:Int = 0;
	@:md.volatile static var sum:Int = 0;

	@:md.main
	static function main():Void {
		Vdp.drawText("HX68K SPIKE", 12, 12);

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

			Palette.setColour(0, ramp(frame));
			System.doVBlankProcess();
		}
	}

	static function ramp(t:Int):Int {
		final phase = (t >> 2) & 31;
		final level = phase < 16 ? phase : 31 - phase;
		return level << 1;
	}
}

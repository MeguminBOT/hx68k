package;

import md.Probe;
import md.System;

class Main {
	@:md.volatile static var total:Int = 0;

	@:md.volatile static var seen:Int = 0;

	@:md.main
	static function main():Void {
		accumulate(4);

		masked(0x0048);

		Probe.report(total);
		Probe.done();

		while (true) {
			System.doVBlankProcess();
		}
	}

	static function masked(value:Int):Int {
		final held:Bool = (value & 0x40) != 0;
		var step:Int = 0;

		while (step < 3) {
			seen = seen + (held ? 2 : 1);
			step++;
		}

		return seen;
	}

	static function accumulate(n:Int):Void {
		total = 0;

		var i = 1;
		while (i <= n) {
			total = total + i + i;
			i++;
		}
	}
}

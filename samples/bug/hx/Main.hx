package;

import md.Probe;
import md.sgdk.System;

class Main {
	@:md.volatile static var total:Int = 0;

	@:md.main
	static function main():Void {
		accumulate(4);

		Probe.report(total);
		Probe.done();

		while (true) {
			System.doVBlankProcess();
		}
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

package;

import md.Boot;
import md.Probe;
import md.System;
import md.Vector;

typedef Handler = Int->Int;

class Main {
	static inline final SLOTS = 4;
	static inline final WAIT = 5;

	@:md.size(4) static var handlers:Vector<Handler>;

	static var registered:Int = 0;
	static var offset:Int = 100;

	@:md.volatile static var ticks:Int = 0;

	@:md.main
	static function main():Void {
		Boot.begin();
		Boot.listen();

		register(twice);
		register(negate);
		register(value -> value + offset);

		Probe.report(dispatch(5));
		Probe.report(registered);

		while (ticks < WAIT) {
			System.doVBlankProcess();
		}

		final seen = ticks;
		Probe.report(seen >= WAIT ? 1 : 0);
		Probe.report(seen);
		Probe.report(run(twice, 21));
		Probe.done();

		while (true) {
			System.doVBlankProcess();
		}
	}

	static function register(handler:Handler):Void {
		handlers[registered] = handler;
		registered++;
	}

	static function dispatch(value:Int):Int {
		var total = 0;
		var i = 0;

		while (i < registered) {
			total = total + handlers[i](value);
			i++;
		}

		return total;
	}

	static function run(handler:Handler, value:Int):Int {
		return handler(value);
	}

	static function twice(value:Int):Int {
		return value * 2;
	}

	static function negate(value:Int):Int {
		return -value;
	}

	@:md.vertical
	static function count():Void {
		ticks = ticks + 1;
	}
}

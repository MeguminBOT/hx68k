package;

import md.Int16;
import md.Native;
import md.Probe;
import md.System;
import md.Vector;

class Main {
	static inline final CELLS = 256;
	static inline final ENTITIES = 64;

	@:md.size(256) static var narrowCells:Vector<Int16>;
	@:md.size(256) static var wideCells:Vector<Int>;

	static var head:Entity;

	@:md.main
	static function main():Void {
		final seed = Probe.seed();

		build();
		System.disableInterrupts();

		Probe.mark();
		final native = Native.arrayPass(seed);
		Probe.mark();
		final narrow = narrowPass(seed);
		Probe.mark();
		final wide = widePass(seed);
		Probe.mark();
		final nativeWide = Native.widePass(seed);
		Probe.mark();
		final objects = objectPass(seed);
		Probe.mark();
		final nativeObjects = Native.objectPass(seed);
		Probe.mark();

		System.enableInterrupts();

		Probe.report(narrow);
		Probe.report(native);
		Probe.report(wide);
		Probe.report(nativeWide);
		Probe.report(objects);
		Probe.report(nativeObjects);
		Probe.done();

		while (true) {
			System.doVBlankProcess();
		}
	}

	static function build():Void {
		var i = 0;
		while (i < CELLS) {
			final value = (i * 7 + 13) & 0x3FF;
			narrowCells[i] = value;
			wideCells[i] = value;
			i++;
		}

		var previous:Entity = null;
		var made = 0;
		while (made < ENTITIES) {
			final entity = new Entity(made * 3 + 1, made + 2);
			if (previous == null) head = entity else previous.next = entity;
			previous = entity;
			made++;
		}

		Native.fill();
		Native.build();
	}

	static function narrowPass(seed:Int16):Int {
		var total = 0;
		var i:Int16 = 0;

		while (i < CELLS) {
			var value:Int16 = narrowCells[i];
			value = value + i - seed;
			if (value > 1000) value = value - 1000;
			narrowCells[i] = value;
			total = total + value;
			i = i + 1;
		}

		return total;
	}

	static function widePass(seed:Int):Int {
		var total = 0;
		var i = 0;

		while (i < CELLS) {
			var value:Int = wideCells[i];
			value = value + i - seed;
			if (value > 1000) value = value - 1000;
			wideCells[i] = value;
			total = total + value;
			i = i + 1;
		}

		return total;
	}

	static function objectPass(seed:Int16):Int {
		var total = 0;
		var entity = head;

		while (entity != null) {
			entity.step(seed);
			total = total + entity.value;
			entity = entity.next;
		}

		return total;
	}
}

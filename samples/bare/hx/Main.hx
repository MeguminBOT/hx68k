package;

import md.Boot;
import md.Fix16;
import md.Maths;
import md.Memory;
import md.Palette;
import md.Patterns;
import md.Plane;
import md.Probe;
import md.Sram;
import md.Tilemap;
import md.Trig;
import md.UInt32;
import md.Vector;
import md.hw.Vdp as Ports;

class Main {
	static inline final PATTERN = 1;

	static var carried:Int = 0x1234;

	@:md.volatile static var ticks:Int = 0;

	@:md.size(8) static var block:Vector<UInt32>;

	@:md.size(4) static var cleared:Vector<UInt32>;

	@:md.main
	static function main():Void {
		Boot.begin();

		var i = 0;
		while (i < 8) {
			block[i] = 0x11111111;
			i++;
		}

		Palette.setColour(0, 0x0200);
		Palette.setColour(1, 0x0EEE);

		Patterns.set(PATTERN, block, 1);
		Tilemap.fill(Plane.A, Tilemap.entry(PATTERN, 0, false, false, false), 2, 2, 8, 4);

		Boot.show();
		Boot.listen();

		while (ticks < 4) {}

		Probe.report(carried);
		Probe.report(cleared[0]);
		Probe.report(readCram(1));
		Probe.report(readVram(Tilemap.address(Plane.A, 2, 2)));
		Probe.report(readVram(Patterns.address(PATTERN)));
		Probe.report(Tilemap.columns());
		Probe.report(ticks >= 4 ? 1 : 0);
		Probe.report(Maths.sqrt(Fix16.of(16)));
		Probe.report(Maths.log2(1000));
		Probe.report(Maths.nextPowerOfTwo(1000));
		Probe.report(Maths.distance(30, 40));
		Probe.report(Trig.sin(90));
		Probe.report(Trig.sin(30));
		Probe.report(Trig.sin(210));
		Probe.report(Trig.cos(0));

		Sram.enable();
		Sram.writeLong(0, 0x1234ABCD);
		Sram.writeByte(8, 0x5A);
		Probe.report(Sram.readWord(0));
		Probe.report(Sram.readWord(2));
		Probe.report(Sram.readByte(8));

		Sram.enableReadOnly();
		Sram.writeByte(8, 0xFF);
		Probe.report(Sram.readByte(8));

		Sram.enable();
		Probe.report(Sram.readLong(0));
		Sram.disable();
		Probe.report(Memory.readU8(Sram.BASE));
		Probe.done();

		while (true) {}
	}

	@:md.vertical
	static function onVertical():Void {
		ticks++;
	}

	static function readVram(at:Int):Int {
		Ports.address(Ports.VRAM_READ, at);
		return Ports.read();
	}

	static function readCram(index:Int):Int {
		Ports.address(Ports.CRAM_READ, index * 2);
		return Ports.read() & Palette.MASK;
	}
}

package;

import md.Boot;
import md.Palette;
import md.Patterns;
import md.Plane;
import md.Probe;
import md.Tilemap;
import md.UInt32;
import md.Vector;
import md.hw.Vdp as Ports;

class Main {
	static inline final PATTERN = 1;

	static var carried:Int = 0x1234;

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

		var frame = 0;
		while (frame < 4) {
			Boot.waitVertical();
			frame++;
		}

		Probe.report(carried);
		Probe.report(cleared[0]);
		Probe.report(readCram(1));
		Probe.report(readVram(Tilemap.address(Plane.A, 2, 2)));
		Probe.report(readVram(Patterns.address(PATTERN)));
		Probe.report(Tilemap.columns());
		Probe.done();

		while (true) {
			Boot.waitVertical();
		}
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

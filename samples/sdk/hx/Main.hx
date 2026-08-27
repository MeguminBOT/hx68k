package;

import md.Boot;
import md.Dma;
import md.DmaTarget;
import md.Fix16;
import md.Font;
import md.Pads;
import md.Maths;
import md.Colors;
import md.Plane;
import md.Probe;
import md.System;
import md.Tilemap;
import md.UInt16;
import md.Vdp;
import md.Vector;
import md.hw.Vdp as Ports;

class Main {
	static inline final TILE = 0x0021;
	static inline final FILL = 0x0055;
	static inline final COLOR = 0x0246;
	static inline final TARGET = 0x2000;

	static inline final QUEUED = 0x2100;

	@:md.size(4) static var words:Vector<UInt16>;

	@:md.main
	static function main():Void {
		Boot.begin();
		Font.loadNormal(1);

		Vdp.setBackgroundColor(2);
		Colors.setColor(1, COLOR);

		Tilemap.setCell(Plane.A, TILE, 3, 4);
		Tilemap.fill(Plane.A, FILL, 10, 10, 2, 2);
		Font.write("SDK", 1, 2);

		words[0] = 0xA0A1;
		words[1] = 0xA2A3;
		words[2] = 0xA4A5;
		words[3] = 0xA6A7;
		Dma.transferFrom(DmaTarget.Vram, words, TARGET, 4, 2);

		Dma.queueFrom(DmaTarget.Vram, words, QUEUED, 4, 2);

		Pads.init();

		var frame = 0;
		while (frame < 4) {
			System.nextFrame();
			Pads.update();
			frame++;
		}

		Boot.show();

		Probe.report(Vdp.register(7));
		Probe.report(Colors.color(1));
		Probe.report(readVram(Tilemap.address(Plane.A, 3, 4)));
		Probe.report(readVram(Tilemap.address(Plane.A, 11, 11)));
		Probe.report(readVram(TARGET + 4));
		Probe.report(readVram(QUEUED + 4));
		Probe.report(Pads.held(0));
		Probe.report(Pads.portType(0));
		Probe.report(Pads.padType(0));
		Probe.report(System.isNtsc() ? 1 : 0);
		Probe.report(Maths.sqrt(Fix16.of(16)));
		Probe.done();

		while (true) {
			System.nextFrame();
		}
	}

	static function readVram(at:Int):Int {
		Ports.address(Ports.VRAM_READ, at);
		return Ports.read();
	}
}

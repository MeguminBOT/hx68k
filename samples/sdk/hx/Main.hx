package;

import md.DmaTarget;
import md.Fix16;

import md.sgdk.Maths;
import md.sgdk.Dma;
import md.sgdk.Joy;
import md.sgdk.Palette;
import md.sgdk.Tilemap;
import md.Plane;
import md.Probe;
import md.sgdk.System;
import md.Transfer;
import md.UInt16;
import md.sgdk.Vdp;
import md.Vector;
import md.hw.Vdp as Ports;

class Main {
	static inline final TILE = 0x0021;
	static inline final FILL = 0x0055;
	static inline final COLOUR = 0x0246;
	static inline final TARGET = 0x2000;

	@:md.size(4) static var words:Vector<UInt16>;

	@:md.main
	static function main():Void {
		Vdp.setBackgroundColour(2);
		Palette.setColour(1, COLOUR);

		Tilemap.setCell(Plane.A, TILE, 3, 4);
		Tilemap.fill(Plane.A, FILL, 10, 10, 2, 2);
		Vdp.drawText("SDK", 1, 2);

		words[0] = 0xA0A1;
		words[1] = 0xA2A3;
		words[2] = 0xA4A5;
		words[3] = 0xA6A7;
		Dma.transfer(Transfer.Direct, DmaTarget.Vram, words, TARGET, 4, 2);

		Joy.init();

		var frame = 0;
		while (frame < 4) {
			System.doVBlankProcess();
			frame++;
		}

		Probe.report(Vdp.register(7));
		Probe.report(Palette.colour(1));
		Probe.report(readVram(Tilemap.address(Plane.A, 3, 4)));
		Probe.report(readVram(Tilemap.address(Plane.A, 11, 11)));
		Probe.report(readVram(TARGET + 4));
		Probe.report(Joy.read(0));
		Probe.report(Joy.portType(0));
		Probe.report(Joy.padType(0));
		Probe.report(System.isNtsc());
		Probe.report(Maths.sqrt(Fix16.of(16)));
		Probe.done();

		while (true) {
			System.doVBlankProcess();
		}
	}

	static function readVram(at:Int):Int {
		Ports.address(Ports.VRAM_READ, at);
		return Ports.read();
	}
}

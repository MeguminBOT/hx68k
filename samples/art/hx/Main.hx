package;

import md.Memory;
import md.Palette;
import md.Patterns;
import md.Plane;
import md.Probe;
import md.Sprite;
import md.System;
import md.Tilemap;
import md.Vdp;
import md.hw.Vdp as Ports;

class Main {
	static inline final NATIVE = 400;

	@:md.main
	static function main():Void {
		Sprite.init();

		Vdp.drawImage(Plane.A, Art.blocks, 0, 0);
		Palette.setFromResource(0, Art.blockPalette);

		Sprite.add(Art.diamond, 100, 80, 0);
		Sprite.update();

		Patterns.setFromResource(NATIVE, Art.blockTiles);
		Tilemap.setCell(Plane.B, Tilemap.entry(NATIVE, 0, false, false, false), 3, 5);
		Tilemap.fill(Plane.B, Tilemap.entry(NATIVE + 1, 1, true, false, true), 8, 2, 7, 3);
		Tilemap.fillIncrementing(Plane.B, 300, 0, 10, 4, 2);

		var frame = 0;
		while (frame < 4) {
			System.doVBlankProcess();
			frame++;
		}

		final music = Memory.addressOf(Art.tune);

		Probe.report(readCram(1));
		Probe.report(readCram(2));
		Probe.report(readVram(Tilemap.address(Plane.A, 0, 0)));
		Probe.report(readVram(Vdp.spriteListAddress()));
		Probe.report((music & 0xFFFFFF) < 0x400000 ? 1 : 0);
		Probe.report(Memory.readU16(music + 0x108));
		Probe.report(Tilemap.cell(Plane.B, 3, 5));
		Probe.report(Tilemap.cell(Plane.B, 10, 3));
		Probe.report(Tilemap.cell(Plane.B, 14, 4));
		Probe.report(Tilemap.cell(Plane.B, 2, 11));
		Probe.report(Tilemap.address(Plane.B, 3, 5));
		Probe.report(Tilemap.columns());
		Probe.report(readVram(Patterns.address(NATIVE + 1)));
		Probe.report(readVram(Patterns.address(NATIVE + 15)));
		Probe.done();

		while (true) {
			System.doVBlankProcess();
		}
	}

	static function readVram(at:Int):Int {
		Ports.address(Ports.VRAM_READ, at);
		return Ports.read();
	}

	static function readCram(index:Int):Int {
		Ports.address(Ports.CRAM_READ, index * 2);
		return Ports.read();
	}
}

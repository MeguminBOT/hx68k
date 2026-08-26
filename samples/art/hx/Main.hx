package;

import md.Memory;
import md.Palette;
import md.Plane;
import md.Probe;
import md.Sprite;
import md.System;
import md.Vdp;
import md.hw.Vdp as Ports;

class Main {
	@:md.main
	static function main():Void {
		Sprite.init();

		Vdp.drawImage(Plane.A, Art.blocks, 0, 0);
		Palette.setFromResource(0, Art.blockPalette);

		Sprite.add(Art.diamond, 100, 80, 0);
		Sprite.update();

		var frame = 0;
		while (frame < 4) {
			System.doVBlankProcess();
			frame++;
		}

		final music = Memory.addressOf(Art.tune);

		Probe.report(readCram(1));
		Probe.report(readCram(2));
		Probe.report(readVram(Vdp.planeAddress(Plane.A, 0, 0)));
		Probe.report(readVram(Vdp.spriteListAddress()));
		Probe.report((music & 0xFFFFFF) < 0x400000 ? 1 : 0);
		Probe.report(Memory.readU16(music + 0x108));
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

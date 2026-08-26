package;

import md.Dma;
import md.DmaTarget;
import md.Joy;
import md.Memory;
import md.Palette;
import md.Patterns;
import md.Plane;
import md.Probe;
import md.SpriteTable;
import md.sgdk.System;
import md.Tilemap;
import md.Unpack;
import md.UInt16;
import md.UInt32;
import md.Vector;
import md.sgdk.Sprite;
import md.sgdk.Vdp;
import md.hw.Vdp as Ports;

class Main {
	static inline final NATIVE = 400;

	@:md.size(4) static var words:Vector<UInt16>;

	@:md.size(32) static var scratch:Vector<UInt32>;

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
		Probe.report(readVram(SpriteTable.base()));
		Probe.report((music & 0xFFFFFF) < 0x400000 ? 1 : 0);
		Probe.report(Memory.readU16(music + 0x108));

		final bytes = Memory.addressOf(Art.table);

		Probe.report(bytes & 1);
		Probe.report(Memory.readU8(bytes));
		Probe.report(Memory.readU8(bytes + 3));
		Probe.report(Memory.readU8(bytes + 99));
		Probe.report(Memory.readU8(bytes + 100));
		Probe.report(Memory.readU8(bytes + 111));

		final room = Memory.addressOf(scratch);

		final grew = Unpack.aplib(Memory.addressOf(Art.squeezed), room);
		Probe.report(grew);
		Probe.report(Memory.readU8(room));
		Probe.report(Memory.readU8(room + 3));
		Probe.report(Memory.readU8(room + 99));
		Probe.report(Memory.readU8(room + 111));

		final widened = Unpack.lz4w(Memory.addressOf(Art.wordSqueezed), room);
		Probe.report(widened);
		Probe.report(Memory.readU8(room));
		Probe.report(Memory.readU8(room + 3));
		Probe.report(Memory.readU8(room + 99));
		Probe.report(Memory.readU8(room + 111));
		Probe.report(Tilemap.cell(Plane.B, 3, 5));
		Probe.report(Tilemap.cell(Plane.B, 10, 3));
		Probe.report(Tilemap.cell(Plane.B, 14, 4));
		Probe.report(Tilemap.cell(Plane.B, 2, 11));
		Probe.report(Tilemap.address(Plane.B, 3, 5));
		Probe.report(Tilemap.columns());
		Probe.report(readVram(Patterns.address(NATIVE + 1)));
		Probe.report(readVram(Patterns.address(NATIVE + 15)));

		SpriteTable.set(0, 100, 96, SpriteTable.size(2, 2),
			SpriteTable.attribute(NATIVE + 3, 1, false, false, false), 0);
		SpriteTable.set(1, 140, 90, SpriteTable.size(3, 2),
			SpriteTable.attribute(NATIVE + 5, 2, true, true, false), 0);
		SpriteTable.chain(0, 2);
		SpriteTable.update(2);

		Probe.report(readVram(SpriteTable.base()));
		Probe.report(readVram(SpriteTable.base() + 2));
		Probe.report(readVram(SpriteTable.base() + 4));
		Probe.report(readVram(SpriteTable.base() + 6));
		Probe.report(readVram(SpriteTable.base() + 10));
		Probe.report(readVram(SpriteTable.base() + 12));

		words[0] = 0xA0A1;
		words[1] = 0xA2A3;
		words[2] = 0xA4A5;
		words[3] = 0xA6A7;

		Dma.fillVram(0x8000, 8, 0x5A, 1);
		Dma.wait();
		Dma.transferFrom(DmaTarget.Vram, words, 0x8100, 4, 2);
		Dma.wait();
		Dma.copyVram(0x8000, 0x8200, 4, 1);
		Dma.wait();
		Dma.queueFrom(DmaTarget.Vram, words, 0x8300, 4, 2);
		Dma.flush();
		Dma.wait();

		Probe.report(readVram(0x8000));
		Probe.report(readVram(0x8100));
		Probe.report(readVram(0x8106));
		Probe.report(readVram(0x8200));
		Probe.report(readVram(0x8300));

		Joy.init();
		Joy.update();
		final arrived = Joy.pressed(0);
		Joy.update();

		Probe.report(arrived);
		Probe.report(Joy.read(0));
		Probe.report(Joy.pressed(0));
		Probe.report(Joy.portType(0));
		Probe.report(Joy.padType(0));
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

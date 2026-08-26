package;

import md.Int16;
import md.Native;
import md.Dma;
import md.Fm;
import md.Joy;
import md.DmaTarget;
import md.Palette;
import md.Psg;
import md.Patterns;
import md.Plane;
import md.Probe;
import md.sgdk.System;
import md.sgdk.Vdp;
import md.Transfer;
import md.UInt16;
import md.Vector;
import md.SpriteTable;
import md.Tilemap;
import md.UInt32;
import md.sgdk.Dma as SgdkDma;
import md.sgdk.Fm as SgdkFm;
import md.sgdk.Joy as SgdkJoy;
import md.sgdk.Palette as SgdkPalette;
import md.sgdk.Psg as SgdkPsg;
import md.sgdk.SpriteTable as SgdkSpriteTable;
import md.sgdk.Tilemap as SgdkTilemap;

class Main {
	static inline final CELLS = 256;
	static inline final ENTITIES = 64;

	static inline final LOADS = 64;

	static inline final CELL_WRITES = 64;

	static inline final FILLS = 8;

	static inline final FILL_COLUMNS = 40;

	static inline final FILL_ROWS = 28;

	static inline final PATTERN_LOADS = 8;

	static inline final PATTERNS = 16;

	static inline final PATTERN_BASE = 600;

	static inline final SPRITE_FRAMES = 8;

	static inline final SPRITES = 40;

	static inline final DMA_FRAMES = 8;

	static inline final SOUND_WRITES = 64;

	static inline final PAD_READS = 64;

	@:md.size(256) static var narrowCells:Vector<Int16>;
	@:md.size(256) static var wideCells:Vector<Int>;
	@:md.size(16) static var shades:Vector<UInt16>;
	@:md.size(128) static var patternWords:Vector<UInt32>;

	static var head:Entity;

	@:md.main
	static function main():Void {
		final seed = Probe.seed();

		build();
		System.disableInterrupts();
		Vdp.setEnable(false);

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
		paletteInHaxe();
		Probe.mark();
		paletteInSgdk();
		Probe.mark();
		cellsInHaxe();
		Probe.mark();
		cellsInSgdk();
		Probe.mark();
		fillInHaxe();
		Probe.mark();
		fillInSgdk();
		Probe.mark();
		patternsInHaxe();
		Probe.mark();
		patternsInSgdk();
		Probe.mark();
		spritesInHaxe();
		Probe.mark();
		spritesInSgdk();
		Probe.mark();
		spriteTransferInHaxe();
		Probe.mark();
		spriteTransferInSgdk();
		Probe.mark();
		dmaInHaxe();
		Probe.mark();
		dmaInSgdk();
		Probe.mark();
		psgInHaxe();
		Probe.mark();
		psgInSgdk();
		Probe.mark();
		fmInHaxe();
		Probe.mark();
		fmInSgdk();
		Probe.mark();
		padInHaxe();
		Probe.mark();
		padInSgdk();
		Probe.mark();

		Vdp.setEnable(true);
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

		var shade = 0;
		while (shade < 16) {
			shades[shade] = (shade * 0x111) & 0x0EEE;
			shade++;
		}

		var word = 0;
		while (word < 128) {
			patternWords[word] = (word << 24) | (word << 16) | (word << 8) | word;
			word++;
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

	static function paletteInHaxe():Void {
		var n = 0;
		while (n < LOADS) {
			Palette.setColours(0, shades, 16);
			n++;
		}
	}

	static function paletteInSgdk():Void {
		var n = 0;
		while (n < LOADS) {
			SgdkPalette.setColours(0, shades, 16, Transfer.Cpu);
			n++;
		}
	}

	static function cellsInHaxe():Void {
		var n = 0;
		while (n < CELL_WRITES) {
			Tilemap.setCell(Plane.A, n, n & 31, n >> 5);
			n++;
		}
	}

	static function cellsInSgdk():Void {
		var n = 0;
		while (n < CELL_WRITES) {
			SgdkTilemap.setCell(Plane.A, n, n & 31, n >> 5);
			n++;
		}
	}

	static function fillInHaxe():Void {
		var n = 0;
		while (n < FILLS) {
			Tilemap.fill(Plane.A, 1, 0, 0, FILL_COLUMNS, FILL_ROWS);
			n++;
		}
	}

	static function fillInSgdk():Void {
		var n = 0;
		while (n < FILLS) {
			SgdkTilemap.fill(Plane.A, 1, 0, 0, FILL_COLUMNS, FILL_ROWS);
			n++;
		}
	}

	static function patternsInHaxe():Void {
		var n = 0;
		while (n < PATTERN_LOADS) {
			Patterns.set(PATTERN_BASE, patternWords, PATTERNS);
			n++;
		}
	}

	static function patternsInSgdk():Void {
		var n = 0;
		while (n < PATTERN_LOADS) {
			SgdkTilemap.setPatterns(patternWords, PATTERN_BASE, PATTERNS, Transfer.Cpu);
			n++;
		}
	}

	static function spritesInHaxe():Void {
		var frame = 0;
		while (frame < SPRITE_FRAMES) {
			var n = 0;
			while (n < SPRITES) {
				SpriteTable.setPosition(n, n * 5, frame * 3);
				n++;
			}
			SpriteTable.update(SPRITES);
			frame++;
		}
	}

	static function spritesInSgdk():Void {
		var frame = 0;
		while (frame < SPRITE_FRAMES) {
			var n = 0;
			while (n < SPRITES) {
				SgdkSpriteTable.setPosition(n, n * 5, frame * 3);
				n++;
			}
			SgdkSpriteTable.update(SPRITES, Transfer.Cpu);
			frame++;
		}
	}

	static function spriteTransferInHaxe():Void {
		var frame = 0;
		while (frame < SPRITE_FRAMES) {
			SpriteTable.update(SPRITES);
			frame++;
		}
	}

	static function spriteTransferInSgdk():Void {
		var frame = 0;
		while (frame < SPRITE_FRAMES) {
			SgdkSpriteTable.update(SPRITES, Transfer.Cpu);
			frame++;
		}
	}

	static function dmaInHaxe():Void {
		var frame = 0;
		while (frame < DMA_FRAMES) {
			Dma.queueFrom(DmaTarget.Vram, shades, 0x8000, 16, 2);
			Dma.queueFrom(DmaTarget.Vram, shades, 0x8100, 16, 2);
			Dma.queueFrom(DmaTarget.Vram, shades, 0x8200, 16, 2);
			Dma.queueFrom(DmaTarget.Vram, shades, 0x8300, 16, 2);
			Dma.flush();
			Dma.wait();
			frame++;
		}
	}

	static function dmaInSgdk():Void {
		var frame = 0;
		while (frame < DMA_FRAMES) {
			SgdkDma.queue(DmaTarget.Vram, shades, 0x8000, 16, 2);
			SgdkDma.queue(DmaTarget.Vram, shades, 0x8100, 16, 2);
			SgdkDma.queue(DmaTarget.Vram, shades, 0x8200, 16, 2);
			SgdkDma.queue(DmaTarget.Vram, shades, 0x8300, 16, 2);
			SgdkDma.flush();
			SgdkDma.wait();
			frame++;
		}
	}

	static function psgInHaxe():Void {
		var n = 0;
		while (n < SOUND_WRITES) {
			Psg.setAttenuation(n & 3, n & 0x0F);
			Psg.setTone(n & 3, n * 5);
			n++;
		}
	}

	static function psgInSgdk():Void {
		var n = 0;
		while (n < SOUND_WRITES) {
			SgdkPsg.setAttenuation(n & 3, n & 0x0F);
			SgdkPsg.setTone(n & 3, n * 5);
			n++;
		}
	}

	static function fmInHaxe():Void {
		var n = 0;
		while (n < SOUND_WRITES) {
			Fm.setRegister(0, 0x40 + (n & 3), n & 0x7F);
			n++;
		}
	}

	static function fmInSgdk():Void {
		var n = 0;
		while (n < SOUND_WRITES) {
			SgdkFm.setRegister(0, 0x40 + (n & 3), n & 0x7F);
			n++;
		}
	}

	static function padInHaxe():Void {
		Joy.init();

		var n = 0;
		while (n < PAD_READS) {
			Joy.update();
			n++;
		}
	}

	static function padInSgdk():Void {
		SgdkJoy.init();

		var n = 0;
		while (n < PAD_READS) {
			SgdkJoy.update();
			n++;
		}
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

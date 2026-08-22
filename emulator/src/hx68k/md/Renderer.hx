package hx68k.md;

import haxe.ds.Vector;

class Renderer {
	public static inline final MAX_WIDTH = 320;
	public static inline final MAX_HEIGHT = 240;

	public static inline final SHADOW = 0x200;
	public static inline final HIGHLIGHT = 0x400;

	static inline final PRIORITY = 0x100;

	public final pixels:Vector<Int> = new Vector<Int>(MAX_WIDTH * MAX_HEIGHT);
	public var width(default, null):Int = MAX_WIDTH;
	public var height(default, null):Int = 224;

	final planeA:Vector<Int> = new Vector<Int>(MAX_WIDTH);
	final planeB:Vector<Int> = new Vector<Int>(MAX_WIDTH);
	final sprites:Vector<Int> = new Vector<Int>(MAX_WIDTH);

	public function new() {
		for (i in 0...pixels.length) pixels[i] = 0;
	}

	public function line(vdp:Vdp, y:Int):Void {
		width = wide(vdp) ? 320 : 256;
		height = (vdp.registers[1] & 0x08) != 0 ? 240 : 224;
		if (y >= height) return;

		layer(vdp, y, planeA, true);
		layer(vdp, y, planeB, false);
		sprite(vdp, y);
		compose(vdp, y);
	}

	static inline function wide(vdp:Vdp):Bool {
		return (vdp.registers[12] & 0x81) == 0x81;
	}

	static inline function readVram(vdp:Vdp, at:Int):Int {
		final even = at & 0xFFFE;
		return (vdp.vram.get(even) << 8) | vdp.vram.get(even | 1);
	}

	static function cells(code:Int):Int {
		return switch (code & 3) {
			case 0: 32;
			case 1: 64;
			case _: 128;
		}
	}

	static function horizontal(vdp:Vdp, y:Int, front:Bool):Int {
		final base = (vdp.registers[13] & 0x3F) << 10;
		final at = switch (vdp.registers[11] & 0x03) {
			case 0: base;
			case 3: base + y * 4;
			case _: base + (y & ~7) * 4;
		}
		return readVram(vdp, at + (front ? 0 : 2)) & 0x3FF;
	}

	static function vertical(vdp:Vdp, column:Int, front:Bool):Int {
		final index = (vdp.registers[11] & 0x04) != 0 ? (column >> 4) * 2 : 0;
		final slot = index + (front ? 0 : 1);
		return slot < vdp.vsram.length ? vdp.vsram[slot] & 0x3FF : 0;
	}

	static inline function inWindow(vdp:Vdp, x:Int, y:Int):Bool {
		final h = vdp.registers[17];
		final v = vdp.registers[18];
		final rows = (v & 0x80) != 0 ? (y >> 3) >= (v & 0x1F) : (y >> 3) < (v & 0x1F);
		final columns = (h & 0x80) != 0 ? (x >> 4) >= (h & 0x1F) : (x >> 4) < (h & 0x1F);
		return rows || columns;
	}

	function layer(vdp:Vdp, y:Int, out:Vector<Int>, front:Bool):Void {
		final planeBase = front ? (vdp.registers[2] & 0x38) << 10 : (vdp.registers[4] & 0x07) << 13;
		final windowBase = (vdp.registers[3] & (wide(vdp) ? 0x3E : 0x3F)) << 10;
		final windowPitch = wide(vdp) ? 64 : 32;

		final columns = cells(vdp.registers[16]);
		final rows = cells(vdp.registers[16] >> 4);
		final scroll = horizontal(vdp, y, front);

		for (x in 0...width) {
			final window = front && inWindow(vdp, x, y);
			var entry:Int;
			var fine:Int;
			var row:Int;

			if (window) {
				entry = readVram(vdp, windowBase + ((y >> 3) * windowPitch + (x >> 3)) * 2);
				fine = x & 7;
				row = y & 7;
			} else {
				final px = (x - scroll) & (columns * 8 - 1);
				final py = (y + vertical(vdp, x, front)) & (rows * 8 - 1);
				entry = readVram(vdp, planeBase + ((py >> 3) * columns + (px >> 3)) * 2);
				fine = px & 7;
				row = py & 7;
			}

			out[x] = texel(vdp, entry, fine, row);
		}
	}

	static function texel(vdp:Vdp, entry:Int, fine:Int, row:Int):Int {
		final tile = entry & 0x07FF;
		final column = (entry & 0x0800) != 0 ? 7 - fine : fine;
		final scanline = (entry & 0x1000) != 0 ? 7 - row : row;

		final at = (tile * 32 + scanline * 4 + (column >> 1)) & 0xFFFF;
		final byte = vdp.vram.get(at);
		final index = (column & 1) == 0 ? (byte >> 4) & 0x0F : byte & 0x0F;
		if (index == 0) return 0;

		return (((entry >> 13) & 3) << 4 | index) | ((entry & 0x8000) != 0 ? PRIORITY : 0);
	}

	function sprite(vdp:Vdp, y:Int):Void {
		for (x in 0...width) sprites[x] = 0;

		final table = (vdp.registers[5] & (wide(vdp) ? 0x7E : 0x7F)) << 9;
		final maxSprites = wide(vdp) ? 20 : 16;
		final maxPixels = wide(vdp) ? 320 : 256;
		final maxEntries = wide(vdp) ? 80 : 64;

		var link = 0;
		var drawn = 0;
		var covered = 0;

		for (visited in 0...maxEntries) {
			final at = (table + link * 8) & 0xFFFF;
			final top = (readVram(vdp, at) & 0x3FF) - 128;
			final size = vdp.vram.get(at + 2);
			final tall = (size & 0x03) + 1;
			final wideCells = ((size >> 2) & 0x03) + 1;
			final next = vdp.vram.get(at + 3) & 0x7F;
			final attribute = readVram(vdp, at + 4);
			final left = (readVram(vdp, at + 6) & 0x1FF) - 128;

			if (y >= top && y < top + tall * 8) {
				drawn++;
				if (drawn > maxSprites) break;
				if (left == -128 && drawn > 1) break;

				covered += wideCells * 8;
				paint(vdp, y, top, left, tall, wideCells, attribute);
				if (covered >= maxPixels) break;
			}

			link = next;
			if (link == 0) break;
		}
	}

	function paint(vdp:Vdp, y:Int, top:Int, left:Int, tall:Int, wideCells:Int, attribute:Int):Void {
		final tile = attribute & 0x07FF;
		final palette = (attribute >> 13) & 3;
		final priority = (attribute & 0x8000) != 0 ? PRIORITY : 0;
		final flipX = (attribute & 0x0800) != 0;
		final flipY = (attribute & 0x1000) != 0;

		var row = y - top;
		if (flipY) row = tall * 8 - 1 - row;

		for (column in 0...wideCells * 8) {
			final x = left + column;
			if (x < 0 || x >= width || sprites[x] != 0) continue;

			final source = flipX ? wideCells * 8 - 1 - column : column;
			final cell = tile + (source >> 3) * tall + (row >> 3);
			final at = (cell * 32 + (row & 7) * 4 + ((source & 7) >> 1)) & 0xFFFF;
			final byte = vdp.vram.get(at);
			final index = (source & 1) == 0 ? (byte >> 4) & 0x0F : byte & 0x0F;
			if (index == 0) continue;

			sprites[x] = (palette << 4 | index) | priority;
		}
	}

	function compose(vdp:Vdp, y:Int):Void {
		final backdrop = vdp.registers[7] & 0x3F;
		final effects = (vdp.registers[12] & 0x08) != 0;
		final row = y * MAX_WIDTH;

		for (x in 0...width) {
			final a = planeA[x];
			final b = planeB[x];
			var s = sprites[x];

			var mode = effects && (a & PRIORITY) == 0 && (b & PRIORITY) == 0 ? SHADOW : 0;

			if (effects && (s & 0x3F) == 0x3E) {
				mode = HIGHLIGHT;
				s = 0;
			} else if (effects && (s & 0x3F) == 0x3F) {
				mode = SHADOW;
				s = 0;
			} else if (effects && (s & PRIORITY) != 0 && (s & 0x0F) != 0) {
				mode = 0;
			}

			var colour = backdrop;
			if ((b & 0x0F) != 0) colour = b & 0x3F;
			if ((a & 0x0F) != 0 && ((a & PRIORITY) != 0 || (b & PRIORITY) == 0)) colour = a & 0x3F;
			if ((s & 0x0F) != 0 && ((s & PRIORITY) != 0 || ((a & PRIORITY) == 0 && (b & PRIORITY) == 0)))
				colour = s & 0x3F;

			pixels[row + x] = rgb(vdp.cram[colour], mode);
		}
	}

	public static function rgb(entry:Int, mode:Int):Int {
		var r = (entry >> 1) & 7;
		var g = (entry >> 5) & 7;
		var b = (entry >> 9) & 7;

		if (mode == SHADOW) {
			r >>= 1;
			g >>= 1;
			b >>= 1;
		} else if (mode == HIGHLIGHT) {
			r = (r >> 1) + 4;
			g = (g >> 1) + 4;
			b = (b >> 1) + 4;
		}

		return (level(r) << 16) | (level(g) << 8) | level(b);
	}

	static inline function level(value:Int):Int {
		return Std.int(value * 255 / 7);
	}
}

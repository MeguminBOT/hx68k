package hx68k.debug;

import hx68k.md.Vdp;

typedef Layout = {
	final wide:Bool;
	final tall:Bool;
	final display:Bool;
	final effects:Bool;
	final planeA:Int;
	final planeB:Int;
	final window:Int;
	final sprites:Int;
	final horizontalScroll:Int;
	final columns:Int;
	final rows:Int;
	final backdrop:Int;
}

typedef Cell = {
	final tile:Int;
	final palette:Int;
	final priority:Bool;
	final flipX:Bool;
	final flipY:Bool;
}

typedef Sprite = {
	final index:Int;
	final x:Int;
	final y:Int;
	final width:Int;
	final height:Int;
	final link:Int;
	final tile:Int;
	final palette:Int;
	final priority:Bool;
	final flipX:Bool;
	final flipY:Bool;
}

class Viewer {
	public final vdp:Vdp;

	public function new(vdp:Vdp) {
		this.vdp = vdp;
	}

	public function layout():Layout {
		final wide = (vdp.registers[12] & 0x81) == 0x81;

		return {
			wide: wide,
			tall: (vdp.registers[1] & 0x08) != 0,
			display: (vdp.registers[1] & 0x40) != 0,
			effects: (vdp.registers[12] & 0x08) != 0,
			planeA: (vdp.registers[2] & 0x38) << 10,
			planeB: (vdp.registers[4] & 0x07) << 13,
			window: (vdp.registers[3] & (wide ? 0x3E : 0x3F)) << 10,
			sprites: (vdp.registers[5] & (wide ? 0x7E : 0x7F)) << 9,
			horizontalScroll: (vdp.registers[13] & 0x3F) << 10,
			columns: cells(vdp.registers[16]),
			rows: cells(vdp.registers[16] >> 4),
			backdrop: vdp.registers[7] & 0x3F
		};
	}

	public function cell(base:Int, column:Int, row:Int):Cell {
		final entry = word(base + (row * layout().columns + column) * 2);

		return {
			tile: entry & 0x07FF,
			palette: (entry >> 13) & 3,
			priority: (entry & 0x8000) != 0,
			flipX: (entry & 0x0800) != 0,
			flipY: (entry & 0x1000) != 0
		};
	}

	public function spriteList():Array<Sprite> {
		final shape = layout();
		final table = shape.sprites;
		final limit = shape.wide ? 80 : 64;
		final seen = new Map<Int, Bool>();
		final out = new Array<Sprite>();

		var index = 0;
		while (out.length < limit) {
			if (seen.exists(index)) break;
			seen.set(index, true);

			final at = table + index * 8;
			final size = word(at + 2);
			final attribute = word(at + 4);

			out.push({
				index: index,
				y: (word(at) & 0x03FF) - 128,
				x: (word(at + 6) & 0x01FF) - 128,
				width: ((size >> 10) & 3) + 1,
				height: ((size >> 8) & 3) + 1,
				link: size & 0x7F,
				tile: attribute & 0x07FF,
				palette: (attribute >> 13) & 3,
				priority: (attribute & 0x8000) != 0,
				flipX: (attribute & 0x0800) != 0,
				flipY: (attribute & 0x1000) != 0
			});

			index = size & 0x7F;
			if (index == 0) break;
		}

		return out;
	}

	public function tile(index:Int):Array<Int> {
		final out = new Array<Int>();
		final base = index * 32;

		for (row in 0...8) {
			for (pair in 0...4) {
				final byte = vdp.vram.get((base + row * 4 + pair) & 0xFFFF);
				out.push((byte >> 4) & 15);
				out.push(byte & 15);
			}
		}

		return out;
	}

	public function vramUse():Array<Int> {
		final out = new Array<Int>();

		for (block in 0...32) {
			var used = 0;
			for (i in 0...0x800) if (vdp.vram.get(block * 0x800 + i) != 0) used++;
			out.push(used);
		}

		return out;
	}

	public function verticalScroll(column:Int, front:Bool):Int {
		final index = (vdp.registers[11] & 0x04) != 0 ? (column >> 4) * 2 : 0;
		final slot = index + (front ? 0 : 1);
		return slot < vdp.vsram.length ? vdp.vsram[slot] & 0x03FF : 0;
	}

	public function horizontalScroll(line:Int, front:Bool):Int {
		final base = (vdp.registers[13] & 0x3F) << 10;
		final at = switch (vdp.registers[11] & 0x03) {
			case 0: base;
			case 3: base + line * 4;
			case _: base + (line & ~7) * 4;
		}
		return word(at + (front ? 0 : 2)) & 0x03FF;
	}

	inline function word(at:Int):Int {
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
}

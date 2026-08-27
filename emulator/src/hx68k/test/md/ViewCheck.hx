package hx68k.test.md;

import hx68k.debug.md.VdpState;
import hx68k.md.Memory;
import hx68k.md.Renderer;
import hx68k.md.Vdp;

private class Empty implements Memory {
	public function new() {}

	public function readWord(address:Int):Int {
		return 0;
	}
}

class ViewCheck {
	static inline final PLANE_A = 0xC000;
	static inline final PLANE_B = 0xE000;
	static inline final WINDOW = 0xB000;
	static inline final SPRITES = 0xF000;
	static inline final HSCROLL = 0xFC00;

	static var checks = 0;
	static var failures = 0;

	static function main():Void {
		run();
	}

	public static function run():Void {
		layout();
		planeCell();
		planeAddressing();
		spriteOrder();
		spriteLoop();
		spriteGeometry();
		tilePixels();
		scrolls();
		agreesWithTheRenderer();

		Sys.println("");
		Sys.println(checks + " view checks, " + failures + " failures");
		Sys.exit(failures == 0 ? 0 : 1);
	}

	static function check(ok:Bool, what:String):Void {
		checks++;
		if (!ok) failures++;
		Sys.println((ok ? "  ok   " : "  FAIL ") + what);
	}

	static function setup():Vdp {
		final vdp = new Vdp(new Empty());

		register(vdp, 1, 0x44);
		register(vdp, 12, 0x81);
		register(vdp, 2, PLANE_A >> 10);
		register(vdp, 4, PLANE_B >> 13);
		register(vdp, 3, WINDOW >> 10);
		register(vdp, 5, SPRITES >> 9);
		register(vdp, 13, HSCROLL >> 10);
		register(vdp, 15, 2);
		register(vdp, 16, 0x01);
		register(vdp, 7, 10);

		for (i in 0...64) color(vdp, i, ((i & 7) << 1) | (((i >> 3) & 7) << 5));

		return vdp;
	}

	static function layout():Void {
		final shape = new VdpState(setup()).layout();

		check(shape.wide, "register 12 says H40");
		check(!shape.tall, "register 1 says V28");
		check(shape.display, "register 1 says the display is on");
		check(shape.planeA == PLANE_A, "plane A is where register 2 put it");
		check(shape.planeB == PLANE_B, "plane B is where register 4 put it");
		check(shape.window == WINDOW, "the window is where register 3 put it");
		check(shape.sprites == SPRITES, "the sprite table is where register 5 put it");
		check(shape.columns == 64 && shape.rows == 32, "register 16 says 64 cells by 32");
		check(shape.backdrop == 10, "register 7 names the backdrop color");
	}

	static function planeCell():Void {
		final vdp = setup();
		cell(vdp, PLANE_A, 0, 0, 0x9923);

		final entry = new VdpState(vdp).cell(PLANE_A, 0, 0);
		check(entry.tile == 0x123, "the low eleven bits are the tile");
		check(entry.palette == 0, "bits 14 and 13 are the palette");
		check(entry.priority, "bit 15 is priority");
		check(entry.flipX, "bit 11 flips horizontally");
		check(entry.flipY, "bit 12 flips vertically");
	}

	static function planeAddressing():Void {
		final vdp = setup();
		cell(vdp, PLANE_A, 3, 2, 0x0077);

		final viewer = new VdpState(vdp);
		check(viewer.cell(PLANE_A, 3, 2).tile == 0x77, "a cell is found where the plane width puts it");
		check(viewer.cell(PLANE_A, 2, 3).tile == 0, "and not where a square plane would have put it");
	}

	static function spriteOrder():Void {
		final vdp = setup();
		sprite(vdp, 0, 128, 128, 5, 0, 0x0001);
		sprite(vdp, 5, 136, 136, 2, 0, 0x0002);
		sprite(vdp, 2, 144, 144, 0, 0, 0x0003);

		final list = new VdpState(vdp).spriteList();
		check(list.length == 3, "the walk stops where a link of zero ends the list");
		check(list[0].index == 0 && list[1].index == 5 && list[2].index == 2,
			"the list is in link order, not index order");
	}

	static function spriteLoop():Void {
		final vdp = setup();
		sprite(vdp, 0, 128, 128, 3, 0, 0x0001);
		sprite(vdp, 3, 136, 136, 3, 0, 0x0002);

		final list = new VdpState(vdp).spriteList();
		check(list.length == 2, "a link that points at itself stops the walk rather than looping");
	}

	static function spriteGeometry():Void {
		final vdp = setup();
		sprite(vdp, 0, 178, 228, 0, 0x0D, 0xA923);

		final first = new VdpState(vdp).spriteList()[0];
		check(first.y == 50 && first.x == 100, "x and y come back as screen positions");
		check(first.width == 4 && first.height == 2, "the size field is cells across and cells down");
		check(first.tile == 0x123 && first.palette == 1, "the attribute names the tile and the palette");
		check(first.priority && first.flipX && !first.flipY, "and the priority and flip bits");
	}

	static function tilePixels():Void {
		final vdp = setup();
		for (row in 0...8) {
			word(vdp, 1, 32 + row * 4, 0x1234);
			word(vdp, 1, 32 + row * 4 + 2, 0x5678);
		}

		final pixels = new VdpState(vdp).tile(1);
		check(pixels.length == 64, "a tile is 64 palette indices");
		check(pixels[0] == 1 && pixels[1] == 2 && pixels[7] == 8, "each byte is two indices, high nibble first");
		check(pixels[56] == 1 && pixels[63] == 8, "and the last row reads the same way");
	}

	static function scrolls():Void {
		final vdp = setup();
		register(vdp, 11, 0x07);
		word(vdp, 1, HSCROLL + 4 * 4, 0x0011);
		word(vdp, 1, HSCROLL + 4 * 4 + 2, 0x0022);

		final viewer = new VdpState(vdp);
		check(viewer.horizontalScroll(4, true) == 0x11, "per-line scroll reads the line's own entry");
		check(viewer.horizontalScroll(4, false) == 0x22, "and plane B's is the word after it");

		word(vdp, 5, 4, 0x0033);
		word(vdp, 5, 6, 0x0044);
		check(viewer.verticalScroll(16, true) == 0x33, "two-cell scroll reads the column's own entry");
		check(viewer.verticalScroll(16, false) == 0x44, "and plane B's is the slot after it");
	}

	static function agreesWithTheRenderer():Void {
		final vdp = setup();
		for (row in 0...8) {
			word(vdp, 1, 32 + row * 4, 0x1111);
			word(vdp, 1, 32 + row * 4 + 2, 0x1111);
		}
		cell(vdp, PLANE_A, 0, 0, 0x4001);
		vdp.renderer.line(vdp, 0);

		final entry = new VdpState(vdp).cell(PLANE_A, 0, 0);
		final index = entry.palette * 16 + 1;
		check(entry.palette == 2, "the cell the viewer reads is in palette 2");
		check(vdp.renderer.pixels[0] == Renderer.rgb(vdp.cram[index], 0),
			"and the renderer painted that palette's color, so both read the cell the same way");
	}

	static function register(vdp:Vdp, index:Int, value:Int):Void {
		vdp.writeControl(0x8000 | ((index & 0x1F) << 8) | (value & 0xFF));
	}

	static function at(vdp:Vdp, code:Int, address:Int):Void {
		vdp.writeControl(((code & 3) << 14) | (address & 0x3FFF));
		vdp.writeControl(((code >> 2) << 4) | ((address >> 14) & 3));
	}

	static function word(vdp:Vdp, code:Int, address:Int, value:Int):Void {
		at(vdp, code, address);
		vdp.writeData(value);
		settle(vdp);
	}

	static function settle(vdp:Vdp):Void {
		while (vdp.queued > 0 || vdp.running()) vdp.tick(16);
	}

	static function color(vdp:Vdp, index:Int, value:Int):Void {
		word(vdp, 3, index * 2, value);
	}

	static function cell(vdp:Vdp, base:Int, column:Int, row:Int, entry:Int):Void {
		word(vdp, 1, base + (row * 64 + column) * 2, entry);
	}

	static function sprite(vdp:Vdp, index:Int, y:Int, x:Int, link:Int, size:Int, attribute:Int):Void {
		final base = SPRITES + index * 8;
		word(vdp, 1, base, y);
		word(vdp, 1, base + 2, ((size & 0x0F) << 8) | (link & 0x7F));
		word(vdp, 1, base + 4, attribute);
		word(vdp, 1, base + 6, x);
	}
}

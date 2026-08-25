package hx68k.test;

import hx68k.md.Machine;
import hx68k.md.Memory;
import hx68k.md.Renderer;
import hx68k.md.Vdp;

private class Empty implements Memory {
	public function new() {}

	public function readWord(address:Int):Int {
		return 0;
	}
}

class RenderCheck {
	static inline final PLANE_A = 0xC000;
	static inline final PLANE_B = 0xE000;
	static inline final WINDOW = 0xB000;
	static inline final SPRITES = 0xF000;
	static inline final HSCROLL = 0xFC00;

	static var checks = 0;
	static var failures = 0;

	static function main():Void {
		backdrop();
		opaqueTile();
		flippedTile();
		planePriority();
		fullScreenScroll();
		windowReplacesPlaneA();
		spriteOverPlanes();
		spritesPerLine();
		shadowedLine();

		final args = Sys.args();
		if (args.length > 0) drawnText(args[0]);

		Sys.println("");
		Sys.println(checks + " render checks, " + failures + " failures");
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

		for (i in 0...64) colour(vdp, i, ((i & 7) << 1) | (((i >> 3) & 7) << 5));

		for (row in 0...8) {
			word(vdp, 1, 32 + row * 4, 0x1111);
			word(vdp, 1, 32 + row * 4 + 2, 0x1111);
			word(vdp, 1, 64 + row * 4, 0x2222);
			word(vdp, 1, 64 + row * 4 + 2, 0x3333);
		}

		return vdp;
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
		while (vdp.queued > 0) vdp.tick(16);
	}

	static function colour(vdp:Vdp, index:Int, value:Int):Void {
		word(vdp, 3, index * 2, value);
	}

	static function cell(vdp:Vdp, base:Int, column:Int, row:Int, entry:Int):Void {
		word(vdp, 1, base + (row * 64 + column) * 2, entry);
	}

	static function pixel(vdp:Vdp, x:Int):Int {
		return vdp.renderer.pixels[x];
	}

	static function expected(vdp:Vdp, index:Int, mode:Int = 0):Int {
		return Renderer.rgb(vdp.cram[index], mode);
	}

	static function backdrop():Void {
		final vdp = setup();
		register(vdp, 7, 10);
		vdp.renderer.line(vdp, 0);

		var uniform = true;
		for (x in 0...320) if (pixel(vdp, x) != expected(vdp, 10)) uniform = false;
		check(uniform, "an empty line is the backdrop register's colour everywhere");
	}

	static function opaqueTile():Void {
		final vdp = setup();
		register(vdp, 7, 10);
		cell(vdp, PLANE_A, 0, 0, 0x0001);
		vdp.renderer.line(vdp, 0);

		var covered = true;
		for (x in 0...8) if (pixel(vdp, x) != expected(vdp, 1)) covered = false;
		check(covered, "a plane A cell paints its eight pixels from its own palette");
		check(pixel(vdp, 8) == expected(vdp, 10), "the cell beside it stays the backdrop");
	}

	static function flippedTile():Void {
		final vdp = setup();
		cell(vdp, PLANE_A, 0, 0, 0x0002);
		cell(vdp, PLANE_A, 1, 0, 0x0802);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 0) == expected(vdp, 2) && pixel(vdp, 7) == expected(vdp, 3),
			"a tile paints its left half then its right");
		check(pixel(vdp, 8) == expected(vdp, 3) && pixel(vdp, 15) == expected(vdp, 2),
			"the flip bit reverses it");
	}

	static function planePriority():Void {
		final vdp = setup();
		cell(vdp, PLANE_A, 0, 0, 0x0001);
		cell(vdp, PLANE_B, 0, 0, 0xA001);
		cell(vdp, PLANE_A, 1, 0, 0x8001);
		cell(vdp, PLANE_B, 1, 0, 0x2001);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 0) == expected(vdp, 0x11), "plane B with priority covers plane A without it");
		check(pixel(vdp, 8) == expected(vdp, 0x01), "plane A with priority stays in front");
	}

	static function fullScreenScroll():Void {
		final vdp = setup();
		register(vdp, 7, 10);
		register(vdp, 11, 0x00);
		word(vdp, 1, HSCROLL, 4);
		cell(vdp, PLANE_A, 0, 0, 0x0001);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 3) == expected(vdp, 10) && pixel(vdp, 4) == expected(vdp, 1),
			"a full-screen scroll of 4 moves the whole line right by four pixels");
	}

	static function windowReplacesPlaneA():Void {
		final vdp = setup();
		register(vdp, 17, 0x02);
		cell(vdp, PLANE_A, 0, 0, 0x0001);
		cell(vdp, PLANE_A, 4, 0, 0x0001);
		word(vdp, 1, WINDOW + 0, 0x0002);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 0) == expected(vdp, 2), "the window plane replaces plane A inside its region");
		check(pixel(vdp, 32) == expected(vdp, 1), "plane A comes back outside it");
	}

	static function spriteOverPlanes():Void {
		final vdp = setup();
		register(vdp, 7, 10);
		cell(vdp, PLANE_A, 0, 0, 0x0001);
		sprite(vdp, 0, 128, 128, 0, 0, 0x0002);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 0) == expected(vdp, 2), "a sprite without priority still covers a plane without it");
		check(pixel(vdp, 7) == expected(vdp, 3), "the sprite's own tile decides its pixels");
	}

	static function spritesPerLine():Void {
		final vdp = setup();
		register(vdp, 7, 10);

		for (i in 0...21) sprite(vdp, i, 128, 128 + i * 8, i < 20 ? i + 1 : 0, 0, 0x0001);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 19 * 8) == expected(vdp, 1), "the twentieth sprite on a line is drawn");
		check(pixel(vdp, 20 * 8) == expected(vdp, 10), "the twenty-first is not, since H40 stops at twenty");
	}

	static function shadowedLine():Void {
		final vdp = setup();
		register(vdp, 7, 10);
		register(vdp, 12, 0x89);
		cell(vdp, PLANE_A, 0, 0, 0x0001);
		cell(vdp, PLANE_A, 1, 0, 0x8001);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 0) == expected(vdp, 1, Renderer.SHADOW),
			"shadow and highlight mode darkens a line with nothing in front");
		check(pixel(vdp, 8) == expected(vdp, 1), "a cell with priority is not darkened");
	}

	static function sprite(vdp:Vdp, index:Int, y:Int, x:Int, link:Int, size:Int, attribute:Int):Void {
		final base = SPRITES + index * 8;
		word(vdp, 1, base, y);
		word(vdp, 1, base + 2, ((size & 0x0F) << 8) | (link & 0x7F));
		word(vdp, 1, base + 4, attribute);
		word(vdp, 1, base + 6, x);
	}

	static function drawnText(root:String):Void {
		final machine = new Machine();
		machine.load(haxe.io.Path.join([root, "samples/spike/rom/out/release/rom.bin"]));

		for (frame in 0...40) machine.runFrame();

		final renderer = machine.vdp.renderer;
		final row = 100 * Renderer.MAX_WIDTH;
		final background = renderer.pixels[row];
		var ink = 0;
		for (x in 96...208) if (renderer.pixels[row + x] != background) ink++;

		check(ink > 20, "the spike ROM's own text renders as " + ink + " pixels of ink");
	}
}

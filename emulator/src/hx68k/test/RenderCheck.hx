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
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
		backdrop();
		opaqueTile();
		flippedTile();
		planePriority();
		fullScreenScroll();
		windowReplacesPlaneA();
		spriteOverPlanes();
		spritesPerLine();
		spriteMask();
		maskFirst();
		maskAfterMask();
		dotLimit();
		overflowFlag();
		collisionFlag();
		linkPastTheTable();
		shadowedLine();
		colourLevels();

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
		while (vdp.queued > 0 || vdp.running()) vdp.tick(16);
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

	static function channel(value:Int, mode:Int):Int {
		return (Renderer.rgb(value << 1, mode) >> 16) & 0xFF;
	}

	static function distinct(values:Array<Int>):Int {
		final seen = new Map<Int, Bool>();
		for (value in values) seen.set(value, true);

		var count = 0;
		for (_ in seen.keys()) count++;
		return count;
	}

	static function colourLevels():Void {
		final normal = [for (n in 0...8) channel(n, 0)];
		final shadow = [for (n in 0...8) channel(n, Renderer.SHADOW)];
		final highlight = [for (n in 0...8) channel(n, Renderer.HIGHLIGHT)];

		check(normal[0] == 0 && normal[7] == 255,
			"the darkest colour reads as black and the brightest as full");
		check(shadow[0] == normal[0], "shadowing black leaves black");
		check(highlight[7] == normal[7], "highlighting the brightest cannot pass full");
		check(shadow[7] == highlight[0],
			"shadow ends where highlight starts, so the three modes share one ramp");

		check(distinct(normal) == 8, "a normal colour reaches eight levels");
		check(distinct(shadow) == 8, "so does a shadowed one");
		check(distinct(highlight) == 8, "so does a highlighted one");
		check(distinct(normal.concat(shadow).concat(highlight)) == 15,
			"and the three together reach fifteen, not sixteen");

		final ramp = shadow.concat(highlight.slice(1));
		var rising = true;
		for (n in 1...ramp.length) if (ramp[n] <= ramp[n - 1]) rising = false;
		check(rising, "the ramp rises at every step");

		var every = true;
		for (n in 0...8) if (normal[n] != ramp[n * 2]) every = false;
		check(every, "a normal colour is every other level of that ramp");

		final steps = [for (n in 1...ramp.length) ramp[n] - ramp[n - 1]];
		var flatter = true;
		for (n in 1...steps.length - 1) {
			if (steps[n] >= steps[0] || steps[n] >= steps[steps.length - 1]) flatter = false;
		}
		check(flatter, "and it is a curve, flatter in the middle than at either end");
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

	static function spriteMask():Void {
		final vdp = setup();
		register(vdp, 7, 10);

		sprite(vdp, 0, 128, 128, 1, 0, 0x0001);
		sprite(vdp, 1, 128, 0, 2, 0, 0x0001);
		sprite(vdp, 2, 128, 144, 0, 0, 0x0001);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 0) == expected(vdp, 1), "a sprite before a mask is drawn");
		check(pixel(vdp, 16) == expected(vdp, 10),
			"and a sprite after one, where the mask follows a sprite with x above zero, is not");
	}

	static function maskFirst():Void {
		final vdp = setup();
		register(vdp, 7, 10);

		sprite(vdp, 0, 128, 0, 1, 0, 0x0001);
		sprite(vdp, 1, 128, 128, 0, 0, 0x0001);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 0) == expected(vdp, 1),
			"a mask that is the first sprite on its line hides nothing");
	}

	static function maskAfterMask():Void {
		final vdp = setup();
		register(vdp, 7, 10);

		sprite(vdp, 0, 128, 0, 1, 0, 0x0001);
		sprite(vdp, 1, 128, 0, 2, 0, 0x0001);
		sprite(vdp, 2, 128, 128, 0, 0, 0x0001);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 0) == expected(vdp, 1),
			"and neither does a second mask straight after the first");
	}

	static function dotLimit():Void {
		final vdp = setup();
		register(vdp, 7, 10);

		for (i in 0...13) sprite(vdp, i, 128, 96, i + 1, 0x08, 0x0001);
		sprite(vdp, 13, 128, 128, 0, 0x0C, 0x0001);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 7) == expected(vdp, 1), "the last pixel the dot limit leaves room for is drawn");
		check(pixel(vdp, 8) == expected(vdp, 10), "and the next one, in the same sprite, is not");
	}

	static function overflowFlag():Void {
		final vdp = setup();
		register(vdp, 7, 10);

		for (i in 0...21) sprite(vdp, i, 128, 128 + i * 8, i < 20 ? i + 1 : 0, 0, 0x0001);
		vdp.renderer.line(vdp, 0);

		check((vdp.readStatus() & 0x0040) != 0, "too many sprites on a line raises the overflow bit");
		check((vdp.readStatus() & 0x0040) == 0, "and reading the status clears it");
	}

	static function collisionFlag():Void {
		final vdp = setup();
		register(vdp, 7, 10);

		sprite(vdp, 0, 128, 128, 1, 0, 0x0001);
		sprite(vdp, 1, 128, 132, 0, 0, 0x0001);
		vdp.renderer.line(vdp, 0);

		check((vdp.readStatus() & 0x0020) != 0, "two sprites over one pixel raise the collision bit");
		check((vdp.readStatus() & 0x0020) == 0, "and reading the status clears it");
	}

	static function linkPastTheTable():Void {
		final vdp = setup();
		register(vdp, 7, 10);

		sprite(vdp, 0, 128, 128, 70, 0, 0x0001);
		sprite(vdp, 70, 128, 160, 0, 0, 0x0001);
		register(vdp, 12, 0x81);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 32) == expected(vdp, 1),
			"a link to entry 70 is followed in H40, where the table holds eighty");

		register(vdp, 12, 0x01);
		vdp.renderer.line(vdp, 0);

		check(pixel(vdp, 32) == expected(vdp, 10),
			"and stops the scan in H32, where it holds sixty-four");
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

package hx68k.test;

import haxe.io.Path;
import hx68k.md.Machine;
import hx68k.md.Renderer;

class SpriteCheck {
	static inline final SETTLE = 300;

	static inline final HELD = 6;

	static inline final AFTER = 200;

	static inline final PAD_C = 0x20;

	static inline final PASSED = 0x00FF00;

	static inline final FAILED = 0xFF0000;

	static final NAMED = [
		"max sprites per line",
		"max sprite dots, basic",
		"max sprite dots, complex",
		"sprite mask",
		"sprite mask, sprite 1",
		"mask sprite 1 on dot overflow",
		"mask sprite 1, x=0 and x=1",
		"mask sprite 1, x=0 twice",
		"max sprites per frame"
	];

	static var failures:Int = 0;

	static function main():Void {
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
		final root = args.length > 0 ? args[0] : ".";
		final rom = Path.join([root, "vendor/SpriteMaskingTest/sprites.bin"]);

		if (!sys.FileSystem.exists(rom)) {
			Sys.println("  skip: no ROM at " + rom + ", run haxelib run hx68k setup");
			return;
		}

		final into = args.length > 1 ? args[1] : null;

		final machine = new Machine();
		machine.load(rom);
		for (_ in 0...SETTLE) machine.runFrame();

		for (page in 0...2) {
			if (page > 0) turn(machine);
			say(machine, page == 0 ? "H32" : "H40");

			if (into != null) {
				final file = into + "/sprites-" + (page == 0 ? "h32" : "h40") + ".png";
				hx68k.debug.Screenshot.save(machine.vdp.renderer, file);
				Sys.println("  wrote " + file);
			}
		}

		Sys.println("  " + failures + " result rows carry red, over both widths");
	}

	static function turn(machine:Machine):Void {
		for (_ in 0...HELD) {
			machine.buttons[0] = PAD_C;
			machine.runFrame();
		}

		machine.buttons[0] = 0;
		for (_ in 0...AFTER) machine.runFrame();
	}

	static function say(machine:Machine, mode:String):Void {
		final renderer = machine.vdp.renderer;
		final green = new Array<Int>();
		final red = new Array<Int>();

		var cell = 0;
		while (cell * 8 + 8 <= renderer.height) {
			var rowGreen = 0;
			var rowRed = 0;

			for (y in cell * 8...cell * 8 + 8) {
				for (x in 0...renderer.width) {
					switch (renderer.pixels[y * Renderer.MAX_WIDTH + x]) {
						case PASSED: rowGreen++;
						case FAILED: rowRed++;
						case _:
					}
				}
			}

			if (rowGreen + rowRed > 0) {
				green.push(rowGreen);
				red.push(rowRed);
			}
			cell++;
		}

		var wrong = 0;
		for (i in 0...green.length) if (red[i] > 0) wrong++;

		Sys.println("  " + mode + " at " + renderer.width + " pixels wide: " + wrong
			+ " of " + green.length + " result rows carry red");

		for (i in 0...green.length) {
			final name = i < NAMED.length ? NAMED[i] : "row " + (i + 1);
			Sys.println("    " + (red[i] > 0 ? "RED  " : "ok   ") + StringTools.rpad(name, " ", 30)
				+ green[i] + " green, " + red[i] + " red");
		}

		failures += wrong;
	}
}

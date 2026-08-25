package hx68k.test;

import haxe.io.Path;
import hx68k.md.Machine;
import hx68k.md.Renderer;

class FifoCheck {
	static inline final SETTLE = 400;

	static inline final HELD = 6;

	static inline final AFTER = 120;

	static inline final PAD_START = 0x80;

	static inline final PASSED = 0x004800;

	static inline final FAILED = 0xDA0000;

	static function main():Void {
		final args = Sys.args();
		final root = args.length > 0 ? args[0] : ".";
		final rom = Path.join([root, "vendor/VDPFIFOTesting/VDPFIFOTesting.bin"]);

		if (!sys.FileSystem.exists(rom)) {
			Sys.println("  skip: no ROM at " + rom + ", run haxelib run hx68k setup");
			return;
		}

		final pages = args.length > 1 ? Std.parseInt(args[1]) : 2;
		final into = args.length > 2 ? args[2] : null;

		final machine = new Machine();
		machine.load(rom);

		for (_ in 0...SETTLE) machine.runFrame();

		for (page in 0...(pages == null ? 2 : pages)) {
			if (page > 0) turn(machine);
			say(machine, page + 1);
			if (into != null) {
				final file = into + "/fifo-page" + (page + 1) + ".png";
				hx68k.debug.Screenshot.save(machine.vdp.renderer, file);
				Sys.println("  wrote " + file);
			}
		}
	}

	static function turn(machine:Machine):Void {
		for (_ in 0...HELD) {
			machine.buttons[0] = PAD_START;
			machine.runFrame();
		}

		machine.buttons[0] = 0;
		for (_ in 0...AFTER) machine.runFrame();
	}

	static function say(machine:Machine, page:Int):Void {
		final renderer = machine.vdp.renderer;

		var green = 0;
		var red = 0;

		for (y in 0...renderer.height) {
			for (x in 0...renderer.width) {
				switch (renderer.pixels[y * Renderer.MAX_WIDTH + x]) {
					case PASSED: green++;
					case FAILED: red++;
					case _:
				}
			}
		}

		final total = green + red;
		Sys.println("  page " + page + ": " + green + " of " + total
			+ " pixels of the result rows are drawn in the passing colour ("
			+ (total == 0 ? 0 : Math.round(1000.0 * green / total) / 10) + "%)");
	}
}

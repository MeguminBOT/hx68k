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
		var bandGreen = 0;
		var bandRed = 0;
		var band = 0;

		for (y in 0...renderer.height) {
			var rowGreen = 0;
			var rowRed = 0;

			for (x in 0...renderer.width) {
				switch (renderer.pixels[y * Renderer.MAX_WIDTH + x]) {
					case PASSED: rowGreen++;
					case FAILED: rowRed++;
					case _:
				}
			}

			if (rowGreen + rowRed > 0) {
				bandGreen += rowGreen;
				bandRed += rowRed;
				continue;
			}

			if (bandGreen + bandRed > 0) {
				band++;
				Sys.println("    " + StringTools.lpad(Std.string(band), " ", 2) + "  "
					+ share(bandGreen, bandRed));
				green += bandGreen;
				red += bandRed;
			}

			bandGreen = 0;
			bandRed = 0;
		}

		if (bandGreen + bandRed > 0) {
			band++;
			Sys.println("    " + StringTools.lpad(Std.string(band), " ", 2) + "  "
				+ share(bandGreen, bandRed));
			green += bandGreen;
			red += bandRed;
		}

		Sys.println("  page " + page + ": " + share(green, red) + " over " + band + " suites");
	}

	static function share(green:Int, red:Int):String {
		final total = green + red;
		return StringTools.lpad(Std.string(green), " ", 5) + " of "
			+ StringTools.lpad(Std.string(total), " ", 5) + " pixels pass, "
			+ StringTools.lpad(Std.string(total == 0 ? 0 : Math.round(1000.0 * green / total) / 10),
				" ", 5) + "%";
	}
}

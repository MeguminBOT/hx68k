package hx68k.test.md;

import haxe.io.Path;
import hx68k.md.Machine;
import hx68k.md.Renderer;

class PatternCheck {
	static inline final SETTLE = 400;

	static inline final HELD = 6;

	static inline final AFTER = 20;

	static inline final PAD_DOWN = 0x02;

	static inline final PAD_A = 0x40;

	static inline final PAD_START = 0x80;

	static final PATTERNS:Array<String> = [
		"pluge", "color bars", "color bars with grey", "grid", "linearity", "grey ramp",
		"white screen"
	];

	static final DREW:Map<String, String> = [
		"pluge" => "125D8000",
		"color bars" => "11C0F6F6",
		"color bars with grey" => "75840D46",
		"grid" => "BCB46000",
		"linearity" => "D8DCA780",
		"grey ramp" => "FCCFA000",
		"white screen" => "D8BE8000"
	];

	static var failures:Int = 0;

	static function main():Void {
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
		final root = args.length > 0 ? args[0] : ".";
		final rom = Path.join([root, "vendor/240pTestSuite/240p.bin"]);

		if (!sys.FileSystem.exists(rom)) {
			Sys.println("  skip: no ROM at " + rom + ", run haxelib run hx68k setup");
			return;
		}

		final into = args.length > 1 && args[1] != "-" ? args[1] : null;
		final said = args.length > 2 ? args[2] : "";
		final wanted = said == "-" ? new Map<String, String>()
			: (said == "" ? DREW : digests(said));

		final machine = new Machine();
		machine.load(rom);
		for (_ in 0...SETTLE) machine.runFrame();

		press(machine, PAD_A);

		for (name in PATTERNS) {
			press(machine, PAD_A);
			report(machine, name, into, wanted.get(name));
			press(machine, PAD_START);
			press(machine, PAD_DOWN);
		}

		Sys.println("  " + PATTERNS.length + " patterns, " + failures + " failures");
		if (failures > 0) Sys.exit(1);
	}

	static function digests(said:String):Map<String, String> {
		final out = new Map<String, String>();

		for (part in said.split(",")) {
			final at = part.indexOf(":");
			if (at > 0) out.set(part.substr(0, at), part.substr(at + 1).toUpperCase());
		}

		return out;
	}

	static function press(machine:Machine, button:Int):Void {
		for (_ in 0...HELD) {
			machine.buttons[0] = button;
			machine.runFrame();
		}

		machine.buttons[0] = 0;
		for (_ in 0...AFTER) machine.runFrame();
	}

	static function report(machine:Machine, name:String, into:Null<String>,
			expected:Null<String>):Void {
		final got = StringTools.hex(digestOf(machine), 8);

		if (into != null) {
			final file = into + "/240p-" + StringTools.replace(name, " ", "-") + ".png";
			hx68k.debug.Screenshot.save(machine.vdp.renderer, file);
		}

		if (expected == null) {
			Sys.println("  " + StringTools.rpad(name, " ", 22) + got);
			return;
		}

		if (got == expected) {
			Sys.println("  ok   " + StringTools.rpad(name, " ", 22) + got);
			return;
		}

		failures++;
		Sys.println("  FAIL " + StringTools.rpad(name, " ", 22) + got + ", drew " + expected
			+ " last time");
	}

	static function digestOf(machine:Machine):Int {
		final renderer = machine.vdp.renderer;
		var digest = 0;

		for (y in 0...renderer.height) {
			for (x in 0...renderer.width) {
				digest = (digest * 31 + renderer.pixels[y * Renderer.MAX_WIDTH + x]) | 0;
			}
		}

		return digest;
	}
}

package hx68k.test;

import hx68k.map.Elf;
import hx68k.md.Machine;

class SoundCheck {
	static inline final FRAMES = 60;

	static var checks = 0;
	static var failures = 0;

	static function main():Void {
		final args = Sys.args();
		if (args.length < 1) {
			Sys.println("usage: sound <repository root>");
			Sys.exit(2);
		}

		final root = args[0];
		final machine = new Machine();
		machine.vdp.rendering = false;
		machine.load(haxe.io.Path.join([root, "samples/sound/rom/out/release/rom.bin"]));

		final elf = new Elf(haxe.io.Path.join([root, "samples/sound/rom/out/release/rom.out"]));
		final done = address(elf, "hx_probe_done");
		final probe = address(elf, "hx_probe");

		var frames = 0;
		while (frames < FRAMES && machine.readWord(done) == 0) {
			machine.runFrame();
			frames++;
		}

		check(machine.readWord(done) != 0, "the rom got past starting the music, in " + frames + " frames");
		check(machine.z80.pc != 0, "the z80 is running its own code at 0x"
			+ StringTools.hex(machine.z80.pc, 4));
		check(busy(machine), "the z80 driver is somewhere inside its own eight kilobytes");

		check(peek(machine, probe) == 1, "Z80_isDriverReady (got " + peek(machine, probe) + ")");
		check(peek(machine, probe + 4) > 0, "a driver is loaded (got " + peek(machine, probe + 4) + ")");
		check(peek(machine, probe + 8) == 1, "XGM_isPlaying (got " + peek(machine, probe + 8) + ")");
		check(machine.z80Bus.soundWrites > 0, "the driver wrote to the sound chips "
			+ machine.z80Bus.soundWrites + " times");

		Sys.println("");
		Sys.println(checks + " sound checks, " + failures + " failures");
		Sys.exit(failures == 0 ? 0 : 1);
	}

	static function busy(machine:Machine):Bool {
		var written = 0;
		for (i in 0...0x2000) if (machine.z80Bus.ram.get(i) != 0) written++;
		return written > 256;
	}

	static function address(elf:Elf, symbol:String):Int {
		final found = elf.addressOf(symbol);
		return found == null ? 0 : found & 0xFFFFFF;
	}

	static function peek(machine:Machine, at:Int):Int {
		return (machine.readWord(at) << 16) | machine.readWord(at + 2);
	}

	static function check(ok:Bool, what:String):Void {
		checks++;
		if (!ok) failures++;
		Sys.println((ok ? "  ok   " : "  FAIL ") + what);
	}
}

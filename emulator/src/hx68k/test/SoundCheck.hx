package hx68k.test;

import hx68k.map.Elf;
import hx68k.md.Machine;
import hx68k.md.Sound;

class SoundCheck {
	static inline final FRAMES = 60;

	static inline final CHUNK = 256;

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

		heard(machine);
		sides();

		Sys.println("");
		Sys.println(checks + " sound checks, " + failures + " failures");
		Sys.exit(failures == 0 ? 0 : 1);
	}

	static function heard(machine:Machine):Void {
		final sound = machine.sound;
		final taken = new haxe.ds.Vector<Int>(CHUNK * 2);

		while (sound.ready() > 0) sound.take(taken, CHUNK);

		var count = 0;
		var loudest = 0;
		var sum = 0.0;
		var power = 0.0;
		var deepest = 0;
		final before = sound.lost;

		for (_ in 0...FRAMES) {
			machine.runFrame();
			if (sound.ready() > deepest) deepest = sound.ready();

			while (sound.ready() >= CHUNK) {
				final got = sound.take(taken, CHUNK);
				for (i in 0...got * 2) {
					final value = taken[i];
					final size = value < 0 ? -value : value;
					if (size > loudest) loudest = size;
					sum += value;
					power += value * value;
					count++;
				}
			}
		}

		Sys.println("");

		final wanted = Std.int(FRAMES * Sound.RATE / 60);
		check(count / 2 > wanted - 900 && count / 2 < wanted + 900,
			"the mixer made " + Std.int(count / 2) + " samples over " + FRAMES
			+ " frames, wanting about " + wanted);

		final offset = count == 0 ? 0.0 : sum / count;
		final loudness = count == 0 ? 0.0 : Math.sqrt(power / count);

		check(offset > -30 && offset < 30, "the mix sits on centre, off by " + Math.round(offset));
		check(loudness > 20, "there is something to hear, at " + Math.round(loudness) + " of level");
		check(loudest < 2600, "nothing ran past what the chips can make, the loudest being " + loudest);
		check(sound.lost - before == 0,
			"nothing was dropped for want of a listener (" + (sound.lost - before) + ")");
		check(deepest < 2000, "the ring stayed shallow, at most " + deepest + " samples");
	}

	static function sides():Void {
		final sound = new Sound();
		final taken = new haxe.ds.Vector<Int>(CHUNK * 2);

		for (at in [0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x90]) {
			for (slot in [0, 4, 8, 12]) {
				sound.ym.write(0, at + slot);
				sound.ym.write(1, at == 0x30 ? 0x01 : (at == 0x50 ? 0x1F : (at == 0x80 ? 0x0F : 0)));
			}
		}

		sound.ym.write(0, 0xB0);
		sound.ym.write(1, 0x07);
		sound.ym.write(0, 0xB4);
		sound.ym.write(1, 0x80);
		sound.ym.write(0, 0xA4);
		sound.ym.write(1, (4 << 3) | 1);
		sound.ym.write(0, 0xA0);
		sound.ym.write(1, 0x69);
		sound.ym.write(0, 0x28);
		sound.ym.write(1, 0xF0);

		var left = 0;
		var right = 0;

		for (_ in 0...400) {
			sound.tick(4000);
			while (sound.ready() >= CHUNK) {
				final got = sound.take(taken, CHUNK);
				for (i in 0...got) {
					final a = taken[i * 2];
					final b = taken[i * 2 + 1];
					if ((a < 0 ? -a : a) > left) left = a < 0 ? -a : a;
					if ((b < 0 ? -b : b) > right) right = b < 0 ? -b : b;
				}
			}
		}

		Sys.println("");
		check(left > 50, "a channel panned hard left is heard on the left, at " + left);
		check(right < left / 8, "and not on the right, at " + right);
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

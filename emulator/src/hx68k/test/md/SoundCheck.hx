package hx68k.test.md;

import hx68k.map.Elf;
import hx68k.md.Machine;
import hx68k.md.Sound;

class SoundCheck {
	static inline final FRAMES = 60;

	static inline final CHUNK = 256;

	static inline final SETTLE_LIMIT = 20000000;

	static inline final PENDING_FRAME = 0x113;

	static var checks = 0;
	static var failures = 0;

	static function main():Void {
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
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
		final counted = address(elf, "hx_probe_count");

		settled(machine, counted);
		chips(machine);

		var frames = 0;
		while (frames < FRAMES && machine.readWord(done) == 0) {
			machine.runFrame();
			frames++;
		}

		check(machine.readWord(done) != 0, "the rom got past starting the music, in " + frames + " frames");
		check(machine.z80.pc != 0, "the z80 is running its own code at 0x"
			+ StringTools.hex(machine.z80.pc, 4));
		check(busy(machine), "the z80 driver is somewhere inside its own eight kilobytes");

		check(peek(machine, probe + 4) == 1, "Z80_isDriverReady (got "
			+ peek(machine, probe + 4) + ")");
		check(peek(machine, probe + 8) > 0, "a driver is loaded (got "
			+ peek(machine, probe + 8) + ")");
		check(peek(machine, probe + 12) == 1, "XGM_isPlaying (got "
			+ peek(machine, probe + 12) + ")");
		check(machine.z80Bus.soundWrites > 0, "the driver wrote to the sound chips "
			+ machine.z80Bus.soundWrites + " times");

		check(peek(machine, probe + 16) != 0, "XGM_isPlayingPCM (got "
			+ peek(machine, probe + 16) + ")");

		final beep = [
			{at: 20, want: 92, where: 8},
			{at: 24, want: 163, where: 24},
			{at: 28, want: 88, where: 200},
			{at: 32, want: 34, where: 1000},
			{at: 36, want: 0, where: 7000}
		];
		for (each in beep)
			check(peek(machine, probe + each.at) == each.want,
				"the wav at byte " + each.where + " is " + peek(machine, probe + each.at)
				+ ", wanting " + each.want);

		heard(machine);
		sides();

		Sys.println("");
		Sys.println(checks + " sound checks, " + failures + " failures");
		Sys.exit(failures == 0 ? 0 : 1);
	}

	static function settled(machine:Machine, counted:Int):Void {
		var steps = 0;

		while (machine.readWord(counted) == 0 && steps < SETTLE_LIMIT) {
			machine.step();
			steps++;
		}

		check(machine.readWord(counted) == 1, "the rom set both sound chips up, in " + steps
			+ " instructions");
	}

	static function chips(machine:Machine):Void {
		final psg = machine.sound.psg;
		final ym = machine.sound.ym;

		check(psg.tone[0] == 0x1A5, "a PSG tone written as a whole (got " + psg.tone[0] + ")");
		check(psg.attenuation[0] == 2, "and its attenuation (got " + psg.attenuation[0] + ")");
		check(psg.tone[1] == 254, "a PSG tone asked for in hertz (got " + psg.tone[1] + ")");
		check(psg.attenuation[1] == 7, "and its attenuation (got " + psg.attenuation[1] + ")");
		check(psg.noise == 6, "the noise channel took its type and rate (got "
			+ psg.noise + ")");
		check(psg.attenuation[3] == 5, "and its attenuation (got " + psg.attenuation[3] + ")");
		check(psg.attenuation[2] == 0x0F, "the channel nothing asked for stayed silent");

		check(ym.registers[0x100 + 0xB1] == 0x33, "an FM algorithm and feedback (got "
			+ ym.registers[0x100 + 0xB1] + ")");
		check(ym.registers[0x100 + 0xB5] == 0x80, "panned left only (got "
			+ ym.registers[0x100 + 0xB5] + ")");
		check(ym.registers[0x100 + 0xA5] == 0x2A, "a block and the high three bits of a note");
		check(ym.registers[0x100 + 0xA1] == 0xA9, "and the low eight, written second");
		check(ym.registers[0x100 + 0x45] == 0x1C, "slot 3's total level, at the offset the "
			+ "chip orders slots in (got " + ym.registers[0x100 + 0x45] + ")");
		check(ym.registers[0x100 + 0x35] == 0x39, "and its detune and multiple (got "
			+ ym.registers[0x100 + 0x35] + ")");
		check(ym.registers[0x28] == 0xF5, "all four slots keyed on for channel 5 (got "
			+ ym.registers[0x28] + ")");
		check(ym.registers[0x100 + 0x4D] == 0x7F, "a slot nothing asked for stayed quiet");
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
		final wrote = machine.z80Bus.soundWrites;
		var waiting = 0;
		var idle = 0;

		for (_ in 0...FRAMES) {
			machine.runFrame();
			if (sound.ready() > deepest) deepest = sound.ready();

			final pending = machine.z80Bus.ram.get(PENDING_FRAME);
			if (pending > waiting) waiting = pending;
			if (pending == 0) idle++;

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

		check(offset > -30 && offset < 30, "the mix sits on center, off by " + Math.round(offset));
		check(loudness > 20, "there is something to hear, at " + Math.round(loudness) + " of level");
		check(loudest < 2600, "nothing ran past what the chips can make, the loudest being " + loudest);
		check(sound.lost - before == 0,
			"nothing was dropped for want of a listener (" + (sound.lost - before) + ")");
		check(deepest < 2000, "the ring stayed shallow, at most " + deepest + " samples");

		check(waiting <= 1, "the driver kept up: at most " + waiting
			+ " XGM frame left waiting at the end of any of " + FRAMES);
		check(idle == FRAMES, "and nothing left over on " + idle + " of " + FRAMES
			+ " frames, which is one XGM frame a vertical interrupt and so the tempo");
		check(machine.z80Bus.soundWrites - wrote > 1000, "the driver wrote to the chips "
			+ (machine.z80Bus.soundWrites - wrote) + " times over those frames");
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

		check(right < left / 8, "and on the right only its converter's step, at " + right);
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

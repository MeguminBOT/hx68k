package hx68k.test;

import haxe.io.Bytes;
import haxe.io.Path;
import hx68k.debug.Rewind;
import hx68k.md.Machine;
import hx68k.md.Renderer;
import hx68k.md.Savestate;

class StateCheck {
	static inline final SETTLE = 45;

	static var checks = 0;
	static var failures = 0;

	static function main():Void {
		final args = Sys.args();
		final root = args.length > 0 ? args[0] : ".";

		roundTrip(Path.join([root, "samples/spike/rom/out/release/rom.bin"]), "spike");
		roundTrip(Path.join([root, "samples/art/rom/out/release/rom.bin"]), "art");

		roundTrip(Path.join([root, "samples/sound/rom/out/release/rom.bin"]), "sound");
		chips(Path.join([root, "samples/spike/rom/out/release/rom.bin"]));
		rewinds(Path.join([root, "samples/spike/rom/out/release/rom.bin"]));

		Sys.println("");
		Sys.println(checks + " state checks, " + failures + " failures");
		Sys.exit(failures == 0 ? 0 : 1);
	}

	static function check(ok:Bool, what:String):Void {
		checks++;
		if (!ok) failures++;
		Sys.println((ok ? "  ok   " : "  FAIL ") + what);
	}

	static function roundTrip(rom:String, name:String):Void {
		if (!sys.FileSystem.exists(rom)) {
			Sys.println("  skip " + name + ": no ROM at " + rom);
			return;
		}

		final machine = new Machine();
		machine.load(rom);
		machine.vdp.rendering = false;
		for (_ in 0...SETTLE) machine.runFrame();
		machine.vdp.rendering = true;

		for (_ in 0...7777) machine.step();

		heard(machine);

		final saved = Savestate.of(machine);
		check(Savestate.of(machine).compare(saved) == 0, name + ": saving twice gives the same bytes");

		for (_ in 0...6) machine.runFrame();
		for (_ in 0...5555) machine.step();
		final wentOn = Savestate.of(machine);
		final drew = pixels(machine);
		final held = memory(machine);
		final sounded = heard(machine);

		Savestate.into(machine, saved);
		check(Savestate.of(machine).compare(saved) == 0, name + ": a state restored saves back the same");

		for (_ in 0...6) machine.runFrame();
		for (_ in 0...5555) machine.step();
		check(Savestate.of(machine).compare(wentOn) == 0,
			name + ": the same six frames from the same state reach the same state");
		check(pixels(machine) == drew, name + ": and draw the same frame");
		check(memory(machine) == held, name + ": and leave the same memory behind");
		check(heard(machine) == sounded, name + ": and make the same sound");
	}

	static function rewinds(rom:String):Void {
		if (!sys.FileSystem.exists(rom)) return;

		final machine = new Machine();
		machine.load(rom);
		machine.vdp.rendering = false;
		for (_ in 0...40) machine.runFrame();
		machine.vdp.rendering = true;

		final rewind = new Rewind(machine, 32);
		for (_ in 0...20) rewind.frame();

		final ahead = pixels(machine);
		final frame = machine.vdp.frame;

		check(rewind.depth == 20, "the ring holds a state for every frame it ran");
		check(!rewind.back(21), "it refuses to go back further than it has kept");
		check(rewind.back(10), "and goes back ten frames");
		check(machine.vdp.frame == frame - 10, "which is ten frames earlier on the counter");

		for (_ in 0...10) rewind.frame();
		check(machine.vdp.frame == frame, "running them again arrives at the same frame");
		check(pixels(machine) == ahead, "drawing the same picture it drew the first time");

		check(rewind.back(30) == false, "the ten it replayed did not deepen the ring past what it holds");
	}

	static function chips(rom:String):Void {
		if (!sys.FileSystem.exists(rom)) {
			Sys.println("  skip the chips: no ROM at " + rom);
			return;
		}

		final machine = new Machine();
		machine.load(rom);
		machine.vdp.rendering = false;
		for (_ in 0...200) machine.step();

		voice(machine);
		for (_ in 0...40000) machine.sound.tick(64);
		heard(machine);

		final saved = Savestate.of(machine);
		for (_ in 0...40000) machine.sound.tick(64);
		final sounded = heard(machine);

		Savestate.into(machine, saved);
		for (_ in 0...40000) machine.sound.tick(64);

		check(sounded != 0, "the chips made something to compare (" + sounded + ")");
		check(heard(machine) == sounded, "and carry across a state, sample for sample");
	}

	static function voice(machine:Machine):Void {
		final ym = machine.sound.ym;

		inline function set(port:Int, at:Int, value:Int):Void {
			ym.write(port, at);
			ym.write(port + 1, value);
		}

		set(0, 0x22, 0x0B);

		for (slot in [0, 4, 8, 12]) {
			set(0, 0x30 + slot, 0x21);
			set(0, 0x40 + slot, slot == 12 ? 8 : 26);
			set(0, 0x50 + slot, 0x14);
			set(0, 0x60 + slot, 0x86);
			set(0, 0x70 + slot, 0x03);
			set(0, 0x80 + slot, 0x24);
			set(0, 0x90 + slot, 0x00);
		}

		set(0, 0xB0, 0x1A);
		set(0, 0xB4, 0xF5);
		set(0, 0xA4, (4 << 3) | 1);
		set(0, 0xA0, 0x69);
		set(0, 0x28, 0xF0);

		machine.sound.psg.write(0x80 | 0x0E);
		machine.sound.psg.write(0x1B);
		machine.sound.psg.write(0x90 | 0x04);
	}

	static function heard(machine:Machine):Int {
		final taken = new haxe.ds.Vector<Int>(512);
		var digest = 0;

		while (machine.sound.ready() > 0) {
			final got = machine.sound.take(taken, 256);
			for (i in 0...got * 2) digest = (digest * 31 + taken[i]) | 0;
		}

		return digest;
	}

	static function pixels(machine:Machine):Int {
		var digest = 0;
		for (y in 0...224) {
			for (x in 0...320) digest = (digest * 31 + machine.vdp.renderer.pixels[y * Renderer.MAX_WIDTH + x]) | 0;
		}
		return digest;
	}

	static function memory(machine:Machine):Int {
		var digest = 17;
		digest = fold(digest, machine.ram);
		digest = fold(digest, machine.z80Ram);
		digest = fold(digest, machine.vdp.vram);

		for (i in 0...machine.vdp.cram.length) digest = (digest * 131 + machine.vdp.cram[i]) | 0;
		for (i in 0...machine.vdp.vsram.length) digest = (digest * 131 + machine.vdp.vsram[i]) | 0;
		for (i in 0...8) digest = (digest * 131 + machine.cpu.d[i] + machine.cpu.a[i]) | 0;

		return (digest * 131 + machine.cpu.pc + machine.z80.pc) | 0;
	}

	static function fold(digest:Int, bytes:Bytes):Int {
		var value = digest;
		for (i in 0...bytes.length) value = (value * 131 + bytes.get(i)) | 0;
		return value;
	}
}

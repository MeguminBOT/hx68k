package hx68k.test;

import haxe.io.Bytes;
import haxe.io.Path;
import hx68k.debug.Rewind;
import hx68k.md.Machine;
import hx68k.md.Renderer;
import hx68k.md.Savestate;

class StateCheck {
	static var checks = 0;
	static var failures = 0;

	static function main():Void {
		final args = Sys.args();
		final root = args.length > 0 ? args[0] : ".";

		roundTrip(Path.join([root, "samples/spike/rom/out/release/rom.bin"]), "spike");
		roundTrip(Path.join([root, "samples/art/rom/out/release/rom.bin"]), "art");
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
		for (_ in 0...40) machine.runFrame();
		machine.vdp.rendering = true;

		for (_ in 0...7777) machine.step();

		final saved = Savestate.of(machine);
		check(Savestate.of(machine).compare(saved) == 0, name + ": saving twice gives the same bytes");

		for (_ in 0...6) machine.runFrame();
		for (_ in 0...5555) machine.step();
		final wentOn = Savestate.of(machine);
		final drew = pixels(machine);
		final held = memory(machine);

		Savestate.into(machine, saved);
		check(Savestate.of(machine).compare(saved) == 0, name + ": a state restored saves back the same");

		for (_ in 0...6) machine.runFrame();
		for (_ in 0...5555) machine.step();
		check(Savestate.of(machine).compare(wentOn) == 0,
			name + ": the same six frames from the same state reach the same state");
		check(pixels(machine) == drew, name + ": and draw the same frame");
		check(memory(machine) == held, name + ": and leave the same memory behind");
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

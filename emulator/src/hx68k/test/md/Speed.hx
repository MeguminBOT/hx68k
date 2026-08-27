package hx68k.test.md;

import hx68k.md.Machine;

class Speed {
	static function main():Void {
		final args = Sys.args();
		if (args.length < 1) {
			Sys.println("usage: speed <rom> [frames]");
			Sys.exit(2);
		}

		final rom = args[0];
		if (!sys.FileSystem.exists(rom)) {
			Sys.println("no rom at " + rom + ", skipping");
			Sys.exit(0);
		}

		final frames = args.length > 1 ? Std.parseInt(args[1]) : 300;

		Sys.println("");
		Sys.println(haxe.io.Path.withoutDirectory(rom) + ", " + frames + " frames a pass");
		Sys.println("");

		final whole = pass(rom, frames, true, true);
		final quiet = pass(rom, frames, false, true);
		final blind = pass(rom, frames, true, false);
		final bare = pass(rom, frames, false, false);

		say("everything", whole, frames);
		say("without the sound", quiet, frames);
		say("without the renderer", blind, frames);
		say("neither", bare, frames);

		Sys.println("");
		part("sound", whole - quiet, whole);
		part("renderer", whole - blind, whole);
		part("the rest", bare, whole);

		Sys.println("");
		chips();
		Sys.println("");
		tempo();
		Sys.println("");
		panels(rom);
		Sys.println("");
		shares(rom);
		Sys.println("");
		Sys.println("  a frame has 16.7 ms in it, and the window draws in about 3 of them");
	}

	static function chips():Void {
		final sound = new hx68k.md.Sound();

		var started = haxe.Timer.stamp();
		for (_ in 0...888000) sound.ym.sample();
		final fm = haxe.Timer.stamp() - started;

		started = haxe.Timer.stamp();
		for (_ in 0...3729000) sound.psg.run(16);
		final psg = haxe.Timer.stamp() - started;

		started = haxe.Timer.stamp();
		for (_ in 0...32000000) sound.tick(28);
		final mixer = haxe.Timer.stamp() - started;

		Sys.println("  of a frame's sound, in the same milliseconds:");
		Sys.println("    the FM chip's 888 samples   " + round(fm) + " ms");
		Sys.println("    the other chip's 3729 steps " + round(psg) + " ms");
		Sys.println("    the mixer's 32000 slices    " + round(mixer - fm - psg) + " ms around them");
	}

	static function panels(rom:String):Void {
		final machine = new Machine();
		machine.load(rom);
		for (_ in 0...240) machine.runFrame();

		final views = hx68k.debug.Views.of(new hx68k.debug.Debugger(machine, null));

		Sys.println("  each of the debugger's panels, once, in milliseconds:");

		for (view in views) {
			final started = haxe.Timer.stamp();
			for (_ in 0...1000) view.rows(60);
			final each = (haxe.Timer.stamp() - started);

			Sys.println("    " + StringTools.rpad(view.title(), " ", 16) + round(each)
				+ (each > 0.5 ? "   this one is worth looking at" : ""));
		}

		Sys.println("    twenty of those a second is what an open panel costs a frame");
	}

	static function shares(rom:String):Void {
		final machine = new Machine();
		machine.load(rom);
		machine.vdp.rendering = false;

		for (_ in 0...240) machine.runFrame();

		final states = machine.z80Bus.states;
		final stopped = machine.stoppedFor;
		final requested = machine.requestedFor;
		final halted = machine.haltedFor;
		final cycles = machine.cycles;

		final frames = 300;
		for (_ in 0...frames) machine.runFrame();

		final master = frames * hx68k.md.Vdp.MASTER_PER_LINE * hx68k.md.Vdp.LINES_NTSC;
		final ran = (machine.z80Bus.states - states) * 15;
		final held = machine.stoppedFor - stopped;
		final took = machine.requestedFor - requested;
		final idle = machine.haltedFor - halted;

		Sys.println("  where the z80's clock went over " + frames + " settled frames:");
		Sys.println("    ran           " + portion(ran, master));
		Sys.println("    bus taken     " + portion(took, master));
		Sys.println("    held in reset " + portion(held, master));
		Sys.println("    halted        " + portion(idle, master));
		Sys.println("    unaccounted   " + portion(master - ran - took - held - idle, master));
		Sys.println("");
		Sys.println("  and the 68000 ran " + portion((machine.cycles - cycles) * 7, master));
	}

	static function portion(part:Int, whole:Int):String {
		return StringTools.lpad(Std.string(Math.round(1000.0 * part / whole) / 10), " ", 6) + "%"
			+ StringTools.lpad(Std.string(part), " ", 12) + " master clocks";
	}

	static function tempo():Void {
		final sound = new hx68k.md.Sound();
		final slice = 28;
		final slices = Std.int(hx68k.md.Vdp.MASTER_HZ / slice);

		var made = 0;
		final taken = new haxe.ds.Vector<Int>(512);

		for (_ in 0...slices) {
			sound.tick(slice);
			while (sound.ready() >= 256) made += sound.take(taken, 256);
		}

		made += sound.ready();

		Sys.println("  one emulated second of clock made " + made + " samples of 44100, with the"
			+ " rate bent to " + Math.round(sound.bend * 10000) / 10000);
	}

	static function pass(rom:String, frames:Int, audible:Bool, rendering:Bool):Float {
		final machine = new Machine();
		machine.load(rom);
		machine.audible = audible;
		machine.vdp.rendering = rendering;

		for (_ in 0...120) machine.runFrame();

		final started = haxe.Timer.stamp();
		for (_ in 0...frames) machine.runFrame();
		return haxe.Timer.stamp() - started;
	}

	static function say(what:String, seconds:Float, frames:Int):Void {
		final each = seconds * 1000 / frames;
		Sys.println("  " + StringTools.rpad(what, " ", 22)
			+ StringTools.lpad(round(each), " ", 7) + " ms a frame"
			+ StringTools.lpad(Std.string(Math.round(1000 / each)), " ", 7) + " frames a second");
	}

	static function part(what:String, seconds:Float, whole:Float):Void {
		Sys.println("  " + StringTools.rpad(what, " ", 22)
			+ StringTools.lpad(Math.round(100 * seconds / whole) + "%", " ", 7) + " of it");
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 100) / 100);
	}
}

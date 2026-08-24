package hx68k.test;

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

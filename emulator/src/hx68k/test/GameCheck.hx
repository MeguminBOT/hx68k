package hx68k.test;

import hx68k.md.Machine;
import hx68k.md.Renderer;

class GameCheck {
	static function main():Void {
		final args = Sys.args();
		if (args.length < 1) {
			Sys.println("usage: game <rom> [frames]");
			Sys.exit(2);
		}

		final path = args[0];
		if (!sys.FileSystem.exists(path)) {
			Sys.println("no rom at " + path + ", skipping");
			Sys.exit(0);
		}

		var frames = 120;
		var picture:Null<String> = null;
		var tune:Null<String> = null;
		var expected:Null<String> = null;

		var i = 1;
		while (i < args.length) {
			switch (args[i]) {
				case "--png": picture = args[++i];
				case "--wav": tune = args[++i];
				case "--digest": expected = args[++i];
				case _: frames = Std.parseInt(args[i]);
			}
			i++;
		}
		final machine = new Machine();
		machine.load(path);

		Sys.println("booting " + haxe.io.Path.withoutDirectory(path) + " for " + frames + " frames");

		var ran = 0;
		var fault:Null<String> = null;

		final heard:Array<Int> = [];
		final taken = new haxe.ds.Vector<Int>(2048);

		final started = haxe.Timer.stamp();
		while (ran < frames) {
			try {
				machine.runFrame();
				if (tune != null) hx68k.debug.Recording.drain(machine.sound, taken, heard);
			} catch (e:Dynamic) {
				fault = Std.string(e);
				break;
			}
			ran++;
		}
		final seconds = haxe.Timer.stamp() - started;

		if (fault != null) {
			Sys.println("  stopped in frame " + ran + " at pc=" + hex(machine.cpu.pc - 4, 6) + ": " + fault);
			Sys.exit(1);
		}

		final digest = report(machine, ran, seconds);

		if (tune != null) {
			hx68k.debug.Recording.save(heard, tune);
			Sys.println("  wrote " + tune + ", " + Math.round(10.0 * (heard.length >> 1)
				/ hx68k.md.Sound.RATE) / 10 + " seconds of it");
		}

		if (picture != null) {
			hx68k.debug.Screenshot.save(machine.vdp.renderer, picture);
			Sys.println("  wrote " + picture);
		}

		if (expected == null) Sys.exit(0);

		if (StringTools.hex(digest, 8) == expected.toUpperCase()) {
			Sys.println("  the frame is the one it drew last time");
			Sys.exit(0);
		}

		Sys.println("  the frame changed: expected " + expected.toUpperCase()
			+ ", got " + StringTools.hex(digest, 8));
		Sys.exit(1);
	}

	static function report(machine:Machine, frames:Int, seconds:Float):Int {
		Sys.println("  ran " + frames + " frames in " + Math.round(seconds * 10) / 10 + " s, "
			+ machine.cycles + " cycles of 68000");
		Sys.println("  68000 pc=" + hex(machine.cpu.pc - 4, 6) + " sr=" + hex(machine.cpu.getSr(), 4)
			+ " sp=" + hex(machine.cpu.a[7], 6));
		Sys.println("  z80   pc=" + hex(machine.z80.pc, 4) + " sound writes="
			+ machine.z80Bus.soundWrites);
		Sys.println("  share 68000 " + Std.int(machine.cycles / frames) + " cycles a frame of 128005"
			+ ", z80 " + Std.int(machine.z80Bus.states / frames) + " states a frame of 59672");

		Sys.println("  z80 v-ints raised " + machine.z80Raised + ", taken " + machine.z80Taken
			+ ", dropped " + machine.z80Dropped
			+ " (" + Math.round(1000.0 * machine.z80Dropped / (machine.z80Raised == 0 ? 1 : machine.z80Raised)) / 10
			+ "%)");

		Sys.println("  vdp   line=" + machine.vdp.line + " display="
			+ ((machine.vdp.registers[1] & 0x40) != 0 ? "on" : "off")
			+ " mode=" + ((machine.vdp.registers[12] & 0x81) == 0x81 ? "H40" : "H32")
			+ " vint=" + ((machine.vdp.registers[1] & 0x20) != 0 ? "on" : "off")
			+ " hint=" + ((machine.vdp.registers[0] & 0x10) != 0 ? "on" : "off"));

		var vram = 0;
		for (i in 0...0x10000) if (machine.vdp.vram.get(i) != 0) vram++;
		var cram = 0;
		for (i in 0...64) if (machine.vdp.cram[i] != 0) cram++;
		Sys.println("  memory " + vram + " bytes of VRAM written, " + cram + " colours set");

		var registers = "  regs ";
		for (i in 0...24) registers += hex(machine.vdp.registers[i], 2) + " ";
		Sys.println(registers);

		final planeA = (machine.vdp.registers[2] & 0x38) << 10;
		final planeB = (machine.vdp.registers[4] & 0x07) << 13;
		Sys.println("  bases plane A=" + hex(planeA, 4) + " plane B=" + hex(planeB, 4)
			+ " window=" + hex((machine.vdp.registers[3] & 0x3E) << 10, 4)
			+ " sprites=" + hex((machine.vdp.registers[5] & 0x7E) << 9, 4)
			+ " hscroll=" + hex((machine.vdp.registers[13] & 0x3F) << 10, 4));

		var row = "  cells ";
		for (i in 0...8) {
			final at = planeA + i * 2;
			row += hex((machine.vdp.vram.get(at) << 8) | machine.vdp.vram.get(at + 1), 4) + " ";
		}
		Sys.println(row + " (plane A, first row)");

		var used = "  vram ";
		for (block in 0...32) {
			var count = 0;
			for (i in 0...0x800) if (machine.vdp.vram.get(block * 0x800 + i) != 0) count++;
			used += (count == 0 ? "." : (count < 256 ? "-" : "#"));
		}
		Sys.println(used + "  (2 KB blocks, . empty - some # full)");

		final sprites = (machine.vdp.registers[5] & 0x7E) << 9;
		var first = "  sprite ";
		for (i in 0...8) first += hex(machine.vdp.vram.get(sprites + i), 2) + " ";
		Sys.println(first + " (first entry: y, size, link, attribute, x)");

		var back = "  plane B row 10 ";
		for (i in 0...8) {
			final at = planeB + (10 * 128 + i) * 2;
			back += hex((machine.vdp.vram.get(at) << 8) | machine.vdp.vram.get(at + 1), 4) + " ";
		}
		Sys.println(back);
		Sys.println("  vsram " + hex(machine.vdp.vsram[0], 4) + " " + hex(machine.vdp.vsram[1], 4)
			+ "  pixel(80,80)=" + hex(machine.vdp.renderer.pixels[80 * Renderer.MAX_WIDTH + 80], 6)
			+ "  cram0=" + hex(machine.vdp.cram[0], 4) + " cram1=" + hex(machine.vdp.cram[1], 4));

		final colours = new Map<Int, Bool>();
		var ink = 0;
		final background = machine.vdp.renderer.pixels[0];
		for (i in 0...Renderer.MAX_WIDTH * machine.vdp.renderer.height) {
			final pixel = machine.vdp.renderer.pixels[i];
			colours.set(pixel, true);
			if (pixel != background) ink++;
		}

		var distinct = 0;
		for (colour in colours.keys()) distinct++;
		Sys.println("  screen " + distinct + " distinct colours, " + ink + " pixels away from the corner one");

		var digest = 0;
		for (y in 0...machine.vdp.renderer.height) {
			for (x in 0...machine.vdp.renderer.width) {
				digest = (digest * 31 + machine.vdp.renderer.pixels[y * Renderer.MAX_WIDTH + x]) | 0;
			}
		}
		Sys.println("  digest " + StringTools.hex(digest, 8) + " of the frame it ended on");
		return digest;
	}

	static inline function hex(value:Int, width:Int):String {
		return StringTools.hex(value & 0xFFFFFF, width);
	}
}

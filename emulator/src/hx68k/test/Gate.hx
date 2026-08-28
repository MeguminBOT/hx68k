package hx68k.test;

import hx68k.test.md.FifoCheck;
import hx68k.test.md.GameCheck;
import hx68k.test.md.OpnCheck;
import hx68k.test.md.PatternCheck;
import hx68k.test.md.PsgCheck;
import hx68k.test.md.RenderCheck;
import hx68k.test.md.RomCheck;
import hx68k.test.md.SlotCheck;
import hx68k.test.md.SoundCheck;
import hx68k.test.md.Speed;
import hx68k.test.OpnFixtures;
import hx68k.test.md.SpriteCheck;
import hx68k.test.md.StateCheck;
import hx68k.test.md.ViewCheck;

class Gate {
	static function main():Void {
		final args = Sys.args();
		if (args.length == 0) {
			usage();
			Sys.exit(2);
		}

		final rest = args.slice(1);

		switch (args[0]) {
			case "bench": Bench.run(rest);
			case "debug": hx68k.debug.DebugTool.run(rest);
			case "disassembly": DisassemblyCheck.run(rest);
			case "dump": SstDump.run(rest);
			case "fifo": FifoCheck.run(rest);
			case "fixtures": OpnFixtures.run(rest);
			case "game": GameCheck.run(rest);
			case "gdb": GdbCheck.run();
			case "layout": LayoutCheck.run();
			case "map": hx68k.map.MapTool.run(rest);
			case "opn": OpnCheck.run(rest);
			case "pattern": PatternCheck.run(rest);
			case "psg": PsgCheck.run();
			case "render": RenderCheck.run(rest);
			case "rom": RomCheck.run(rest);
			case "settings": SettingsCheck.run(rest);
			case "slot": SlotCheck.run();
			case "sound": SoundCheck.run(rest);
			case "sprite": SpriteCheck.run(rest);
			case "speed": Speed.run(rest);
			case "sst": SstConformance.run(rest);
			case "state": StateCheck.run(rest);
			case "view": ViewCheck.run();
			case "widget": WidgetCheck.run();
			case "z80": Z80Conformance.run(rest);
			case "z80convert": Z80Convert.run(rest);
			case _:
				Sys.println("no program named " + args[0]);
				usage();
				Sys.exit(2);
		}
	}

	static function usage():Void {
		Sys.println("usage: gate <program> [arguments]");
		Sys.println("  bench debug disassembly dump fifo fixtures game gdb layout map opn");
		Sys.println("  pattern psg render rom settings slot sound speed sprite sst state");
		Sys.println("  view widget z80 z80convert");
	}
}

package hx68k.test;

class Gate {
	static function main():Void {
		final args = Sys.args();
		if (args.length == 0) {
			usage();
			Sys.exit(2);
		}

		final rest = args.slice(1);

		switch (args[0]) {
			case "bench": hx68k.md.Bench.run(rest);
			case "debug": hx68k.debug.DebugTool.run(rest);
			case "disassembly": DisassemblyCheck.run(rest);
			case "fifo": FifoCheck.run(rest);
			case "game": GameCheck.run(rest);
			case "layout": LayoutCheck.run();
			case "map": hx68k.map.MapTool.run(rest);
			case "opn": OpnCheck.run(rest);
			case "pattern": PatternCheck.run(rest);
			case "psg": PsgCheck.run();
			case "render": RenderCheck.run(rest);
			case "rom": hx68k.md.RomCheck.run(rest);
			case "settings": SettingsCheck.run(rest);
			case "slot": SlotCheck.run();
			case "sound": SoundCheck.run(rest);
			case "sst": SstConform.run(rest);
			case "state": StateCheck.run(rest);
			case "view": ViewCheck.run();
			case "widget": WidgetCheck.run();
			case "z80": Z80Conform.run(rest);
			case _:
				Sys.println("no program named " + args[0]);
				usage();
				Sys.exit(2);
		}
	}

	static function usage():Void {
		Sys.println("usage: gate <program> [arguments]");
		Sys.println("  bench debug disassembly fifo game layout map opn pattern render");
		Sys.println("  psg rom settings slot sound sst state view widget z80");
	}
}

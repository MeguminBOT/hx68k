import sys.FileSystem;
import sys.io.File;

typedef Source = {
	final name:String;
	final group:String;
	final url:String;
	final present:String;
	final size:String;
	final about:String;
}

class Run {
	static inline final SDL_VERSION = "3.4.14";
	static inline final MINIAUDIO_COMMIT = "9634bedb5b5a2ca38c1ee7108a9358a4e233f14d";

	static final SOURCES:Array<Source> = [
		{
			name: "SGDK", group: "build",
			url: "https://github.com/Stephane-D/SGDK.git",
			present: "SGDK/inc", size: "238 MB",
			about: "the m68k toolchain and library every ROM is built with"
		},
		{
			name: "reflaxe", group: "build",
			url: "https://github.com/SomeRanDev/reflaxe.git",
			present: "reflaxe/src", size: "4 MB",
			about: "the framework the compiler backend is written on"
		},
		{
			name: "reflaxe.CPP", group: "build",
			url: "https://github.com/SomeRanDev/reflaxe.CPP.git",
			present: "reflaxe.CPP/src", size: "3 MB",
			about: "the backend the compiler was modelled on"
		},
		{
			name: "SDL3", group: "build",
			url: "", present: "SDL3/include", size: "12 MB",
			about: "the window, called directly. A system package off Windows"
		},
		{
			name: "miniaudio", group: "build",
			url: "", present: "miniaudio/miniaudio.h", size: "1 MB",
			about: "the audio device, called directly by emulator/native"
		},
		{
			name: "Musashi", group: "test",
			url: "https://github.com/kstenerud/Musashi.git",
			present: "Musashi/m68kcpu.c", size: "2 MB",
			about: "the known-good 68000 the compiler suite checks its answers against"
		},
		{
			name: "Nuked-OPN2", group: "test",
			url: "https://github.com/nukeykt/Nuked-OPN2.git",
			present: "Nuked-OPN2/ym3438.c", size: "1 MB",
			about: "the FM reference the YM2612 is held to, sample for sample"
		},
		{
			name: "VDPFIFOTesting", group: "test",
			url: "", present: "VDPFIFOTesting/VDPFIFOTesting.bin", size: "512 KB",
			about: "Nemesis' VDP port access ROM: fifteen suites the VDP's timing is held to"
		},
		{
			name: "M68000Tests", group: "test",
			url: "", present: "M68000Tests/illegal.bin", size: "1 MB",
			about: "two self-checking 68000 ROMs: the illegal opcodes and the BCD instructions"
		},
		{
			name: "SpriteMaskingTest", group: "test",
			url: "", present: "SpriteMaskingTest/sprites.bin", size: "256 KB",
			about: "Nemesis' sprite masking and overflow ROM: nine tests, in both widths"
		},
		{
			name: "240pTestSuite", group: "test",
			url: "", present: "240pTestSuite/240p.bin", size: "256 KB",
			about: "Artemio Urbina's pattern ROM: what the renderer is looked at through"
		},
		{
			name: "SingleStepTests-m68000", group: "test",
			url: "https://github.com/SingleStepTests/m68000.git",
			present: "SingleStepTests-m68000", size: "182 MB",
			about: "317,500 fixtures: the 68000's specification"
		},
		{
			name: "SingleStepTests-z80", group: "test",
			url: "https://github.com/SingleStepTests/z80.git",
			present: "SingleStepTests-z80", size: "1.2 GB",
			about: "1,604,000 fixtures: the z80's specification"
		}
	];

	static function main():Void {
		final args = Sys.args();
		final last = args.length > 0 ? args[args.length - 1] : "";
		final handed = last != "" && !StringTools.startsWith(last, "-")
			&& FileSystem.exists(last) && FileSystem.isDirectory(last);
		final called = handed ? args.pop() : Sys.getCwd();

		var root = findRoot(called);
		if (root == null) root = findRoot(Sys.getCwd());
		if (root == null) {
			Sys.println("hx68k: run this from inside the repository");
			Sys.exit(1);
		}

		final command = args.length > 0 ? args[0] : "help";
		final flags = args.slice(1);

		switch (command) {
			case "setup": setup(root, flags.indexOf("--minimal") >= 0);
			case "check": check(root);
			case "list": list(root);
			case "build": build(root, chosen(root, flags), flags.indexOf("--debug") >= 0);
			case "rom": buildRom(root, called, flags);
			case "player": buildPlayer(root, called, flags);
			case "run": play(root, flags);
			case "gate": gate(root, flags);
			case "test": suite(root, flags);
			case "pad": padRom(called, flags);
			case "new": scaffold(root, called, flags);
			case _: help();
		}
	}

	static function help():Void {
		Sys.println("");
		Sys.println("  haxelib run hx68k setup              everything needed to build and to pass the gate");
		Sys.println("  haxelib run hx68k setup --minimal    only what is needed to build a ROM and the emulator");
		Sys.println("  haxelib run hx68k check              what is present and what is missing");
		Sys.println("");
		Sys.println("  haxelib run hx68k new <name>         a project that builds and boots, ready to edit");
		Sys.println("  haxelib run hx68k rom [dir] [debug]  build that project into a ROM");
		Sys.println("  haxelib run hx68k run <rom>          run it in the debugger emulator");
		Sys.println("  haxelib run hx68k player <rom>       one executable with that ROM inside it");
		Sys.println("");
		Sys.println("  haxelib run hx68k build              the debugger emulator");
		Sys.println("  haxelib run hx68k build sst z80      those targets");
		Sys.println("  haxelib run hx68k build --all        every target");
		Sys.println("  haxelib run hx68k build --debug      the same, carrying debug information");
		Sys.println("  haxelib run hx68k list               every target and where it is put");
		Sys.println("");
		Sys.println("  haxelib run hx68k test               the gate: every check, in order");
		Sys.println("  haxelib run hx68k gate               every check and tool the gate can run alone");
		Sys.println("  haxelib run hx68k gate sst MOVE.w -f one of them, on one group");
		Sys.println("");
		Sys.println("  haxelib run hx68k pad <rom.bin> -sizealign 131072 -checksum");
		Sys.println("                                       pad a ROM and write its header checksum");
		Sys.println("");
		Sys.println("  everything a build makes goes under export/md, and nothing else is written.");
		Sys.println("");
	}

	static function buildRom(root:String, called:String, flags:Array<String>):Void {
		final named = flags.filter(f -> !StringTools.startsWith(f, "-"));
		final profile = named.length > 0 && named[named.length - 1] == "debug" ? "debug" : "";
		if (profile != "") named.pop();

		final where = named.length > 0 ? absolute(called, named[0]) : called;

		if (!FileSystem.exists(where + "/build.hxml")) {
			Sys.println("hx68k: no build.hxml in " + where);
			Sys.exit(1);
		}

		Sys.exit(shell(where, [root + "/sdk/rom.sh"].concat(profile == "" ? [] : [profile])));
	}

	static function buildPlayer(root:String, called:String, flags:Array<String>):Void {
		final named = flags.filter(f -> !StringTools.startsWith(f, "-"));
		if (named.length == 0) {
			Sys.println("hx68k: player needs a ROM, as in haxelib run hx68k player mygame.bin");
			Sys.exit(1);
		}

		final rom = absolute(called, named[0]);
		if (!FileSystem.exists(rom)) {
			Sys.println("hx68k: no file at " + rom);
			Sys.exit(1);
		}

		final title = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(rom));
		release(title);
		built(root, "player", flags.indexOf("--debug") >= 0,
			["-resource", nativePath(rom) + "@" + title]);
		ship(root, "player", title);

		Sys.println("");
		Sys.println("  export/md/player/bin/" + title + exeSuffix());
		Sys.println("");
	}

	static function gate(root:String, flags:Array<String>):Void {
		if (Sys.getEnv("GATE_BUILT") != "1") {
			built(root, "gate", false, []);
			ship(root, "gate");
		}

		final binary = root + "/export/md/tests/bin/gate" + exeSuffix();
		if (!FileSystem.exists(binary)) {
			Sys.println("hx68k: the gate binary is not at " + binary);
			Sys.exit(1);
		}

		Sys.exit(Sys.command(binary, flags));
	}

	static function suite(root:String, flags:Array<String>):Void {
		Sys.exit(shell(root, [root + "/tests/run.sh"].concat(flags)));
	}

	static function shell(where:String, command:Array<String>):Int {
		final here = Sys.getCwd();
		Sys.setCwd(where);

		var code = 0;
		try {
			code = Sys.command("bash", command);
		} catch (e:Dynamic) {
			Sys.println("hx68k: bash is needed to run " + command[0]);
			code = 1;
		}

		Sys.setCwd(here);
		return code;
	}

	static function exeSuffix():String {
		return Sys.systemName() == "Windows" ? ".exe" : "";
	}

	static function scaffold(root:String, where:String, flags:Array<String>):Void {
		final name = flags.length > 0 && !StringTools.startsWith(flags[0], "-") ? flags[0] : "";

		if (name == "") {
			Sys.println("hx68k: new needs a name, as in haxelib run hx68k new mygame");
			Sys.exit(1);
		}

		final at = haxe.io.Path.join([where, name]);

		if (FileSystem.exists(at)) {
			Sys.println("hx68k: " + at + " is already there");
			Sys.exit(1);
		}

		final posix = StringTools.replace(root, "\\", "/");

		FileSystem.createDirectory(at + "/hx");

		File.saveContent(at + "/build.hxml", buildFile(posix, name));
		File.saveContent(at + "/hx/Main.hx", firstProgram(name));
		File.saveContent(at + "/.gitignore", "export/\n");

		final built = "export/md/rom/" + name + "/bin/rom.bin";

		Sys.println("");
		Sys.println("  " + at);
		Sys.println("");
		Sys.println("  cd " + name);
		Sys.println("  haxelib run hx68k rom                builds " + built);
		Sys.println("  haxelib run hx68k run " + built + "   runs it in the emulator");
		Sys.println("");
	}

	static function buildFile(root:String, name:String):String {
		return "-cp " + root + "/compiler/src\n"
			+ "-cp " + root + "/compiler/std\n"
			+ "-cp " + root + "/compiler/std/md/_std\n"
			+ "-cp " + root + "/sdk/src\n"
			+ "-lib reflaxe\n"
			+ "-D md\n"
			+ "-D MegaDrive\n"
			+ "-D md-output=export/md/rom/" + name + "/src\n"
			+ "--macro mdcompiler.CompilerInit.Start()\n"
			+ "-cp hx\n"
			+ "-dce full\n"
			+ "-main Main\n";
	}

	static function firstProgram(name:String):String {
		return "package;\n"
			+ "\n"
			+ "import md.Boot;\n"
			+ "import md.Colors;\n"
			+ "import md.Font;\n"
			+ "import md.System;\n"
			+ "\n"
			+ "class Main {\n"
			+ "\tstatic var frame:Int = 0;\n"
			+ "\n"
			+ "\t@:md.main\n"
			+ "\tstatic function main():Void {\n"
			+ "\t\tBoot.begin();\n"
			+ "\t\tFont.loadNormal(1);\n"
			+ "\n"
			+ "\t\tColors.setColor(0, 0x0400);\n"
			+ "\t\tColors.setColor(15, 0x0EEE);\n"
			+ "\t\tFont.write(\"" + name.toUpperCase() + "\", 2, 2);\n"
			+ "\t\tBoot.show();\n"
			+ "\n"
			+ "\t\twhile (true) {\n"
			+ "\t\t\tframe++;\n"
			+ "\t\t\tColors.setColor(0, ((frame >> 3) & 0x0E) << 8);\n"
			+ "\t\t\tSystem.nextFrame();\n"
			+ "\t\t}\n"
			+ "\t}\n"
			+ "}\n";
	}

	static function findRoot(from:String):Null<String> {
		var at = haxe.io.Path.removeTrailingSlashes(FileSystem.absolutePath(from));
		while (true) {
			if (FileSystem.exists(at + "/emulator") && FileSystem.exists(at + "/compiler")) return at;
			final up = haxe.io.Path.removeTrailingSlashes(haxe.io.Path.directory(at));
			if (up == at || up == "") return null;
			at = up;
		}
	}

	static function setup(root:String, minimal:Bool):Void {
		final vendor = root + "/vendor";
		if (!FileSystem.exists(vendor)) FileSystem.createDirectory(vendor);

		final wanted = SOURCES.filter(s -> !minimal || s.group == "build");
		var fetched = 0;
		var already = 0;

		Sys.println("");
		for (source in wanted) {
			if (FileSystem.exists(vendor + "/" + source.present)) {
				Sys.println("  " + pad(source.name) + "already there");
				already++;
				continue;
			}

			Sys.println("  " + pad(source.name) + "fetching, about " + source.size);
			final ok = switch (source.name) {
				case "SDL3": sdl(vendor);
				case "miniaudio": miniaudio(vendor);
				case "VDPFIFOTesting": fifo(vendor);
				case "M68000Tests": opcodes(vendor);
				case "SpriteMaskingTest": sprites(vendor);
				case "240pTestSuite": patterns(vendor);
				case _: clone(source, vendor);
			}

			if (!ok) {
				Sys.println("  " + pad("") + "failed, see above");
				Sys.exit(1);
			}
			fetched++;
		}

		Sys.println("");
		Sys.println("  " + fetched + " fetched, " + already + " already there");
		if (minimal) Sys.println("  the gate needs the rest: haxelib run hx68k setup");
		else Sys.println("  ./tests/run.sh");
		Sys.println("");
	}

	static function jvm():Bool {
		try {
			final probe = new sys.io.Process("java", ["-version"]);
			final code = probe.exitCode();
			probe.close();
			return code == 0;
		} catch (e:Dynamic) {
			return false;
		}
	}

	static function check(root:String):Void {
		final vendor = root + "/vendor";
		Sys.println("");
		for (group in ["build", "test"]) {
			Sys.println("  " + group);
			for (source in SOURCES) {
				if (source.group != group) continue;
				final here = FileSystem.exists(vendor + "/" + source.present);
				Sys.println("    " + (here ? "[x] " : "[ ] ") + pad(source.name)
					+ StringTools.lpad(source.size, " ", 8) + "   " + source.about);
			}
		}

		Sys.println("");
		Sys.println("  optional");
		Sys.println("    " + (jvm() ? "[x] " : "[ ] ") + pad("a JVM") + StringTools.lpad("", " ", 8)
			+ "   the resource pipeline is held to SGDK's rescomp where one is present");
		Sys.println("");
	}

	static function clone(source:Source, vendor:String):Bool {
		final into = vendor + "/" + source.name;
		return Sys.command("git", ["clone", "--depth", "1", source.url, into]) == 0;
	}

	static function sdl(vendor:String):Bool {
		final base = "https://github.com/libsdl-org/SDL/releases/download/release-" + SDL_VERSION;
		final archive = vendor + "/.sdl3.zip";
		final staging = vendor + "/.sdl3";

		if (!download(base + "/SDL3-devel-" + SDL_VERSION + "-VC.zip", archive)) return false;
		if (FileSystem.exists(staging)) remove(staging);
		FileSystem.createDirectory(staging);
		if (Sys.command("tar", ["-xf", archive, "-C", staging]) != 0) return false;

		final unpacked = staging + "/SDL3-" + SDL_VERSION;
		FileSystem.createDirectory(vendor + "/SDL3");
		FileSystem.createDirectory(vendor + "/SDL3/lib");
		copyTree(unpacked + "/include", vendor + "/SDL3/include");
		File.copy(unpacked + "/lib/x64/SDL3.dll", vendor + "/SDL3/lib/SDL3.dll");
		File.copy(unpacked + "/lib/x64/SDL3.lib", vendor + "/SDL3/lib/SDL3.lib");
		File.copy(unpacked + "/LICENSE.txt", vendor + "/SDL3/LICENSE.txt");

		FileSystem.deleteFile(archive);
		remove(staging);
		return true;
	}

	static function miniaudio(vendor:String):Bool {
		final base = "https://raw.githubusercontent.com/mackron/miniaudio/" + MINIAUDIO_COMMIT;
		if (!FileSystem.exists(vendor + "/miniaudio")) FileSystem.createDirectory(vendor + "/miniaudio");
		return download(base + "/miniaudio.h", vendor + "/miniaudio/miniaudio.h")
			&& download(base + "/LICENSE", vendor + "/miniaudio/LICENSE");
	}

	static function fifo(vendor:String):Bool {
		final archive = vendor + "/.vdpfifo.zip";
		final into = vendor + "/VDPFIFOTesting";

		if (!download("http://nemesis.exodusemulator.com/MegaDrive/Tests/VDPFIFOTesting/"
				+ "VDPFIFOTesting.zip", archive)) return false;

		if (!FileSystem.exists(into)) FileSystem.createDirectory(into);
		unpack(archive, into);

		FileSystem.deleteFile(archive);
		return FileSystem.exists(into + "/VDPFIFOTesting.bin");
	}

	static function opcodes(vendor:String):Bool {
		final into = vendor + "/M68000Tests";
		if (!FileSystem.exists(into)) FileSystem.createDirectory(into);

		final wanted = [
			{ id: "1NKagoNVmUEZB9DojKcmXSsSlJY96xS8-", zipped: "itest.BIN", named: "illegal.bin" },
			{ id: "1EgwX-T4g9bUcsGc6FywO_-4Irxjo1Vgn", zipped: "bcd-verifier-u1.bin", named: "bcd.bin" }
		];

		for (each in wanted) {
			final archive = into + "/.fetched.zip";
			if (!download("https://drive.google.com/uc?id=" + each.id + "&export=download", archive)) {
				return false;
			}

			unpack(archive, into);
			FileSystem.deleteFile(archive);

			if (!FileSystem.exists(into + "/" + each.zipped)) return false;
			if (FileSystem.exists(into + "/" + each.named)) FileSystem.deleteFile(into + "/" + each.named);
			FileSystem.rename(into + "/" + each.zipped, into + "/" + each.named);
		}

		return true;
	}

	static function sprites(vendor:String):Bool {
		final into = vendor + "/SpriteMaskingTest";
		if (!FileSystem.exists(into)) FileSystem.createDirectory(into);

		return download("https://archive.org/download/Sprite_Masking_Test_ROM_PD/"
			+ "Sprite_Masking_Test_ROM_PD.bin", into + "/sprites.bin");
	}

	static function patterns(vendor:String):Bool {
		final into = vendor + "/240pTestSuite";
		if (!FileSystem.exists(into)) FileSystem.createDirectory(into);

		return download("https://archive.org/download/240p_Test_Suite_v1.07_by_Artemio_Ua_PD/"
			+ "240p_Test_Suite_v1.07_by_Artemio_Urbina_PD.bin", into + "/240p.bin");
	}

	static function unpack(archive:String, into:String):Void {
		final ways = [
			{ tool: "unzip", flags: ["-o", "-q", archive, "-d", into] },
			{ tool: "tar", flags: ["-xf", archive, "-C", into] }
		];

		for (way in ways) {
			try {
				final run = new sys.io.Process(way.tool, way.flags);
				final code = run.exitCode();
				run.close();
				if (code == 0) return;
			} catch (e:Dynamic) {}
		}
	}

	static function download(url:String, into:String):Bool {
		return Sys.command("curl", ["-sL", "--fail", "-o", into, url]) == 0;
	}

	static function copyTree(from:String, to:String):Void {
		if (!FileSystem.exists(to)) FileSystem.createDirectory(to);
		for (entry in FileSystem.readDirectory(from)) {
			final source = from + "/" + entry;
			final target = to + "/" + entry;
			if (FileSystem.isDirectory(source)) copyTree(source, target);
			else File.copy(source, target);
		}
	}

	static function remove(path:String):Void {
		if (!FileSystem.exists(path)) return;
		if (!FileSystem.isDirectory(path)) {
			FileSystem.deleteFile(path);
			return;
		}
		for (entry in FileSystem.readDirectory(path)) remove(path + "/" + entry);
		FileSystem.deleteDirectory(path);
	}

	static function pad(name:String):String {
		return StringTools.rpad(name, " ", 24);
	}

	static final HOMES:Array<String> = ["emulator", "sdk"];

	static function targets(root:String):Array<String> {
		final out = [];
		for (home in HOMES) {
			for (entry in FileSystem.readDirectory(root + "/" + home)) {
				if (StringTools.endsWith(entry, ".hxml")) out.push(entry.substr(0, entry.length - 5));
			}
		}
		out.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	static function homeOf(root:String, target:String):String {
		for (home in HOMES) {
			if (FileSystem.exists(root + "/" + home + "/" + target + ".hxml")) return home;
		}
		return "";
	}

	static function setting(root:String, target:String, flag:String):String {
		final home = homeOf(root, target);
		if (home == "") return "";

		final path = root + "/" + home + "/" + target + ".hxml";
		for (line in File.getContent(path).split("
")) {
			final trimmed = StringTools.trim(line);
			if (StringTools.startsWith(trimmed, flag + " ")) {
				return StringTools.trim(trimmed.substr(flag.length + 1));
			}
		}
		return "";
	}

	static function chosen(root:String, flags:Array<String>):Array<String> {
		if (flags.indexOf("--all") >= 0) return targets(root);
		final named = flags.filter(f -> !StringTools.startsWith(f, "-"));
		return named.length == 0 ? ["debugger"] : named;
	}

	static function nativePath(path:String):String {
		return StringTools.replace(FileSystem.absolutePath(path), "\\", "/");
	}

	static function list(root:String):Void {
		Sys.println("");
		for (target in targets(root)) {
			final shipped = "export/md/" + kindOf(target) + "/bin/" + shipName(target)
				+ (setting(root, target, "-neko") != "" ? ".n" : exeSuffix());
			Sys.println("  " + pad(target) + shipped);
		}
		Sys.println("");
		Sys.println("  every check and tool the gate runs is inside 'gate', chosen by its first");
		Sys.println("  argument: haxelib run hx68k gate");
		Sys.println("");
	}

	static function build(root:String, names:Array<String>, debug:Bool):Void {
		for (name in names) {
			release(name);
			built(root, name, debug, []);
			ship(root, name);
		}

		Sys.println("");
		Sys.println("  " + names.length + " built");
		Sys.println("");
	}

	static function built(root:String, name:String, debug:Bool, extra:Array<String>):Void {
		final vendor = root + "/vendor";
		if (Sys.systemName() == "Windows" && !FileSystem.exists(vendor + "/SDL3/lib/SDL3.lib")) {
			Sys.println("SDL3 is missing from vendor/. Run: haxelib run hx68k setup");
			Sys.exit(1);
		}

		final home = homeOf(root, name);
		if (home == "") {
			Sys.println("no target called " + name + ". Try: haxelib run hx68k list");
			Sys.exit(1);
		}

		final flags = [
			"-D", "SDL3PATH=" + nativePath(vendor + "/SDL3"),
			"-D", "MINIAUDIOPATH=" + nativePath(vendor + "/miniaudio"),
			"-D", "NATIVEPATH=" + nativePath(root + "/emulator/native")
		].concat(extra);
		if (debug) flags.push("-debug");

		Sys.println("  " + pad(name) + "building");

		final here = Sys.getCwd();
		Sys.setCwd(root + "/" + home);
		final code = Sys.command("haxe", [name + ".hxml"].concat(flags));
		Sys.setCwd(here);

		if (code != 0) Sys.exit(code);
	}

	static final SHIPPED:Map<String, String> = ["debugger" => "hx68k-debugger"];

	static function shipName(target:String):String {
		final named = SHIPPED.get(target);
		return named == null ? target : named;
	}

	static function kindOf(target:String):String {
		return switch (target) {
			case "debugger": "emulator";
			case "player": "player";
			case _: "tests";
		};
	}

	static function release(target:String):Void {
		if (Sys.systemName() != "Windows") return;
		try {
			final killer = new sys.io.Process("taskkill", ["/F", "/IM", shipName(target) + ".exe"]);
			killer.exitCode();
			killer.close();
		} catch (e:Dynamic) {}
	}

	static function ship(root:String, name:String, ?as:String):Void {
		final into = setting(root, name, "-cpp");
		final main = setting(root, name, "-main");
		if (into == "" || main == "") return;

		final dir = haxe.io.Path.normalize(root + "/" + homeOf(root, name) + "/" + into);
		final stem = main.split(".").pop();

		var exe = dir + "/" + stem + ".exe";
		var suffix = ".exe";
		if (!FileSystem.exists(exe)) {
			exe = dir + "/" + stem;
			suffix = "";
		}
		if (!FileSystem.exists(exe)) return;

		final bin = haxe.io.Path.normalize(root + "/export/md/" + kindOf(name) + "/bin");
		if (!FileSystem.exists(bin)) FileSystem.createDirectory(bin);
		File.copy(exe, bin + "/" + (as == null ? shipName(name) : as) + suffix);

		final source = File.getContent(root + "/" + homeOf(root, name) + "/src/"
			+ main.split(".").join("/") + ".hx");
		if (source.indexOf("hx68k.host") >= 0 && Sys.systemName() == "Windows") {
			File.copy(root + "/vendor/SDL3/lib/SDL3.dll", bin + "/SDL3.dll");
		}
	}

	static function padRom(called:String, flags:Array<String>):Void {
		var name = "";
		var align = 256;
		var fill = 0;
		var checksum = false;
		var at = 0;

		while (at < flags.length) {
			final flag = flags[at++];
			switch (flag.toLowerCase()) {
				case "-sizealign": align = number(flag, flags[at++]);
				case "-fill": fill = number(flag, flags[at++]) & 0xFF;
				case "-checksum": checksum = true;
				case _:
					if (StringTools.startsWith(flag, "-")) fail("no option called " + flag);
					name = flag;
			}
		}

		if (name == "") fail("nothing to pad. Try: haxelib run hx68k pad <rom.bin> -sizealign 131072 -checksum");
		final path = absolute(called, name);
		if (!FileSystem.exists(path)) fail("no file at " + path);
		if (align < 4) align = 4;

		final rom = File.getBytes(path);
		final over = rom.length % align;
		final padded = haxe.io.Bytes.alloc(over == 0 ? rom.length : rom.length + (align - over));
		padded.fill(0, padded.length, fill);
		padded.blit(0, rom, 0, rom.length);
		if (checksum) writeChecksum(padded);
		File.saveBytes(path, padded);
	}

	static function writeChecksum(rom:haxe.io.Bytes):Void {
		final offset = 0x18E;
		if (rom.length < offset + 2) fail("a ROM shorter than its own header cannot carry a checksum");

		rom.set(offset, 0);
		rom.set(offset + 1, 0);

		var folded = 0;
		var at = 0;
		while (at + 3 < rom.length) {
			folded ^= (rom.get(at) << 24) | (rom.get(at + 1) << 16) | (rom.get(at + 2) << 8) | rom.get(at + 3);
			at += 4;
		}

		final sum = (folded ^ (folded >> 16)) & 0xFFFF;
		rom.set(offset, (sum >> 8) & 0xFF);
		rom.set(offset + 1, sum & 0xFF);
	}

	static function number(flag:String, given:Null<String>):Int {
		final value:Null<Int> = given == null ? null : Std.parseInt(given);
		if (value == null) {
			fail(flag + " wants a number after it");
			return 0;
		}
		return value;
	}

	static function absolute(called:String, name:String):String {
		final rooted = StringTools.startsWith(name, "/") || StringTools.startsWith(name, "\\")
			|| (name.length > 1 && name.charAt(1) == ":");
		return haxe.io.Path.normalize(FileSystem.absolutePath(rooted ? name : called + "/" + name));
	}

	static function fail(why:String):Void {
		Sys.stderr().writeString("hx68k pad: " + why + "
");
		Sys.exit(2);
	}

	static function play(root:String, flags:Array<String>):Void {
		final given = flags.filter(f -> !StringTools.startsWith(f, "-"));
		build(root, ["window"], false);

		final exe = root + "/export/md/emulator/bin/hx68k-debugger" + exeSuffix();
		final rom = given.length > 0 ? FileSystem.absolutePath(given[0]) : null;
		Sys.exit(Sys.command(exe, rom == null ? [] : [rom]));
	}
}

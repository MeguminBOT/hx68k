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
			about: "the window, called directly by emulator/native"
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
			about: "the functional oracle the compiler suite is checked against"
		},
		{
			name: "Nuked-OPN2", group: "test",
			url: "https://github.com/nukeykt/Nuked-OPN2.git",
			present: "Nuked-OPN2/ym3438.c", size: "1 MB",
			about: "the FM reference the YM2612 is held to, sample for sample"
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

		final root = findRoot(called);
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
			case "run": play(root, flags);
			case _: help();
		}
	}

	static function help():Void {
		Sys.println("");
		Sys.println("  haxelib run hx68k setup              everything needed to build and to pass the gate");
		Sys.println("  haxelib run hx68k setup --minimal    only what is needed to build a ROM and the window");
		Sys.println("  haxelib run hx68k check              what is present and what is missing");
		Sys.println("");
		Sys.println("  haxelib run hx68k build              the emulator window");
		Sys.println("  haxelib run hx68k build sst z80      those targets");
		Sys.println("  haxelib run hx68k build --all        every target");
		Sys.println("  haxelib run hx68k build --debug      the same, carrying debug information");
		Sys.println("  haxelib run hx68k list               every target and where it is put");
		Sys.println("  haxelib run hx68k run <rom>          build the window and run it");
		Sys.println("");
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
			final ok = source.name == "SDL3" ? sdl(vendor)
				: (source.name == "miniaudio" ? miniaudio(vendor) : clone(source, vendor));

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

	static function targets(root:String):Array<String> {
		final out = [];
		for (entry in FileSystem.readDirectory(root + "/emulator")) {
			if (StringTools.endsWith(entry, ".hxml")) out.push(entry.substr(0, entry.length - 5));
		}
		out.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	static function setting(root:String, target:String, flag:String):String {
		final path = root + "/emulator/" + target + ".hxml";
		if (!FileSystem.exists(path)) return "";
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
		return named.length == 0 ? ["window"] : named;
	}

	static function nativePath(path:String):String {
		return StringTools.replace(FileSystem.absolutePath(path), "\\", "/");
	}

	static function list(root:String):Void {
		Sys.println("");
		for (target in targets(root)) {
			final cpp = setting(root, target, "-cpp");
			final neko = setting(root, target, "-neko");
			Sys.println("  " + pad(target) + (cpp != "" ? cpp : neko));
		}
		Sys.println("");
	}

	static function build(root:String, names:Array<String>, debug:Bool):Void {
		final vendor = root + "/vendor";
		if (!FileSystem.exists(vendor + "/SDL3/lib/SDL3.lib")) {
			Sys.println("SDL3 is missing from vendor/. Run: haxelib run hx68k setup");
			Sys.exit(1);
		}

		final flags = [
			"-D", "SDL3PATH=" + nativePath(vendor + "/SDL3"),
			"-D", "MINIAUDIOPATH=" + nativePath(vendor + "/miniaudio"),
			"-D", "NATIVEPATH=" + nativePath(root + "/emulator/native")
		];
		if (debug) flags.push("-debug");

		final here = Sys.getCwd();
		for (name in names) {
			if (!FileSystem.exists(root + "/emulator/" + name + ".hxml")) {
				Sys.println("no target called " + name + ". Try: haxelib run hx68k list");
				Sys.exit(1);
			}

			if (name == "window") release();

			Sys.println("  " + pad(name) + "building");
			Sys.setCwd(root + "/emulator");
			final code = Sys.command("haxe", [name + ".hxml"].concat(flags));
			Sys.setCwd(here);

			if (code != 0) Sys.exit(code);
			ship(root, name);
		}

		Sys.println("");
		Sys.println("  " + names.length + " built");
		Sys.println("");
	}

	static function release():Void {
		if (Sys.systemName() != "Windows") return;
		try {
			final killer = new sys.io.Process("taskkill", ["/F", "/IM", "hx68k.exe"]);
			killer.exitCode();
			killer.close();
		} catch (e:Dynamic) {}
	}

	static function ship(root:String, name:String):Void {
		final into = setting(root, name, "-cpp");
		final main = setting(root, name, "-main");
		if (into == "" || main == "") return;

		final dir = root + "/emulator/" + into;
		final exe = dir + "/" + main.split(".").pop() + ".exe";
		if (!FileSystem.exists(exe)) return;

		final source = File.getContent(root + "/emulator/src/" + main.split(".").join("/") + ".hx");
		if (source.indexOf("hx68k.host") >= 0) {
			File.copy(root + "/vendor/SDL3/lib/SDL3.dll", dir + "/SDL3.dll");
		}

		if (name == "window") File.copy(exe, dir + "/hx68k.exe");
	}

	static function play(root:String, flags:Array<String>):Void {
		final given = flags.filter(f -> !StringTools.startsWith(f, "-"));
		build(root, ["window"], false);

		final exe = root + "/emulator/bin/window/hx68k.exe";
		final rom = given.length > 0 ? FileSystem.absolutePath(given[0]) : null;
		Sys.exit(Sys.command(exe, rom == null ? [] : [rom]));
	}
}

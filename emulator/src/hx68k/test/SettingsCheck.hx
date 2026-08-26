package hx68k.test;

import hx68k.host.Settings;
import hx68k.host.Group;
import hx68k.host.Grid;
import hx68k.host.Zone.Side;
import hx68k.host.Floating;
import hx68k.host.Metrics;
import hx68k.host.Bindings;

class SettingsCheck {
	static var failures:Int = 0;
	static var checks:Int = 0;

	static var where:String = "";

	static function ok(what:String, held:Bool, saying:String):Void {
		checks++;
		if (held) return;
		failures++;
		Sys.println("  FAIL " + what + ": " + saying);
	}

	static function same(what:String, got:String, wanted:String):Void {
		ok(what, got == wanted, "wanted " + wanted + ", got " + got);
	}

	static function board():Array<Group> {
		final out = new Array<Group>();
		for (name in ["screen", "registers", "disassembly", "stack", "video", "usage"]) {
			final group = new Group(name);
			group.add(name);
			out.push(group);
		}
		return out;
	}

	static function file(name:String):String {
		return where + "/" + name;
	}

	static function directory():Void {
		final held = Settings.directory();

		ok("the settings live somewhere named", held != "", "the directory came back empty");
		ok("under a directory of their own", StringTools.endsWith(held, "/hx68k")
			|| held == ".hx68k", "it is " + held);
		ok("the file sits inside it", Settings.path() == held + "/" + Settings.FILE,
			"the path is " + Settings.path());

		final platform = Sys.systemName();
		final wanted = platform == "Windows" ? "AppData" : (platform == "Mac"
			? "Application Support" : ".config");

		ok("named the way " + platform + " names it", held.indexOf(wanted) >= 0
			|| held == ".hx68k", "it is " + held);

		Sys.println("  the settings would live at " + Settings.path());
	}

	static function roundTrip():Void {
		final written = new Settings();

		written.set("arrangement", "grid");
		written.setWhole("scale", 3);
		written.setFlag("sound", false);
		written.set("layout.grid", "h0.5(@screen,v0.5(@registers,@stack))");
		written.set("something.this.build.does.not.know", "and a value with spaces in it");
		ok("a key with a space in it cannot be stored",
			!written.set("two words", "anything"), "it was stored anyway");

		final at = file("round.cfg");
		ok("the settings write", written.write(at), written.problem);

		final read = new Settings();
		ok("and read back", read.read(at), read.problem);
		same("nothing was wrong with them", read.problem, "");

		same("a word survives", read.text("arrangement", "floating"), "grid");
		ok("a number survives", read.whole("scale", 1) == 3, "scale is " + read.whole("scale", 1));
		ok("a flag survives", !read.flag("sound", true), "sound came back on");
		same("a layout tree survives", read.text("layout.grid", ""),
			"h0.5(@screen,v0.5(@registers,@stack))");
		same("a value with spaces survives whole",
			read.text("something.this.build.does.not.know", ""), "and a value with spaces in it");
		same("a key that was never set falls back", read.text("nothing", "the fallback"),
			"the fallback");

		read.setWhole("scale", 2);
		final again = file("again.cfg");
		read.write(again);

		final third = new Settings();
		third.read(again);
		same("an unknown key is written back by a build that does not know it",
			third.text("something.this.build.does.not.know", ""), "and a value with spaces in it");
		same("the keys keep the order they were first set in", third.keys().join(","),
			"arrangement,scale,sound,layout.grid,something.this.build.does.not.know");
	}

	static function older():Void {
		final at = file("older.cfg");
		sys.io.File.saveContent(at, "# a build from before this one\n"
			+ "scale 2\n"
			+ "\n"
			+ "colourblind on\n"
			+ "framerate cap 120\n");

		final read = new Settings();
		ok("an older file loads", read.read(at), read.problem);
		same("nothing was wrong with it", read.problem, "");
		ok("a setting this build knows loads", read.whole("scale", 1) == 2,
			"scale is " + read.whole("scale", 1));
		ok("one it does not know is kept", read.flag("colourblind", false), "it was dropped");
		same("a value with a space in the middle keeps all of it",
			read.text("framerate", ""), "cap 120");

		read.write(at);
		final back = sys.io.File.getContent(at);
		ok("and is written back", back.indexOf("colourblind on") >= 0, "it went missing:\n" + back);
		ok("a comment is not", back.indexOf("#") < 0, "the comment came back");
	}

	static function malformed():Void {
		final at = file("malformed.cfg");
		sys.io.File.saveContent(at, "scale 2\nnonsense\nsound off\n");

		final read = new Settings();
		ok("a file with a bad line still loads", read.read(at), read.problem);
		ok("and says which line it was", read.problem.indexOf("line 2") >= 0,
			"it said: " + read.problem);
		ok("the good lines before it loaded", read.whole("scale", 1) == 2, "scale is wrong");
		ok("and the good lines after it", !read.flag("sound", true), "sound is wrong");
	}

	static function corrupt():Void {
		final at = file("corrupt.cfg");
		final bytes = haxe.io.Bytes.alloc(64);
		for (index in 0...64) bytes.set(index, index * 3 & 0xFF);
		sys.io.File.saveBytes(at, bytes);

		final read = new Settings();
		ok("a file that is not text loads nothing", !read.read(at), "it claimed to load");
		ok("and says so", read.problem != "", "it said nothing");
		ok("every setting falls back", read.whole("scale", 1) == 1 && read.text("arrangement", "grid") == "grid",
			"something came out of it");

		Sys.println("  a corrupt file says: " + read.problem);

		final missing = new Settings();
		ok("a file that is not there loads nothing", !missing.read(file("never written.cfg")),
			"it claimed to load");
		same("and says nothing about it, since a first run is not a fault", missing.problem, "");
	}

	static function arrangement():Void {
		final groups = board();
		final metrics = new Metrics(16, 32, 1);

		final grid = new Grid();
		grid.anchor("screen", 0.5, Left, 3 / 4);
		grid.adopt(groups);
		grid.place(groups, 1280, 720, metrics);

		groups[1].add("stack");
		groups[3].drop("stack");
		groups[1].active = 1;
		grid.load(grid.save(), groups);
		grid.place(groups, 1280, 720, metrics);

		final tree = grid.save();
		final geometry = Group.written(groups);

		ok("a group with two panels is written as both", geometry.indexOf("registers,stack") >= 0,
			"it wrote " + geometry);

		final settings = new Settings();
		settings.set("layout.grid", tree);
		settings.set("groups", geometry);

		final at = file("layout.cfg");
		settings.write(at);

		final back = new Settings();
		back.read(at);

		final second = board();
		final restored = Group.restore(second, back.text("groups", ""));
		ok("every group came back", restored == groups.length, restored + " of " + groups.length);

		final rebuilt = new Grid();
		rebuilt.anchor("screen", 0.5, Left, 3 / 4);
		rebuilt.load(back.text("layout.grid", ""), second);

		same("the split tree is the one that was saved", rebuilt.save(), tree);
		same("and so is every tab", tabsOf(second), tabsOf(groups));

		rebuilt.place(second, 1280, 720, metrics);
		same("and placing it puts every rectangle back", Group.written(second), geometry);

		final free = new Floating();
		free.adopt(second);
		free.place(second, 1280, 720, metrics);

		final floatingGeometry = Group.written(second);
		final floatingState = free.save();

		final third = board();
		Group.restore(third, floatingGeometry);
		final backAgain = new Floating();
		backAgain.load(floatingState, third);
		backAgain.place(third, 1280, 720, metrics);

		same("a floating arrangement round trips too", Group.written(third), floatingGeometry);
	}

	static function keys():Void {
		final table = new Bindings();
		table.bind("step a line", "ctrl+shift+f7");
		table.bind("pad A", "q");

		final written = new Settings();
		written.set("scale", "2");
		table.write(written);

		final at = file("keys.cfg");
		written.write(at);

		final read = new Settings();
		read.read(at);
		same("nothing was wrong with the keys", read.problem, "");

		final back = new Bindings();
		back.read(read);

		same("a rebound key survives a restart", back.chord("step a line"), "ctrl+shift+f7");
		same("so does a rebound pad button", back.chord("pad A"), "q");
		same("and one that was never touched is still itself", back.chord("pause"), "space");

		final older = new Settings();
		older.set("scale", "2");
		older.set(Bindings.settingOf("pause"), "ctrl+p");

		final partial = new Bindings();
		partial.read(older);
		same("a file naming one key leaves the rest alone", partial.chord("pause") + " "
			+ partial.chord("flat out"), "ctrl+p tab");

		for (action in Bindings.actions()) {
			ok("the settings key for " + action + " can be stored",
				Settings.storable(Bindings.settingOf(action)),
				"it is " + Bindings.settingOf(action));
		}
	}

	static function tabsOf(groups:Array<Group>):String {
		final out = new Array<String>();
		for (group in groups) out.push(group.id + "=" + group.members.join(",") + "@" + group.active);
		return out.join(" ");
	}

	static function main():Void {
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
		where = args.length > 0 ? args[0] : ".settings";
		if (!sys.FileSystem.exists(where)) sys.FileSystem.createDirectory(where);

		Sys.println("");
		Sys.println("where the settings live");
		directory();

		Sys.println("what survives being written and read again");
		roundTrip();
		older();

		Sys.println("what a file this build did not write does");
		malformed();
		corrupt();

		Sys.println("the keys, which have to come back as they were left");
		keys();

		Sys.println("the arrangement, which is the point of keeping any of it");
		arrangement();

		Sys.println("");
		Sys.println(checks + " checks, " + failures + " failures");
		if (failures > 0) Sys.exit(1);
	}
}

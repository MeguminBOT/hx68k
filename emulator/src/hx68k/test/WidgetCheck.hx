package hx68k.test;

import hx68k.host.ui.Focus;
import hx68k.host.ui.Focus.Holder;
import hx68k.host.ui.Field;
import hx68k.host.Keys;
import hx68k.host.Shortcuts;
import hx68k.host.ui.Timeline;

class WidgetCheck {
	static var failures:Int = 0;
	static var checks:Int = 0;

	static function ok(what:String, held:Bool, saying:String):Void {
		checks++;
		if (held) return;
		failures++;
		Sys.println("  FAIL " + what + ": " + saying);
	}

	static function same(what:String, got:String, wanted:String):Void {
		ok(what, got == wanted, "wanted " + wanted + ", got " + got);
	}

	static function shape(field:Field):String {
		final from = field.from();
		final to = field.to();
		final head = field.text.substring(0, from);
		final middle = field.text.substring(from, to);
		final tail = field.text.substring(to);

		return field.selecting() ? head + "[" + middle + "]" + tail : head + "|" + tail;
	}

	static function escaping():Void {
		final focus = new Focus();

		same("nothing focused", Focus.named(focus.top()), "application");
		ok("nothing focused is not busy", !focus.busy(), "an empty stack reported busy");
		same("escape with nothing focused", Focus.named(focus.escape()), "application");

		focus.take(Modal, "preferences");
		same("a modal on top", Focus.named(focus.top()), "modal");
		ok("a modal does not take the keyboard", !focus.typing(), "a modal reported typing");
		same("escape closes the modal", Focus.named(focus.escape()), "modal");
		same("and then quits", Focus.named(focus.top()), "application");

		focus.take(Modal, "preferences");
		focus.take(Field, "filter");
		same("a field over a modal", Focus.named(focus.top()), "field");
		ok("a field takes the keyboard", focus.typing(), "a field did not report typing");

		focus.take(Capture, "bind pause");
		same("a capture over a field", Focus.named(focus.top()), "capture");
		ok("a capture takes the keyboard", focus.typing(), "a capture did not report typing");

		same("escape leaves the capture", Focus.named(focus.escape()), "capture");
		same("escape leaves the field", Focus.named(focus.escape()), "field");
		same("escape closes the modal", Focus.named(focus.escape()), "modal");
		same("escape then quits", Focus.named(focus.escape()), "application");

		focus.clear();
		focus.take(Field, "filter");
		focus.take(Field, "filter");
		ok("the same holder does not stack twice", focus.depth == 1, "depth is " + focus.depth);

		focus.take(Modal, "preferences");
		focus.take(Field, "filter");
		ok("taking again moves it to the top", focus.on("filter") && focus.depth == 2,
			"depth " + focus.depth + ", top " + focus.holding());

		ok("a named holder can be dropped", focus.drop("preferences"), "preferences was not there");
		ok("and is gone", !focus.has("preferences"), "preferences is still there");
		ok("without disturbing the top", focus.on("filter"), "the top is " + focus.holding());
	}

	static function padReach():Void {
		final focus = new Focus();
		final states = [
			{ name: "nothing", kind: Application, pad: true },
			{ name: "a modal", kind: Modal, pad: true },
			{ name: "a field", kind: Field, pad: false },
			{ name: "a capture", kind: Capture, pad: false }
		];

		for (state in states) {
			focus.clear();
			focus.take(state.kind, "under test");
			ok("the pad " + (state.pad ? "hears" : "never hears") + " a key under " + state.name,
				focus.typing() != state.pad, "typing() said " + focus.typing());
		}
	}

	static function editing():Void {
		final field = new Field();

		field.insert("hello");
		same("typing", shape(field), "hello|");

		field.left(false, false);
		field.left(false, false);
		same("left twice", shape(field), "hel|lo");

		field.insert("p");
		same("inserting at the caret", shape(field), "help|lo");

		field.backspace();
		same("backspace", shape(field), "hel|lo");

		field.erase();
		same("delete forward", shape(field), "hel|o");

		field.home(false);
		same("home", shape(field), "|helo");

		field.end(true);
		same("shift end selects to the end", shape(field), "[helo]");

		field.insert("world");
		same("typing over a selection", shape(field), "world|");

		field.insert(" and more");
		field.home(false);
		field.right(false, true);
		same("one word right", shape(field), "world |and more");

		field.right(true, true);
		same("shift word right selects a word", shape(field), "world [and ]more");

		same("cut returns the selection", field.cut(), "and ");
		same("and takes it out", shape(field), "world |more");

		field.end(false);
		field.left(false, true);
		same("one word left", shape(field), "world |more");

		field.all();
		same("select all", shape(field), "[world more]");

		field.commit();
		field.insert("gone");
		ok("a field knows it changed", field.changed(), "changed() said no");
		field.revert();
		same("revert puts it back", shape(field), "world more|");
		ok("and it is unchanged again", !field.changed(), "changed() said yes");

		final capped = new Field("", 4);
		capped.insert("abcdefgh");
		same("a limit holds on insert", shape(capped), "abcd|");
		capped.home(false);
		capped.insert("z");
		same("a full field takes nothing more", shape(capped), "|abcd");

		final clicked = new Field("abcdef");
		clicked.place(2);
		clicked.drag(5);
		same("click then drag selects", shape(clicked), "ab[cde]f");
		clicked.left(false, false);
		same("left collapses a selection to its start", shape(clicked), "ab|cdef");
		clicked.place(2);
		clicked.drag(5);
		clicked.right(false, false);
		same("right collapses a selection to its end", shape(clicked), "abcde|f");
	}

	static function naming():Void {
		final chords = [
			{code: 0x0000001b, mods: Keys.MOD_NONE, said: "escape"},
			{code: 0x00000020, mods: Keys.MOD_NONE, said: "space"},
			{code: 0x00000061, mods: Keys.MOD_NONE, said: "a"},
			{code: 0x40000043, mods: Keys.MOD_NONE, said: "f10"},
			{code: 0x0000007a, mods: Keys.MOD_CTRL, said: "ctrl+z"},
			{code: 0x40000052, mods: Keys.MOD_CTRL | Keys.MOD_SHIFT, said: "ctrl+shift+up"},
			{code: 0x0000000d, mods: Keys.MOD_ALT | Keys.MOD_GUI, said: "alt+gui+return"}
		];

		for (chord in chords) {
			same("naming " + chord.said, Keys.name(chord.code, chord.mods), chord.said);
			ok("reading back the key of " + chord.said, Keys.codeOf(chord.said) == chord.code,
				"got " + Keys.codeOf(chord.said) + ", wanted " + chord.code);
			ok("reading back the modifiers of " + chord.said, Keys.modsOf(chord.said) == chord.mods,
				"got " + Keys.modsOf(chord.said) + ", wanted " + chord.mods);
		}

		same("a key with no name", Keys.name(0x40000100, Keys.MOD_NONE), "");
		ok("an unnamed key binds to nothing", Keys.codeOf("") == Keys.UNBOUND, "it bound to something");
		ok("a modifier key is known for one", Keys.modifier(0x400000e1), "left shift was not one");
		ok("an ordinary key is not", !Keys.modifier(0x00000061), "the letter a was called one");
		same("plus is a key of its own", Keys.name("+".code, Keys.MOD_CTRL), "ctrl++");
		ok("and reads back", Keys.codeOf("ctrl++") == "+".code, "got " + Keys.codeOf("ctrl++"));
	}

	static function binding():Void {
		final table = new Shortcuts();

		same("every key starts where it was", table.chord("step a line") + " " + table.chord("pad A")
			+ " " + table.chord("preferences"), "f11 z f1");

		ok("a command is found by its key",
			table.commandFor(Keys.codeOf("f11"), Keys.MOD_NONE) == "step a line",
			"got " + table.commandFor(Keys.codeOf("f11"), Keys.MOD_NONE));
		ok("a pad button is found by its key",
			table.buttonMask(Keys.codeOf("z")) == Shortcuts.maskOf("pad A"),
			"got " + table.buttonMask(Keys.codeOf("z")));
		ok("a key nothing is bound to finds nothing",
			table.commandFor(Keys.codeOf("q"), Keys.MOD_NONE) == "", "it found something");

		same("binding a key already taken names the one that has it",
			table.clash("step a line", "f10"), "step an instruction");
		same("and a free key clashes with nothing", table.clash("step a line", "f7"), "");

		table.bind("step a line", "ctrl+shift+f7");
		same("a rebound key takes effect", table.chord("step a line"), "ctrl+shift+f7");
		ok("and answers to its chord",
			table.commandFor(Keys.codeOf("f7"), Keys.MOD_CTRL | Keys.MOD_SHIFT) == "step a line",
			"it did not");
		ok("but not to the key without its modifiers",
			table.commandFor(Keys.codeOf("f7"), Keys.MOD_NONE) == "", "it answered anyway");
		ok("and the key it used to have does nothing",
			table.commandFor(Keys.codeOf("f11"), Keys.MOD_NONE) == "", "f11 still steps a line");
		ok("a rebound key is no longer the standard one", !table.standard("step a line"),
			"it says it is standard");

		table.bind("pause", "p");
		table.bind("flat out", "ctrl+p");
		ok("the more specific chord wins where both could match",
			table.commandFor(Keys.codeOf("p"), Keys.MOD_CTRL) == "flat out",
			"got " + table.commandFor(Keys.codeOf("p"), Keys.MOD_CTRL));
		ok("and the plainer one still answers on its own",
			table.commandFor(Keys.codeOf("p"), Keys.MOD_NONE) == "pause",
			"got " + table.commandFor(Keys.codeOf("p"), Keys.MOD_NONE));

		ok("a pad key ignores whichever modifiers are down",
			table.buttonMask(Keys.codeOf("x")) == Shortcuts.maskOf("pad B"), "it did not");

		table.reset();
		same("putting them back restores every one", table.chord("step a line") + " "
			+ table.chord("pause") + " " + table.chord("flat out"), "f11 space tab");
		ok("and they are the standard ones again", table.standard("step a line"), "it says otherwise");

		ok("every action has a key", Shortcuts.actions().length == 16,
			Shortcuts.actions().length + " actions");
		for (action in Shortcuts.actions()) {
			ok("the key for " + action + " is one this build knows",
				Keys.codeOf(table.chord(action)) != Keys.UNBOUND, "it is " + table.chord(action));
		}
	}

	static function timeline():Void {
		final wide = 400.0;

		ok("a thumb narrower than the track needs a span to divide it",
			Timeline.thumbWidth(1, wide) == wide, "one position gave a narrower thumb");
		ok("ten positions share the track between them",
			Timeline.thumbWidth(10, wide) == wide / 10, "it was " + Timeline.thumbWidth(10, wide));
		ok("and a span too long to see keeps a thumb that can be grabbed",
			Timeline.thumbWidth(1000, wide) == Timeline.LEAST,
			"it was " + Timeline.thumbWidth(1000, wide));

		ok("the newest position puts the thumb at the left",
			Timeline.thumbAt(120, 0, wide) == 0, "it was " + Timeline.thumbAt(120, 0, wide));
		ok("and the oldest at the far end",
			Timeline.thumbAt(120, 119, wide) == wide - Timeline.LEAST,
			"it was " + Timeline.thumbAt(120, 119, wide));
		ok("a position past the end is held to it",
			Timeline.thumbAt(120, 400, wide) == Timeline.thumbAt(120, 119, wide),
			"it went further than the track");

		same("the left of the track picks the first position",
			Std.string(Timeline.pick(120, 0, wide)), "0");
		same("the right of it picks the last",
			Std.string(Timeline.pick(120, wide, wide)), "119");
		same("the middle picks the middle", Std.string(Timeline.pick(121, wide / 2, wide)), "60");
		same("and a pointer that has left the track is held to it",
			Std.string(Timeline.pick(120, -80, wide)), "0");

		var walked = 0;
		for (position in 0...120) {
			if (Timeline.pick(120, Timeline.thumbAt(120, position, wide)
				+ Timeline.LEAST * 0.5, wide) == position) walked++;
		}
		same("every position the thumb can sit at is the one picked back from it",
			walked + " of 120", "120 of 120");
	}

	static function main():Void {
		run();
	}

	public static function run():Void {
		Sys.println("");
		Sys.println("the focus stack, and what escape means at each level");
		escaping();
		padReach();

		Sys.println("the text field, driven by the same calls the window makes");
		editing();

		Sys.println("chords, named and read back the way the settings file writes them");
		naming();

		Sys.println("the binding table, and what answers to a key");
		binding();

		Sys.println("the timeline the rewind ring is scrubbed along");
		timeline();

		Sys.println("");
		Sys.println(checks + " checks, " + failures + " failures");
		if (failures > 0) Sys.exit(1);
	}
}

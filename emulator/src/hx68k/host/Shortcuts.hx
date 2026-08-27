package hx68k.host;

class Shortcuts {
	public static final COMMANDS:Array<String> = [
		"pause", "flat out", "step an instruction", "step a line",
		"keep a state", "restore a state", "back a frame", "preferences"
	];

	public static final BUTTONS:Array<String> = [
		"pad up", "pad down", "pad left", "pad right", "pad B", "pad C", "pad A", "pad start"
	];

	static final DEFAULTS:Map<String, String> = [
		"pause" => "space",
		"flat out" => "tab",
		"step an instruction" => "f10",
		"step a line" => "f11",
		"keep a state" => "f5",
		"restore a state" => "f9",
		"back a frame" => "backspace",
		"preferences" => "f1",
		"pad up" => "up",
		"pad down" => "down",
		"pad left" => "left",
		"pad right" => "right",
		"pad B" => "x",
		"pad C" => "c",
		"pad A" => "z",
		"pad start" => "return"
	];

	final chords:Map<String, String> = [];

	public function new() {
		reset();
	}

	public function reset():Void {
		chords.clear();
		for (action in DEFAULTS.keys()) chords.set(action, DEFAULTS.get(action));
	}

	public static function actions():Array<String> {
		return COMMANDS.concat(BUTTONS);
	}

	public static function isButton(action:String):Bool {
		return BUTTONS.indexOf(action) >= 0;
	}

	public static function maskOf(action:String):Int {
		final at = BUTTONS.indexOf(action);
		return at < 0 ? 0 : 1 << at;
	}

	public static function settingOf(action:String):String {
		return "bind." + StringTools.replace(action, " ", "-");
	}

	public function chord(action:String):String {
		final held = chords.get(action);
		return held == null ? "" : held;
	}

	public function standard(action:String):Bool {
		return chord(action) == fallback(action);
	}

	public static function fallback(action:String):String {
		final held = DEFAULTS.get(action);
		return held == null ? "" : held;
	}

	public function clash(action:String, wanted:String):String {
		if (wanted == "") return "";

		for (other in actions()) {
			if (other == action) continue;
			if (chord(other) == wanted) return other;
		}

		return "";
	}

	public function bind(action:String, wanted:String):Void {
		if (DEFAULTS.exists(action)) chords.set(action, wanted);
	}

	public function buttonMask(code:Int):Int {
		var mask = 0;

		for (action in BUTTONS) {
			final wanted = chord(action);
			if (wanted == "" || Keys.codeOf(wanted) != code) continue;
			mask |= maskOf(action);
		}

		return mask;
	}

	public function commandFor(code:Int, mods:Int):String {
		var found = "";
		var best = -1;

		for (action in COMMANDS) {
			final wanted = chord(action);
			if (wanted == "" || Keys.codeOf(wanted) != code) continue;

			final needed = Keys.modsOf(wanted);
			if (needed & mods != needed) continue;

			var count = 0;
			for (bit in 0...4) if (needed & (1 << bit) != 0) count++;

			if (count <= best) continue;
			best = count;
			found = action;
		}

		return found;
	}

	public function read(settings:SettingsFile):Void {
		for (action in actions()) {
			final key = settingOf(action);
			if (settings.has(key)) chords.set(action, settings.text(key, chord(action)));
		}
	}

	public function write(settings:SettingsFile):Void {
		for (action in actions()) settings.set(settingOf(action), chord(action));
	}
}

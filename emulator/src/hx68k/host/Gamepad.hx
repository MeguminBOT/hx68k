package hx68k.host;

class Gamepad {
	public static inline final UNBOUND = -1;

	public static final NAMES:Array<String> = [
		"south", "east", "west", "north", "back", "guide", "start",
		"left stick", "right stick", "left shoulder", "right shoulder",
		"dpad up", "dpad down", "dpad left", "dpad right"
	];

	static final DEFAULTS:Map<String, String> = [
		"pad up" => "dpad up",
		"pad down" => "dpad down",
		"pad left" => "dpad left",
		"pad right" => "dpad right",
		"pad B" => "south",
		"pad C" => "east",
		"pad A" => "west",
		"pad start" => "start"
	];

	final held:Map<String, String> = [];

	public function new() {
		reset();
	}

	public function reset():Void {
		held.clear();
		for (action in Shortcuts.BUTTONS) held.set(action, fallback(action));
	}

	public static function fallback(action:String):String {
		final known = DEFAULTS.get(action);
		return known == null ? "" : known;
	}

	public static function indexOf(name:String):Int {
		final at = NAMES.indexOf(name);
		return at < 0 ? UNBOUND : at;
	}

	public static function settingOf(action:String):String {
		return "gamepad." + StringTools.replace(action, " ", "-");
	}

	public function button(action:String):String {
		final known = held.get(action);
		return known == null ? "" : known;
	}

	public function standard(action:String):Bool {
		return button(action) == fallback(action);
	}

	public function clash(action:String, wanted:String):String {
		if (wanted == "") return "";

		for (other in Shortcuts.BUTTONS) {
			if (other == action) continue;
			if (button(other) == wanted) return other;
		}

		return "";
	}

	public function bind(action:String, wanted:String):Void {
		if (DEFAULTS.exists(action)) held.set(action, wanted);
	}

	public function maskOf(raw:Int):Int {
		var mask = 0;

		for (action in Shortcuts.BUTTONS) {
			final at = indexOf(button(action));
			if (at == UNBOUND) continue;
			if (raw & (1 << at) != 0) mask |= Shortcuts.maskOf(action);
		}

		return mask;
	}

	public static function pressedIn(raw:Int, was:Int):String {
		final fresh = raw & ~was;
		if (fresh == 0) return "";

		for (at in 0...NAMES.length) if (fresh & (1 << at) != 0) return NAMES[at];
		return "";
	}

	public function read(settings:SettingsFile):Void {
		for (action in Shortcuts.BUTTONS) {
			final key = settingOf(action);
			if (settings.has(key)) held.set(action, settings.text(key, button(action)));
		}
	}

	public function write(settings:SettingsFile):Void {
		for (action in Shortcuts.BUTTONS) settings.set(settingOf(action), button(action));
	}
}

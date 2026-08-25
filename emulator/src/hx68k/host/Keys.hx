package hx68k.host;

class Keys {
	public static inline final UNBOUND = 0;

	public static inline final MOD_NONE = 0;
	public static inline final MOD_SHIFT = 1;
	public static inline final MOD_CTRL = 2;
	public static inline final MOD_ALT = 4;
	public static inline final MOD_GUI = 8;

	static final NAMED:Map<Int, String> = [
		0x00000008 => "backspace",
		0x00000009 => "tab",
		0x0000000d => "return",
		0x0000001b => "escape",
		0x00000020 => "space",
		0x0000007f => "delete",
		0x40000039 => "capslock",
		0x4000003a => "f1",
		0x4000003b => "f2",
		0x4000003c => "f3",
		0x4000003d => "f4",
		0x4000003e => "f5",
		0x4000003f => "f6",
		0x40000040 => "f7",
		0x40000041 => "f8",
		0x40000042 => "f9",
		0x40000043 => "f10",
		0x40000044 => "f11",
		0x40000045 => "f12",
		0x40000049 => "insert",
		0x4000004a => "home",
		0x4000004b => "pageup",
		0x4000004d => "end",
		0x4000004e => "pagedown",
		0x4000004f => "right",
		0x40000050 => "left",
		0x40000051 => "down",
		0x40000052 => "up"
	];

	static final CODED:Map<String, Int> = reversed();

	static final MODIFIERS:Array<{name:String, bit:Int}> = [
		{name: "ctrl", bit: MOD_CTRL},
		{name: "shift", bit: MOD_SHIFT},
		{name: "alt", bit: MOD_ALT},
		{name: "gui", bit: MOD_GUI}
	];

	static function reversed():Map<String, Int> {
		final out = new Map<String, Int>();
		for (code in NAMED.keys()) out.set(NAMED.get(code), code);
		return out;
	}

	public static function name(code:Int, mods:Int):String {
		final key = keyName(code);
		if (key == "") return "";

		var out = "";
		for (modifier in MODIFIERS) if (mods & modifier.bit != 0) out += modifier.name + "+";
		return out + key;
	}

	public static function keyName(code:Int):String {
		final known = NAMED.get(code);
		if (known != null) return known;
		if (code > 0x20 && code < 0x7f) return String.fromCharCode(code);
		return "";
	}

	public static function modifier(code:Int):Bool {
		return code >= 0x400000e0 && code <= 0x400000e7;
	}

	public static function codeOf(chord:String):Int {
		final key = keyOf(chord);
		if (key == "") return UNBOUND;

		final known = CODED.get(key);
		if (known != null) return known;
		return key.length == 1 ? key.charCodeAt(0) : UNBOUND;
	}

	public static function modsOf(chord:String):Int {
		final parts = chord.split("+");
		var mods = 0;

		for (index in 0...parts.length - 1) {
			if (parts[index] == "") continue;
			for (modifier in MODIFIERS) if (parts[index] == modifier.name) mods |= modifier.bit;
		}

		return mods;
	}

	static function keyOf(chord:String):String {
		if (chord == "") return "";

		final parts = chord.split("+");
		final last = parts[parts.length - 1];
		return last == "" && parts.length > 1 ? "+" : last;
	}
}

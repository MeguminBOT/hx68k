package hx68k.debug;

class Schedule {
	public static inline final HELD_FRAMES = 6;

	public static function of(text:String):Map<Int, Int> {
		final at:Map<Int, Int> = [];

		for (entry in text.split(",")) {
			final split = entry.indexOf("@");
			if (split <= 0) continue;

			final button = bit(entry.substr(0, split));
			final tail = entry.substr(split + 1);
			final colon = tail.indexOf(":");
			final when = Std.parseInt(colon > 0 ? tail.substr(0, colon) : tail);
			final held = colon > 0 ? Std.parseInt(tail.substr(colon + 1)) : HELD_FRAMES;
			if (button == 0 || when == null || held == null) continue;

			for (frame in when...when + held)
				at.set(frame, (at.exists(frame) ? at.get(frame) : 0) | button);
		}

		return at;
	}

	public static function bit(name:String):Int {
		return switch (StringTools.trim(name).toLowerCase()) {
			case "up": 0x01;
			case "down": 0x02;
			case "left": 0x04;
			case "right": 0x08;
			case "b": 0x10;
			case "c": 0x20;
			case "a": 0x40;
			case "start": 0x80;
			case _: 0;
		}
	}
}

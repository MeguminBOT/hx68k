package hx68k.host;

class Settings {
	public static inline final FILE = "hx68k.cfg";

	public var problem(default, null):String = "";

	final values:Map<String, String> = [];
	final order:Array<String> = [];

	public function new() {}

	public static function directory():String {
		final home = Sys.getEnv("HOME");

		switch (Sys.systemName()) {
			case "Windows":
				final roaming = Sys.getEnv("APPDATA");
				if (roaming != null && roaming != "") return slashed(roaming) + "/hx68k";

			case "Mac":
				if (home != null && home != "") {
					return slashed(home) + "/Library/Application Support/hx68k";
				}

			case _:
				final configured = Sys.getEnv("XDG_CONFIG_HOME");
				if (configured != null && configured != "") return slashed(configured) + "/hx68k";
				if (home != null && home != "") return slashed(home) + "/.config/hx68k";
		}

		return ".hx68k";
	}

	public static function path():String {
		return directory() + "/" + FILE;
	}

	static function slashed(where:String):String {
		return StringTools.replace(where, "\\", "/");
	}

	public function read(from:String):Bool {
		problem = "";
		values.clear();
		while (order.length > 0) order.pop();

		if (!sys.FileSystem.exists(from)) return false;

		var content:String;
		try {
			content = sys.io.File.getContent(from);
		} catch (e:haxe.Exception) {
			problem = "the settings could not be read, so these are the defaults: " + e.message;
			return false;
		}

		if (content.indexOf(String.fromCharCode(0)) >= 0) {
			problem = "the settings file is not text, so these are the defaults";
			return false;
		}

		var malformed = 0;
		var first = 0;
		var line = 0;

		for (raw in StringTools.replace(content, "\r", "").split("\n")) {
			line++;

			final trimmed = StringTools.trim(raw);
			if (trimmed == "" || trimmed.charAt(0) == "#") continue;

			final split = trimmed.indexOf(" ");
			if (split <= 0) {
				malformed++;
				if (first == 0) first = line;
				continue;
			}

			set(trimmed.substr(0, split), StringTools.ltrim(trimmed.substr(split + 1)));
		}

		if (malformed > 0) {
			problem = malformed + (malformed == 1 ? " line" : " lines") + " of the settings say"
				+ " nothing this understands, the first at line " + first + ", and were left out";
		}

		return true;
	}

	public function write(to:String):Bool {
		final out = new StringBuf();
		for (key in order) {
			out.add(key);
			out.add(" ");
			out.add(values.get(key));
			out.add("\n");
		}

		try {
			final into = haxe.io.Path.directory(to);
			if (into != "" && !sys.FileSystem.exists(into)) sys.FileSystem.createDirectory(into);
			sys.io.File.saveContent(to, out.toString());
		} catch (e:haxe.Exception) {
			problem = "the settings could not be written: " + e.message;
			return false;
		}

		return true;
	}

	public function has(key:String):Bool {
		return values.exists(key);
	}

	public function keys():Array<String> {
		return order.copy();
	}

	public function set(key:String, value:String):Bool {
		if (!storable(key)) return false;

		if (!values.exists(key)) order.push(key);
		values.set(key, oneLine(value));
		return true;
	}

	static function oneLine(value:String):String {
		final out = new StringBuf();
		for (index in 0...value.length) {
			final code = value.charCodeAt(index);
			out.addChar(code < 0x20 ? 0x20 : code);
		}
		return out.toString();
	}

	public static function storable(key:String):Bool {
		if (key == "" || key.charAt(0) == "#") return false;

		for (index in 0...key.length) {
			final code = key.charCodeAt(index);
			if (code <= 0x20 || code == 0x7f) return false;
		}

		return true;
	}

	public function text(key:String, fallback:String):String {
		final held = values.get(key);
		return held == null ? fallback : held;
	}

	public function whole(key:String, fallback:Int):Int {
		final held = values.get(key);
		if (held == null) return fallback;

		final parsed = Std.parseInt(held);
		return parsed == null ? fallback : parsed;
	}

	public function setWhole(key:String, value:Int):Void {
		set(key, Std.string(value));
	}

	public function flag(key:String, fallback:Bool):Bool {
		final held = values.get(key);
		if (held == null) return fallback;
		return held == "on" || held == "true" || held == "yes" || held == "1";
	}

	public function setFlag(key:String, value:Bool):Void {
		set(key, value ? "on" : "off");
	}
}

package hx68k.debug;

class Packet {
	public var acknowledging:Bool = true;
	public var interrupted:Bool = false;
	public var damaged(default, null):Int = 0;

	var buffer:String = "";

	public function new() {}

	public function feed(text:String):Void {
		buffer += text;
	}

	public function next():Null<String> {
		while (buffer.length > 0) {
			final lead = buffer.charCodeAt(0);

			if (lead == 3) {
				interrupted = true;
				buffer = buffer.substr(1);
				continue;
			}

			if (lead != "$".code) {
				buffer = buffer.substr(1);
				continue;
			}

			final end = buffer.indexOf("#");
			if (end < 0 || buffer.length < end + 3) return null;

			final body = buffer.substr(1, end - 1);
			final said = Std.parseInt("0x" + buffer.substr(end + 1, 2));
			buffer = buffer.substr(end + 3);

			if (said != checksum(body)) {
				damaged++;
				return null;
			}

			return expand(body);
		}

		return null;
	}

	public static function checksum(body:String):Int {
		var sum = 0;
		for (i in 0...body.length) sum += body.charCodeAt(i);
		return sum & 0xFF;
	}

	public static function frame(body:String):String {
		return "$" + body + "#" + StringTools.hex(checksum(body), 2).toLowerCase();
	}

	public static function expand(body:String):String {
		if (body.indexOf("*") < 0) return body;

		final out = new StringBuf();
		var i = 0;

		while (i < body.length) {
			final char = body.charAt(i);

			if (char != "*" || i == 0 || i + 1 >= body.length) {
				out.add(char);
				i++;
				continue;
			}

			final again = body.charCodeAt(i + 1) - 29;
			for (_ in 0...again) out.add(body.charAt(i - 1));
			i += 2;
		}

		return out.toString();
	}

	public static function escape(text:String):String {
		var needed = false;
		for (i in 0...text.length) {
			final code = text.charCodeAt(i);
			if (code == "#".code || code == "$".code || code == "}".code || code == "*".code) needed = true;
		}
		if (!needed) return text;

		final out = new StringBuf();
		for (i in 0...text.length) {
			final code = text.charCodeAt(i);
			if (code == "#".code || code == "$".code || code == "}".code || code == "*".code) {
				out.addChar("}".code);
				out.addChar(code ^ 0x20);
			} else {
				out.addChar(code);
			}
		}

		return out.toString();
	}

	public static function encode(text:String):String {
		final out = new StringBuf();
		for (i in 0...text.length) out.add(StringTools.hex(text.charCodeAt(i) & 0xFF, 2).toLowerCase());
		return out.toString();
	}

	public static function decode(text:String):String {
		final out = new StringBuf();
		var i = 0;
		while (i + 1 < text.length) {
			final byte = Std.parseInt("0x" + text.substr(i, 2));
			if (byte == null) break;
			out.addChar(byte);
			i += 2;
		}
		return out.toString();
	}
}

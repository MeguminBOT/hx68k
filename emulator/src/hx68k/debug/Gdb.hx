package hx68k.debug;

import haxe.io.Bytes;
import haxe.io.Error;
import hx68k.md.Machine;
import sys.net.Host;
import sys.net.Socket;

class Gdb {
	public static inline final TRAP = 5;
	public static inline final INTERRUPT = 2;

	public static inline final REGISTERS = 18;

	public var port(default, null):Int;
	public var attached(default, null):Bool = false;
	public var halted(default, null):Bool = true;
	public var ending(default, null):Bool = false;
	public var sessions(default, null):Int = 0;

	final debugger:Debugger;
	final machine:Machine;
	final code:Code;
	final packets:Packet = new Packet();
	final breakpoints:Array<Int> = [];
	final watchAt:Array<Int> = [];
	final watchWidth:Array<Int> = [];
	final watchWas:Array<Int> = [];
	final description:String = shape();

	final listener:Socket;
	var client:Null<Socket> = null;
	var stepping:Bool = false;

	public function new(debugger:Debugger, wanted:Int) {
		this.debugger = debugger;
		this.machine = debugger.machine;
		this.code = new MachineCode(debugger.machine);

		listener = new Socket();
		listener.bind(new Host("127.0.0.1"), wanted);
		listener.listen(1);
		port = wanted;
	}

	public function close():Void {
		drop();
		try listener.close() catch (e:Dynamic) {}
	}

	public function attend(wait:Float):Void {
		if (client == null) {
			if (Socket.select([listener], [], [], wait).read.length == 0) return;
			client = listener.accept();
			client.setFastSend(true);
			attached = true;
			halted = true;
			stepping = false;
			packets.acknowledging = true;
			sessions++;
			return;
		}

		if (Socket.select([client], [], [], halted ? wait : 0).read.length == 0) return;

		final text = receive();
		if (text == null) {
			drop();
			return;
		}

		packets.feed(text);
		answer();
	}

	public function advance(instructions:Int):Void {
		if (client == null || halted) return;

		var n = 0;
		while (n < instructions) {
			machine.step();
			n++;

			if (stepping) {
				report(TRAP, "");
				return;
			}

			if (breakpoints.length > 0) {
				final at = debugger.at();
				for (planted in breakpoints) {
					if (planted != at) continue;
					report(TRAP, "swbreak:;");
					return;
				}
			}

			if (watchAt.length > 0) {
				final hit = moved();
				if (hit >= 0) {
					report(TRAP, "watch:" + StringTools.hex(watchAt[hit], 6).toLowerCase() + ";");
					return;
				}
			}
		}
	}

	public function untilFrame():Void {
		final target = machine.vdp.frame + 1;
		while (!halted && machine.vdp.frame != target) advance(2000);
	}

	function drop():Void {
		if (client == null) return;
		try client.close() catch (e:Dynamic) {}
		client = null;
		attached = false;
		halted = true;
		stepping = false;
	}

	function receive():Null<String> {
		final buffer = Bytes.alloc(4096);
		var got = 0;

		try {
			got = client.input.readBytes(buffer, 0, buffer.length);
		} catch (e:haxe.io.Eof) {
			return null;
		} catch (e:Error) {
			return e == Error.Blocked ? "" : null;
		} catch (e:Dynamic) {
			return null;
		}

		if (got <= 0) return null;

		final out = new StringBuf();
		for (i in 0...got) out.addChar(buffer.get(i));
		return out.toString();
	}

	function answer():Void {
		if (packets.interrupted) {
			packets.interrupted = false;
			if (!halted) report(INTERRUPT, "");
		}

		while (true) {
			final before = packets.damaged;
			final body = packets.next();

			if (packets.damaged > before) {
				raw("-");
				continue;
			}

			if (body == null) return;
			if (packets.acknowledging) raw("+");
			handle(body);
		}
	}

	function raw(text:String):Void {
		if (client == null) return;

		final bytes = Bytes.alloc(text.length);
		for (i in 0...text.length) bytes.set(i, text.charCodeAt(i) & 0xFF);

		try {
			client.output.writeBytes(bytes, 0, bytes.length);
			client.output.flush();
		} catch (e:Dynamic) {
			drop();
		}
	}

	function reply(body:String):Void {
		raw(Packet.frame(body));
	}

	function report(signal:Int, extra:String):Void {
		halted = true;
		stepping = false;
		reply(stop(signal, extra));
	}

	function stop(signal:Int, extra:String):String {
		return "T" + StringTools.hex(signal, 2).toLowerCase() + extra + "thread:1;";
	}

	function handle(body:String):Void {
		if (body == "") {
			reply("");
			return;
		}

		switch (body.charAt(0)) {
			case "?": reply(stop(TRAP, ""));
			case "g": reply(all());
			case "G": reply(load(body.substr(1)));
			case "p": reply(one(body.substr(1)));
			case "P": reply(poke(body.substr(1)));
			case "m": reply(look(body.substr(1)));
			case "M": reply(store(body.substr(1)));
			case "c": resume(false);
			case "s": resume(true);
			case "k": ending = true; drop();
			case "D": reply("OK"); drop();
			case "H": reply("OK");
			case "q": reply(asked(body));
			case "Q": settle(body);
			case "v": verbose(body);
			case "Z": reply(plant(body, true));
			case "z": reply(plant(body, false));
			case _: reply("");
		}
	}

	function resume(step:Bool):Void {
		stepping = step;
		halted = false;
		remember();
	}

	function settle(body:String):Void {
		if (body != "QStartNoAckMode") {
			reply("");
			return;
		}

		reply("OK");
		packets.acknowledging = false;
	}

	function verbose(body:String):Void {
		if (body == "vCont?") {
			reply("vCont;c;C;s;S");
			return;
		}

		if (StringTools.startsWith(body, "vCont;")) {
			final action = body.charAt(6);
			if (action == "s" || action == "S") resume(true);
			else if (action == "c" || action == "C") resume(false);
			else reply("");
			return;
		}

		if (StringTools.startsWith(body, "vKill")) {
			ending = true;
			reply("OK");
			drop();
			return;
		}

		reply("");
	}

	function asked(body:String):String {
		if (StringTools.startsWith(body, "qSupported"))
			return "PacketSize=1000;qXfer:features:read+;swbreak+;hwbreak+;QStartNoAckMode+";
		if (StringTools.startsWith(body, "qXfer:features:read:target.xml:")) return part(body);
		if (StringTools.startsWith(body, "qAttached")) return "1";
		if (StringTools.startsWith(body, "qRcmd,")) return monitor(Packet.decode(body.substr(6)));
		if (body == "qC") return "QC1";
		if (body == "qfThreadInfo") return "m1";
		if (body == "qsThreadInfo") return "l";
		if (StringTools.startsWith(body, "qSymbol")) return "OK";
		return "";
	}

	function part(body:String):String {
		final range = body.substr("qXfer:features:read:target.xml:".length).split(",");
		if (range.length != 2) return "E01";

		final from = word(range[0]);
		final length = word(range[1]);
		if (from == null || length == null) return "E01";
		if (from >= description.length) return "l";

		final chunk = description.substr(from, length);
		return (from + chunk.length < description.length ? "m" : "l") + Packet.escape(chunk);
	}

	function monitor(command:String):String {
		final words = StringTools.trim(command).split(" ");

		switch (words[0]) {
			case "reset":
				machine.reset();
				return say("the machine is reset");
			case "frame":
				machine.runFrame();
				return say("frame " + machine.vdp.frame + ", line " + machine.vdp.line);
			case "where":
				final place = debugger.site();
				return say(place == null
					? "no Haxe behind $" + StringTools.hex(debugger.at(), 6)
					: place.file + ":" + place.line);
			case _:
				return say("reset, frame and where are what this answers to");
		}
	}

	function say(text:String):String {
		raw(Packet.frame("O" + Packet.encode(text + "\n")));
		return "OK";
	}

	function all():String {
		final out = new StringBuf();
		for (i in 0...REGISTERS) out.add(long(value(i)));
		return out.toString();
	}

	function load(text:String):String {
		if (text.length < REGISTERS * 8) return "E01";
		for (i in 0...REGISTERS) put(i, word(text.substr(i * 8, 8)));
		return "OK";
	}

	function one(text:String):String {
		final number = word(text);
		if (number == null || number < 0 || number >= REGISTERS) return "E01";
		return long(value(number));
	}

	function poke(text:String):String {
		final parts = text.split("=");
		if (parts.length != 2) return "E01";

		final number = word(parts[0]);
		final wanted = word(parts[1]);
		if (number == null || wanted == null || number < 0 || number >= REGISTERS) return "E01";

		put(number, wanted);
		return "OK";
	}

	function value(number:Int):Int {
		if (number < 8) return machine.cpu.d[number];
		if (number < 16) return machine.cpu.a[number - 8];
		return number == 16 ? machine.cpu.getSr() : debugger.at();
	}

	function put(number:Int, wanted:Int):Void {
		if (number < 8) machine.cpu.d[number] = wanted;
		else if (number < 16) machine.cpu.a[number - 8] = wanted;
		else if (number == 16) machine.cpu.setSr(wanted & 0xFFFF);
		else machine.cpu.jump(wanted & 0xFFFFFF);
	}

	function look(text:String):String {
		final parts = text.split(",");
		if (parts.length != 2) return "E01";

		final at = word(parts[0]);
		final length = word(parts[1]);
		if (at == null || length == null) return "E01";
		if (length == 0) return "";
		if (!mapped(at) || !mapped(at + length - 1)) return "E01";

		final out = new StringBuf();
		for (i in 0...length) out.add(StringTools.hex(peek(at + i), 2).toLowerCase());
		return out.toString();
	}

	function store(text:String):String {
		final colon = text.indexOf(":");
		if (colon < 0) return "E01";

		final parts = text.substr(0, colon).split(",");
		if (parts.length != 2) return "E01";

		final at = word(parts[0]);
		final length = word(parts[1]);
		if (at == null || length == null) return "E01";
		if (length == 0) return "OK";
		if (!writable(at) || !writable(at + length - 1)) return "E01";

		final data = text.substr(colon + 1);
		if (data.length < length * 2) return "E01";

		for (i in 0...length) {
			final byte = word(data.substr(i * 2, 2));
			if (byte == null) return "E01";
			machine.writeByte(at + i, byte);
		}

		return "OK";
	}

	function plant(body:String, on:Bool):String {
		final parts = body.substr(1).split(",");
		if (parts.length < 3) return "E01";

		final kind = Std.parseInt(parts[0]);
		final at = word(parts[1]);
		final width = word(parts[2]);
		if (kind == null || at == null || width == null) return "E01";

		if (kind == 0 || kind == 1) {
			final held = breakpoints.indexOf(at & 0xFFFFFF);
			if (on && held < 0) breakpoints.push(at & 0xFFFFFF);
			if (!on && held >= 0) breakpoints.splice(held, 1);
			return "OK";
		}

		if (kind != 2) return "";

		final held = watchAt.indexOf(at & 0xFFFFFF);
		if (on && held < 0) {
			watchAt.push(at & 0xFFFFFF);
			watchWidth.push(width < 1 ? 1 : width);
			watchWas.push(0);
		}
		if (!on && held >= 0) {
			watchAt.splice(held, 1);
			watchWidth.splice(held, 1);
			watchWas.splice(held, 1);
		}

		remember();
		return "OK";
	}

	function remember():Void {
		for (i in 0...watchAt.length) watchWas[i] = held(i);
	}

	function moved():Int {
		for (i in 0...watchAt.length) {
			final now = held(i);
			if (now == watchWas[i]) continue;
			watchWas[i] = now;
			return i;
		}
		return -1;
	}

	function held(index:Int):Int {
		var out = 0;
		for (i in 0...watchWidth[index]) out = (out << 8) | peek(watchAt[index] + i);
		return out;
	}

	function peek(address:Int):Int {
		final at = address & 0xFFFFFF;
		final word = code.word(at & 0xFFFFFE);
		return (at & 1) == 0 ? (word >> 8) & 0xFF : word & 0xFF;
	}

	function mapped(address:Int):Bool {
		final at = address & 0xFFFFFF;
		return at < machine.rom.length || at >= 0xE00000;
	}

	function writable(address:Int):Bool {
		return (address & 0xFFFFFF) >= 0xE00000;
	}

	static function word(text:String):Null<Int> {
		if (text.length == 0 || text.length > 8) return null;

		var out = 0;

		for (i in 0...text.length) {
			final code = text.charCodeAt(i);
			var digit = -1;
			if (code >= "0".code && code <= "9".code) digit = code - "0".code;
			if (code >= "a".code && code <= "f".code) digit = code - "a".code + 10;
			if (code >= "A".code && code <= "F".code) digit = code - "A".code + 10;
			if (digit < 0) return null;
			out = (out << 4) | digit;
		}

		return out;
	}

	static function long(v:Int):String {
		return StringTools.hex(v, 8).toLowerCase();
	}

	static function shape():String {
		final out = new StringBuf();
		out.add("<?xml version=\"1.0\"?><!DOCTYPE target SYSTEM \"gdb-target.dtd\">");
		out.add("<target version=\"1.0\"><architecture>m68k</architecture>");
		out.add("<feature name=\"org.gnu.gdb.m68k.core\">");
		for (i in 0...8) out.add("<reg name=\"d" + i + "\" bitsize=\"32\" type=\"int32\"/>");
		for (i in 0...6) out.add("<reg name=\"a" + i + "\" bitsize=\"32\" type=\"data_ptr\"/>");
		out.add("<reg name=\"fp\" bitsize=\"32\" type=\"data_ptr\"/>");
		out.add("<reg name=\"sp\" bitsize=\"32\" type=\"data_ptr\"/>");
		out.add("<reg name=\"ps\" bitsize=\"32\" type=\"int32\"/>");
		out.add("<reg name=\"pc\" bitsize=\"32\" type=\"code_ptr\"/>");
		out.add("</feature></target>");
		return out.toString();
	}
}

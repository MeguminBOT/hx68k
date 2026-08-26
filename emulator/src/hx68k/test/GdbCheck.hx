package hx68k.test;

import haxe.io.Bytes;
import hx68k.debug.Debugger;
import hx68k.debug.Gdb;
import hx68k.debug.Packet;
import hx68k.md.Machine;
import sys.net.Host;
import sys.net.Socket;

class GdbCheck {
	static inline final CODE = 0xFF0800;

	static inline final TARGET = 0xFF1000;

	static inline final PLANTED = "4e714e7133fc123400ff100060fe";

	static var failures:Int = 0;
	static var checks:Int = 0;

	static var output:StringBuf = new StringBuf();

	static function ok(what:String, held:Bool, saying:String):Void {
		checks++;
		if (held) return;
		failures++;
		Sys.println("  FAIL " + what + ": " + saying);
	}

	static function same(what:String, got:String, wanted:String):Void {
		ok(what, got == wanted, "wanted " + wanted + ", got " + got);
	}

	static function framing():Void {
		same("the checksum of a body is its bytes added up",
			StringTools.hex(Packet.checksum("OK"), 2).toLowerCase(), "9a");
		same("a framed packet carries it", Packet.frame("OK"), "$OK#9a");
		same("a run of the same character expands", Packet.expand("0* "), "0000");
		same("a body with no run is left alone", Packet.expand("1234"), "1234");
		same("the four reserved characters are escaped", Packet.escape("a#b"), "a}" + String.fromCharCode(3) + "b");
		same("and nothing else is", Packet.escape("plain"), "plain");
		same("text goes out as hex", Packet.encode("hi"), "6869");
		same("and comes back", Packet.decode("6869"), "hi");
	}

	static function stream():Void {
		final packets = new Packet();

		packets.feed("+$g#67");
		same("an acknowledgement before a packet is skipped", packets.next(), "g");
		ok("and nothing follows it", packets.next() == null, "another packet came out");

		packets.feed("$mff0");
		ok("half a packet is not a packet", packets.next() == null, "half a packet came out");
		packets.feed("800,4#61");
		same("and the other half completes it", packets.next(), "mff0800,4");

		packets.feed(String.fromCharCode(3));
		ok("an interrupt byte is not a packet", packets.next() == null, "it came out as one");
		ok("and it is reported", packets.interrupted, "the interrupt was not seen");

		final before = packets.damaged;
		packets.feed("$g#00");
		ok("a body its checksum does not match is refused", packets.next() == null, "it came out anyway");
		ok("and counted", packets.damaged == before + 1, "the count did not move");
	}

	static function port():Int {
		var wanted = 27760;

		while (wanted < 27800) {
			try {
				final trial = new Socket();
				trial.bind(new Host("127.0.0.1"), wanted);
				trial.close();
				return wanted;
			} catch (e:Dynamic) {
				wanted++;
			}
		}

		return 0;
	}

	static function session():Void {
		final where = port();
		if (where == 0) {
			ok("a port to listen on", false, "every port from 27760 to 27799 was taken");
			return;
		}

		final machine = new Machine();
		machine.vdp.rendering = false;
		final debugger = new Debugger(machine, null);
		final gdb = new Gdb(debugger, where);

		final client = new Socket();
		client.connect(new Host("127.0.0.1"), where);
		client.setFastSend(true);

		final answers = new Packet();
		gdb.attend(0.5);
		ok("a client is accepted", gdb.attached, "nothing connected");

		handshake(gdb, client, answers);
		memory(gdb, client, answers, debugger);
		running(gdb, client, answers, debugger);

		talk(gdb, client, answers, "D");
		gdb.attend(0.05);
		ok("a detach lets go of the client", !gdb.attached, "the client is still held");

		try client.close() catch (e:Dynamic) {}
		gdb.close();
	}

	static function handshake(gdb:Gdb, client:Socket, answers:Packet):Void {
		final supported = talk(gdb, client, answers, "qSupported:multiprocess+;swbreak+");
		ok("the stub offers a target description", supported.indexOf("qXfer:features:read+") >= 0,
			"qSupported said " + supported);
		ok("and software breakpoints", supported.indexOf("swbreak+") >= 0, "qSupported said " + supported);

		final description = fetch(gdb, client, answers);
		ok("the description is xml", StringTools.startsWith(description, "<?xml"),
			"it starts " + description.substr(0, 20));
		same("naming the m68000 core", count(description, "<reg ") + " registers", "18 registers");
		ok("with the program counter last",
			description.indexOf("name=\"pc\"") > description.indexOf("name=\"ps\""),
			"ps and pc are the wrong way round");

		same("a stop reason is asked for before anything runs",
			talk(gdb, client, answers, "?"), "T05thread:1;");
		same("one thread answers", talk(gdb, client, answers, "qC"), "QC1");
		same("and it is the only one", talk(gdb, client, answers, "qfThreadInfo"), "m1");
		same("the target was attached to, not started", talk(gdb, client, answers, "qAttached"), "1");
		same("continuing and stepping are both offered",
			talk(gdb, client, answers, "vCont?"), "vCont;c;C;s;S");
		same("a packet nothing here knows is answered empty",
			talk(gdb, client, answers, "qNonsense"), "");
	}

	static function memory(gdb:Gdb, client:Socket, answers:Packet, debugger:Debugger):Void {
		same("a write into work ram is taken",
			talk(gdb, client, answers, "M" + StringTools.hex(CODE, 6).toLowerCase() + ",e:" + PLANTED), "OK");
		same("and reads back byte for byte",
			talk(gdb, client, answers, "m" + StringTools.hex(CODE, 6).toLowerCase() + ",e"), PLANTED);
		same("a read of nothing is nothing",
			talk(gdb, client, answers, "m" + StringTools.hex(CODE, 6).toLowerCase() + ",0"), "");
		same("a read of what no memory answers is refused",
			talk(gdb, client, answers, "mc00004,2"), "E01");
		same("and so is a write into the cartridge",
			talk(gdb, client, answers, "M000100,2:1234"), "E01");

		same("the program counter is written through its own register",
			talk(gdb, client, answers, "P11=00ff0800"), "OK");
		same("and read back", talk(gdb, client, answers, "p11"), "00ff0800");
		ok("which is where the machine now stands", debugger.at() == CODE,
			"the machine is at $" + StringTools.hex(debugger.at(), 6));

		same("a data register is written", talk(gdb, client, answers, "P0=deadbeef"), "OK");
		same("and read back", talk(gdb, client, answers, "p0"), "deadbeef");

		final registers = talk(gdb, client, answers, "g");
		same("all eighteen come out at once", registers.length + " digits", "144 digits");
		same("with the first data register among them", registers.substr(0, 8), "deadbeef");
		same("and the program counter last", registers.substr(17 * 8, 8), "00ff0800");

		same("a register nothing declares is refused", talk(gdb, client, answers, "p20"), "E01");
	}

	static function running(gdb:Gdb, client:Socket, answers:Packet, debugger:Debugger):Void {
		same("a step runs one instruction", talk(gdb, client, answers, "s"), "T05thread:1;");
		ok("and stops on the next", debugger.at() == CODE + 2,
			"the machine is at $" + StringTools.hex(debugger.at(), 6));

		same("the program counter goes back", talk(gdb, client, answers, "P11=00ff0800"), "OK");
		same("a breakpoint is planted",
			talk(gdb, client, answers, "Z0," + StringTools.hex(CODE + 2, 6).toLowerCase() + ",2"), "OK");
		same("and continuing runs into it",
			talk(gdb, client, answers, "c"), "T05swbreak:;thread:1;");
		ok("exactly where it was put", debugger.at() == CODE + 2,
			"the machine is at $" + StringTools.hex(debugger.at(), 6));
		same("taking it out again is taken",
			talk(gdb, client, answers, "z0," + StringTools.hex(CODE + 2, 6).toLowerCase() + ",2"), "OK");

		same("a read watchpoint is not offered",
			talk(gdb, client, answers, "Z3," + StringTools.hex(TARGET, 6).toLowerCase() + ",2"), "");
		same("a write watchpoint is",
			talk(gdb, client, answers, "Z2," + StringTools.hex(TARGET, 6).toLowerCase() + ",2"), "OK");
		same("and the instruction that writes there stops the machine",
			talk(gdb, client, answers, "c"), "T05watch:ff1000;thread:1;");
		same("with the value the instruction wrote",
			talk(gdb, client, answers, "m" + StringTools.hex(TARGET, 6).toLowerCase() + ",2"), "1234");
		ok("after the instruction, not before it", debugger.at() == CODE + 12,
			"the machine is at $" + StringTools.hex(debugger.at(), 6));
		same("and it can be taken out",
			talk(gdb, client, answers, "z2," + StringTools.hex(TARGET, 6).toLowerCase() + ",2"), "OK");

		output = new StringBuf();
		same("a monitor command answers", talk(gdb, client, answers, "qRcmd," + Packet.encode("where")), "OK");
		ok("saying there is no Haxe behind an address in ram",
			output.toString().indexOf("no Haxe behind $FF080C") >= 0,
			"it said " + StringTools.trim(output.toString()));

		same("acknowledgements can be turned off", talk(gdb, client, answers, "QStartNoAckMode"), "OK");
	}

	static function fetch(gdb:Gdb, client:Socket, answers:Packet):String {
		final out = new StringBuf();
		var from = 0;

		while (from < 8192) {
			final chunk = talk(gdb, client, answers, "qXfer:features:read:target.xml:"
				+ StringTools.hex(from, 1).toLowerCase() + ",100");
			if (chunk == "") break;
			out.add(chunk.substr(1));
			from += chunk.length - 1;
			if (chunk.charAt(0) == "l") break;
		}

		return out.toString();
	}

	static function talk(gdb:Gdb, client:Socket, answers:Packet, body:String):String {
		send(client, Packet.frame(body));

		for (_ in 0...4000) {
			gdb.attend(0);
			gdb.advance(2000);

			final ready = answers.next();
			if (ready != null) {
				if (spoken(ready)) {
					output.add(Packet.decode(ready.substr(1)));
					continue;
				}
				return ready;
			}

			if (Socket.select([client], [], [], 0.002).read.length == 0) continue;
			final text = take(client);
			if (text == null) return "";
			answers.feed(text);
		}

		return "";
	}

	static function spoken(body:String):Bool {
		if (body.charAt(0) != "O" || body.length < 3 || (body.length & 1) == 0) return false;

		for (i in 1...body.length) {
			final code = body.charCodeAt(i);
			final hex = (code >= "0".code && code <= "9".code) || (code >= "a".code && code <= "f".code);
			if (!hex) return false;
		}

		return true;
	}

	static function send(client:Socket, text:String):Void {
		final bytes = Bytes.alloc(text.length);
		for (i in 0...text.length) bytes.set(i, text.charCodeAt(i) & 0xFF);
		client.output.writeBytes(bytes, 0, bytes.length);
		client.output.flush();
	}

	static function take(client:Socket):Null<String> {
		final buffer = Bytes.alloc(4096);

		try {
			final got = client.input.readBytes(buffer, 0, buffer.length);
			if (got <= 0) return null;
			final out = new StringBuf();
			for (i in 0...got) out.addChar(buffer.get(i));
			return out.toString();
		} catch (e:Dynamic) {
			return null;
		}
	}

	static function count(text:String, what:String):Int {
		var found = 0;
		var from = 0;

		while (true) {
			final at = text.indexOf(what, from);
			if (at < 0) return found;
			found++;
			from = at + what.length;
		}
	}

	static function main():Void {
		run();
	}

	public static function run():Void {
		Sys.println("");
		Sys.println("what a packet is made of");
		framing();

		Sys.println("what arrives a piece at a time");
		stream();

		Sys.println("what a session says");
		session();

		Sys.println("");
		Sys.println(checks + " gdb checks, " + failures + " failures");
		if (failures > 0) Sys.exit(1);
	}
}

package hx68k.test;

import hx68k.cpu.m68k.M68000;
import hx68k.debug.Code;
import hx68k.debug.Disassembler;
import hx68k.test.SstFormat;
import haxe.io.Path;
import sys.FileSystem;

typedef Expectation = {
	final stems:Array<String>;
	final size:String;
	final contains:String;
}

typedef Tally = {
	var tests:Int;
	var named:Int;
	var matched:Int;
	var operands:Int;
	var measurable:Int;
	var sized:Int;
	var branching:Int;
	var faulting:Int;
}

class DisassemblyCheck {
	static final SUITE = Root.vendor("SingleStepTests-m68000/v1");

	static final FLOW = [
		"BSR", "Bcc", "DBcc", "JMP", "JSR", "RTE", "RTR", "RTS", "TRAP", "TRAPV", "CHK",
		"STOP", "RESET", "ILLEGAL_LINEA", "ILLEGAL_LINEF", "DIVS", "DIVU",
		"MOVEtoSR", "MOVEfromUSP", "MOVEtoUSP", "ANDItoSR", "EORItoSR", "ORItoSR"
	];

	static function main():Void {
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
		var filter:String = null;
		var showFail = 0;

		for (a in args) {
			if (a.charAt(0) == "-" && a.charAt(1) == "f") showFail = a.length > 2 ? Std.parseInt(a.substr(2)) : 5;
			else if (a.charAt(0) != "-") filter = a;
		}

		if (!FileSystem.exists(SUITE)) {
			Sys.println("SingleStepTests suite missing; skipping disassembly conformance.");
			return;
		}

		final files = [];
		for (f in FileSystem.readDirectory(SUITE)) {
			if (!StringTools.endsWith(f, ".json.bin")) continue;
			if (filter != null && f.toLowerCase().indexOf(filter.toLowerCase()) < 0) continue;
			files.push(f);
		}
		files.sort((a, b) -> a < b ? -1 : 1);

		final total:Tally = {tests: 0, named: 0, matched: 0, operands: 0, measurable: 0, sized: 0, branching: 0, faulting: 0};
		var wrongGroups = 0;

		for (f in files) {
			final group = f.substr(0, f.length - 9);
			final tally = runGroup(group, SstReader.readFile(Path.join([SUITE, f])), showFail);

			total.tests += tally.tests;
			total.named += tally.named;
			total.matched += tally.matched;
			total.operands += tally.operands;
			total.measurable += tally.measurable;
			total.sized += tally.sized;
			total.branching += tally.branching;
			total.faulting += tally.faulting;

			if (tally.matched < tally.tests || tally.operands < tally.tests || tally.sized < tally.measurable) {
				wrongGroups++;
				Sys.println(StringTools.rpad(group, " ", 16)
					+ " named " + pct(tally.named, tally.tests)
					+ "   instruction " + pct(tally.matched, tally.tests)
					+ "   operands " + pct(tally.operands, tally.tests)
					+ "   length " + pct(tally.sized, tally.measurable));
			}
		}

		Sys.println("");
		Sys.println("groups         : " + files.length);
		Sys.println("instructions   : " + total.tests);
		Sys.println("named          : " + pct(total.named, total.tests) + " (not dc.w)");
		Sys.println("instruction    : " + pct(total.matched, total.tests) + " agree with the group name");
		Sys.println("operands       : " + pct(total.operands, total.tests) + " name every register the suite does");
		Sys.println("length         : " + pct(total.sized, total.measurable)
			+ " agree with the fixture's own pc, over " + total.measurable + " measurable");
		Sys.println("  not measured : " + total.branching + " in groups that change the flow, "
			+ total.faulting + " that took an address error");

		final perfect = total.matched == total.tests && total.operands == total.tests
			&& total.sized == total.measurable;
		Sys.println("GROUPS WRONG   : " + wrongGroups + " / " + files.length);

		final decodersAgree = filter == null ? opcodeSpace(showFail) : true;

		if (args.indexOf("--ci") >= 0 && !(perfect && decodersAgree)) Sys.exit(1);
	}

	static function opcodeSpace(showFail:Int):Bool {
		final cpu = new M68000(new SstBus());
		final code = new WordCode();
		final disassembler = new Disassembler(code);

		var agree = 0;
		var namedOnly = 0;
		var dispatchedOnly = 0;
		final onlyNamed = new Array<String>();
		final onlyDispatched = new Array<String>();

		var trapped = 0;

		for (op in 0...0x10000) {
			code.opcode = op;
			final named = !StringTools.startsWith(disassembler.at(0).text, "dc.w");
			final dispatched = cpu.isImplemented(op);

			final line = op >> 12;
			if (line == 0xA || line == 0xF) {
				if (!named && dispatched) trapped++;
				continue;
			}

			if (named == dispatched) {
				agree++;
				continue;
			}

			if (named) {
				namedOnly++;
				if (onlyNamed.length < showFail)
					onlyNamed.push("  $" + StringTools.hex(op, 4) + "  " + disassembler.at(0).text);
			} else {
				dispatchedOnly++;
				if (onlyDispatched.length < showFail) onlyDispatched.push("  $" + StringTools.hex(op, 4));
			}
		}

		final compared = 0x10000 - 0x2000;

		Sys.println("");
		Sys.println("opcode words   : 65536, of which 8192 are the line A and line F traps");
		Sys.println("decoders agree : " + pct(agree, compared) + " over the other " + compared);
		Sys.println("  named, not dispatched : " + namedOnly);
		for (line in onlyNamed) Sys.println(line);
		Sys.println("  dispatched, not named : " + dispatchedOnly);
		for (line in onlyDispatched) Sys.println(line);
		Sys.println("line A and line F : " + trapped
			+ " of 8192 trapped by the core and named by neither");

		return agree == compared && trapped == 0x2000;
	}

	static function runGroup(group:String, tests:Array<SstTest>, showFail:Int):Tally {
		final tally:Tally = {tests: 0, named: 0, matched: 0, operands: 0, measurable: 0, sized: 0, branching: 0, faulting: 0};
		final want = expectation(group);
		final flow = FLOW.indexOf(group) >= 0;
		final code = new FixtureCode();
		final disassembler = new Disassembler(code);
		var shown = 0;

		for (t in tests) {
			tally.tests++;
			code.load(t.initial);

			final address = (t.initial.pc - 4) & 0xFFFFFF;
			final line = disassembler.at(address);
			final stem = mnemonic(line.text);

			final named = stem != "dc.w";
			if (named) tally.named++;

			final agrees = matches(stem, line.text, want);
			if (agrees) tally.matched++;

			final sameOperands = operandsAgree(t.name, line.text);
			if (sameOperands) tally.operands++;

			final measurable = !flow && !faulted(t);
			if (flow) tally.branching++;
			else if (!measurable) tally.faulting++;

			if (measurable) {
				tally.measurable++;
				if (line.length == t.expected.pc - t.initial.pc) tally.sized++;
			}

			final ok = agrees && sameOperands && (!measurable || line.length == t.expected.pc - t.initial.pc);
			if (ok || shown >= showFail) continue;

			shown++;
			Sys.println("  " + group + " " + t.name);
			Sys.println("    at $" + StringTools.hex(address, 6) + "  " + line.text
				+ "   (" + line.length + " bytes, fixture says " + (t.expected.pc - t.initial.pc) + ")");
			Sys.println("    words " + words(code, address, 5));
		}

		return tally;
	}

	static function faulted(t:SstTest):Bool {
		for (transaction in t.transactions) {
			if (transaction.kind == ReadAddressError || transaction.kind == WriteAddressError) return true;
		}
		return false;
	}

	static function words(code:FixtureCode, address:Int, count:Int):String {
		final out = [];
		for (i in 0...count) out.push(StringTools.hex(code.word(address + i * 2), 4));
		return out.join(" ");
	}

	static function mnemonic(text:String):String {
		final space = text.indexOf(" ");
		return space < 0 ? text : text.substr(0, space);
	}

	static function matches(stem:String, text:String, want:Expectation):Bool {
		if (want.contains != "" && text.indexOf(want.contains) < 0) return false;
		for (candidate in want.stems) if (candidate == stem) return true;

		var name = stem;
		var size = "";
		final dot = name.indexOf(".");
		if (dot >= 0) {
			size = name.substr(dot);
			name = name.substr(0, dot);
		}

		if (want.size != "" && want.size != size) return false;

		for (candidate in want.stems) {
			if (candidate == name) return true;
			if (candidate == "B?" && isConditional(name, 1)) return true;
			if (candidate == "DB?" && (name == "DBRA" || isConditional(name, 2))) return true;
			if (candidate == "S?" && isConditional(name, 1)) return true;
		}

		return false;
	}

	static function isConditional(name:String, prefix:Int):Bool {
		final tail = name.substr(prefix);
		for (condition in ["T", "F", "HI", "LS", "CC", "CS", "NE", "EQ", "VC", "VS", "PL", "MI", "GE", "LT", "GT", "LE"]) {
			if (tail == condition) return true;
		}
		return false;
	}

	static function expectation(group:String):Expectation {
		switch (group) {
			case "Bcc": return {stems: ["B?", "BRA", "BSR"], size: "", contains: ""};
			case "BSR": return {stems: ["BSR"], size: "", contains: ""};
			case "DBcc": return {stems: ["DB?"], size: "", contains: ""};
			case "Scc": return {stems: ["S?"], size: "", contains: ""};
			case "MOVE.q": return {stems: ["MOVEQ"], size: "", contains: ""};
			case "UNLINK": return {stems: ["UNLK"], size: "", contains: ""};
			case "ILLEGAL_LINEA", "ILLEGAL_LINEF": return {stems: ["dc.w"], size: "", contains: ""};
			case "MOVEfromSR": return {stems: ["MOVE"], size: "", contains: "SR,"};
			case "MOVEtoSR": return {stems: ["MOVE"], size: "", contains: ",SR"};
			case "MOVEtoCCR": return {stems: ["MOVE"], size: "", contains: ",CCR"};
			case "MOVEfromUSP": return {stems: ["MOVE"], size: "", contains: "USP,"};
			case "MOVEtoUSP": return {stems: ["MOVE"], size: "", contains: ",USP"};
			case "ANDItoCCR": return {stems: ["ANDI"], size: "", contains: ",CCR"};
			case "ANDItoSR": return {stems: ["ANDI"], size: "", contains: ",SR"};
			case "EORItoCCR": return {stems: ["EORI"], size: "", contains: ",CCR"};
			case "EORItoSR": return {stems: ["EORI"], size: "", contains: ",SR"};
			case "ORItoCCR": return {stems: ["ORI"], size: "", contains: ",CCR"};
			case "ORItoSR": return {stems: ["ORI"], size: "", contains: ",SR"};
			case "CHK", "DIVS", "DIVU", "MULS", "MULU": return {stems: [group], size: "", contains: ""};
			case _:
		}

		final dot = group.indexOf(".");
		if (dot < 0) return {stems: [group], size: "", contains: ""};

		final stem = group.substr(0, dot);
		final size = group.substr(dot);
		return switch (stem) {
			case "ADD": {stems: ["ADD", "ADDA", "ADDI", "ADDQ", "ADDX"], size: size, contains: ""};
			case "SUB": {stems: ["SUB", "SUBA", "SUBI", "SUBQ", "SUBX"], size: size, contains: ""};
			case "AND": {stems: ["AND", "ANDI"], size: size, contains: ""};
			case "OR": {stems: ["OR", "ORI"], size: size, contains: ""};
			case "EOR": {stems: ["EOR", "EORI"], size: size, contains: ""};
			case "CMP": {stems: ["CMP", "CMPA", "CMPI", "CMPM"], size: size, contains: ""};
			case _: {stems: [stem], size: size, contains: ""};
		}
	}

	static function operandsAgree(name:String, text:String):Bool {
		var i = 0;
		while (i < name.length - 1) {
			final letter = name.charAt(i);
			final digit = name.charCodeAt(i + 1);

			if ((letter == "A" || letter == "D") && digit >= "0".code && digit <= "7".code) {
				final before = i == 0 ? " " : name.charAt(i - 1);
				final after = i + 2 < name.length ? name.charAt(i + 2) : " ";
				if (!isWordCharacter(before) && !isWordCharacter(after)
					&& text.indexOf(letter + name.charAt(i + 1)) < 0) return false;
				i += 2;
				continue;
			}

			i++;
		}

		return true;
	}

	static inline function isWordCharacter(c:String):Bool {
		return c >= "0" && c <= "9" || c >= "A" && c <= "Z" || c >= "a" && c <= "z";
	}

	static function pct(n:Int, total:Int):String {
		if (total == 0) return "   n/a";
		final v = 100.0 * n / total;
		return StringTools.lpad(Std.string(Math.round(v * 10) / 10), " ", 5) + "%";
	}
}

class WordCode implements Code {
	public var opcode:Int = 0;

	public function new() {}

	public function word(address:Int):Int {
		return address == 0 ? opcode : 0;
	}
}

class FixtureCode implements Code {
	final memory = new haxe.ds.IntMap<Int>();

	public function new() {}

	public function load(state:SstState):Void {
		memory.clear();
		for (cell in state.ram) memory.set(cell.addr & 0xFFFFFE, cell.value & 0xFFFF);
		memory.set((state.pc - 4) & 0xFFFFFE, state.prefetch[0] & 0xFFFF);
		memory.set((state.pc - 2) & 0xFFFFFE, state.prefetch[1] & 0xFFFF);
	}

	public function word(address:Int):Int {
		final value = memory.get(address & 0xFFFFFE);
		return value == null ? 0 : value;
	}
}

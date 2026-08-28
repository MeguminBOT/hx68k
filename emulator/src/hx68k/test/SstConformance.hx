package hx68k.test;

import hx68k.cpu.m68k.M68000;
import hx68k.test.SstFormat;
import haxe.io.Path;
import sys.FileSystem;

typedef Score = {
	var tests:Int;
	var skipped:Int;
	var state:Int;
	var cycles:Int;
	var trans:Int;
	var all:Int;
}

class SstConformance {
	static final SUITE = Root.vendor("SingleStepTests-m68000/v1");

	static function main():Void {
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
		var filter:String = null;
		var verbose = false;
		var showFail = 0;

		for (i in 0...args.length) {
			final a = args[i];
			if (a == "-v") verbose = true;
			else if (a.charAt(0) == "-" && a.charAt(1) == "f") showFail = a.length > 2 ? Std.parseInt(a.substr(2)) : 3;
			else if (a.charAt(0) != "-") filter = a;
		}

		final files = [];
		for (f in FileSystem.readDirectory(SUITE)) {
			if (!StringTools.endsWith(f, ".json.bin")) continue;
			if (filter != null && f.toLowerCase().indexOf(filter.toLowerCase()) < 0) continue;
			files.push(f);
		}
		files.sort((a, b) -> a < b ? -1 : 1);

		final total:Score = {tests: 0, skipped: 0, state: 0, cycles: 0, trans: 0, all: 0};
		var implementedGroups = 0;

		for (f in files) {
			final tests = SstReader.readFile(Path.join([SUITE, f]));
			final s = runFile(tests, showFail);

			total.tests += s.tests;
			total.skipped += s.skipped;
			total.state += s.state;
			total.cycles += s.cycles;
			total.trans += s.trans;
			total.all += s.all;

			final covered = s.tests - s.skipped;
			if (covered > 0) implementedGroups++;

			if (verbose || (covered > 0 && filter != null) || (covered > 0 && s.all < covered)) {
				final group = f.substr(0, f.length - 9);
				Sys.println(pad(group, 14) + " " + pct(s.all, s.tests) + " all"
					+ "   state " + pct(s.state, s.tests)
					+ "   cycles " + pct(s.cycles, s.tests)
					+ "   bus " + pct(s.trans, s.tests)
					+ "   skipped " + s.skipped);
			}
		}

		Sys.println("");
		Sys.println("groups touched : " + implementedGroups + " / " + files.length);
		Sys.println("tests          : " + total.tests);
		Sys.println("skipped        : " + total.skipped + " (opcode not implemented)");
		Sys.println("state pass     : " + pct(total.state, total.tests));
		Sys.println("cycle pass     : " + pct(total.cycles, total.tests));
		Sys.println("bus pass       : " + pct(total.trans, total.tests));
		Sys.println("FULL PASS      : " + pct(total.all, total.tests) + " of all tests");

		final covered = total.tests - total.skipped;
		Sys.println("");
		Sys.println("covered tests  : " + covered);
		Sys.println("COVERED PASS   : " + pct(total.all, covered) + "  (state "
			+ pct(total.state, covered) + ", cycles " + pct(total.cycles, covered)
			+ ", bus " + pct(total.trans, covered) + ")");

		if (args.indexOf("--ci") >= 0 && covered > 0 && total.all < covered) Sys.exit(1);
	}

	static function pad(s:String, n:Int):String return StringTools.rpad(s, " ", n);

	static function pct(n:Int, total:Int):String {
		if (total == 0) return "   n/a";
		final v = 100.0 * n / total;
		return StringTools.lpad(Std.string(Math.round(v * 10) / 10), " ", 5) + "%";
	}

	static function runFile(tests:Array<SstTest>, showFail:Int):Score {
		final score:Score = {tests: 0, skipped: 0, state: 0, cycles: 0, trans: 0, all: 0};
		final bus = new SstBus();
		final cpu = new M68000(bus);
		var shown = 0;

		for (t in tests) {
			score.tests++;

			if (!cpu.isImplemented(t.initial.prefetch[0])) {
				score.skipped++;
				continue;
			}

			bus.load(t.initial);
			cpu.bus = bus;
			apply(cpu, t.initial);

			var crashed = false;
			try {
				cpu.step();
			} catch (e:Dynamic) {
				crashed = true;
			}
			bus.finish();

			final okState = !crashed && stateMatches(cpu, bus, t);
			final okCycles = !crashed && bus.cycles == t.cycles;
			final okTrans = !crashed && transMatches(bus.log, t.transactions);

			if (okState) score.state++;
			if (okCycles) score.cycles++;
			if (okTrans) score.trans++;
			if (okState && okCycles && okTrans) score.all++;
			else if (shown < showFail) {
				shown++;
				report(cpu, bus, t, okState, okCycles, okTrans, crashed);
			}
		}

		return score;
	}

	static function apply(c:M68000, st:SstState):Void {
		for (i in 0...8) c.d[i] = st.d[i];
		for (i in 0...7) c.a[i] = st.a[i];

		final sup = (st.sr & 0x2000) != 0;
		c.s = sup;
		c.a[7] = sup ? st.ssp : st.usp;
		c.inactiveSp = sup ? st.usp : st.ssp;
		c.t = (st.sr & 0x8000) != 0;
		c.imask = (st.sr >> 8) & 7;
		c.setCcr(st.sr);

		c.pc = st.pc | 0;
		c.ird = st.prefetch[0] & 0xFFFF;
		c.irc = st.prefetch[1] & 0xFFFF;
		c.faulted = false;
	}

	static function stateMatches(c:M68000, bus:SstBus, t:SstTest):Bool {
		final e = t.expected;

		for (i in 0...8) if ((c.d[i] | 0) != (e.d[i] | 0)) return false;
		for (i in 0...7) if ((c.a[i] | 0) != (e.a[i] | 0)) return false;

		final usp = c.s ? c.inactiveSp : c.a[7];
		final ssp = c.s ? c.a[7] : c.inactiveSp;
		if ((usp | 0) != (e.usp | 0)) return false;
		if ((ssp | 0) != (e.ssp | 0)) return false;

		if (c.getSr() != (e.sr & 0xFFFF)) return false;
		if ((c.pc | 0) != (e.pc | 0)) return false;
		if (c.ird != (e.prefetch[0] & 0xFFFF)) return false;
		if (c.irc != (e.prefetch[1] & 0xFFFF)) return false;

		for (cell in e.ram) {
			final got = bus.mem.get(cell.addr & 0xFFFFFE);
			final want = cell.value & 0xFFFF;
			if ((got == null ? 0 : got) != want) return false;
		}

		return true;
	}

	static function merge(list:Array<SstTransaction>):Array<SstTransaction> {
		final out = [];
		for (tr in list) {
			if (tr.kind == Idle && out.length > 0 && out[out.length - 1].kind == Idle) {
				out[out.length - 1].cycles += tr.cycles;
			} else {
				final copy = new SstTransaction();
				copy.kind = tr.kind;
				copy.cycles = tr.cycles;
				copy.fc = tr.fc;
				copy.addr = tr.addr;
				copy.data = tr.data;
				copy.uds = tr.uds;
				copy.lds = tr.lds;
				out.push(copy);
			}
		}
		return out;
	}

	static function transMatches(got:Array<SstTransaction>, want:Array<SstTransaction>):Bool {
		final a = merge(got);
		final b = merge(want);
		if (a.length != b.length) return false;

		for (i in 0...a.length) {
			final x = a[i], y = b[i];
			if (x.kind != y.kind || x.cycles != y.cycles) return false;
			if (x.kind == Idle) continue;
			if (x.fc != y.fc) return false;
			if ((x.addr & 0xFFFFFF) != (y.addr & 0xFFFFFF)) return false;
			if (x.uds != y.uds || x.lds != y.lds) return false;
			if (x.kind == ReadAddressError || x.kind == WriteAddressError) continue;
			if ((x.data & 0xFFFF) != (y.data & 0xFFFF)) return false;
		}
		return true;
	}

	static function report(c:M68000, bus:SstBus, t:SstTest, okState:Bool, okCycles:Bool, okTrans:Bool, crashed:Bool):Void {
		Sys.println("  MISMATCH " + t.name + (crashed ? " [threw]" : ""));
		if (!okState) {
			final e = t.expected;
			for (i in 0...8) if ((c.d[i] | 0) != (e.d[i] | 0))
				Sys.println("    d" + i + " got " + hex(c.d[i]) + " want " + hex(e.d[i]));
			for (i in 0...7) if ((c.a[i] | 0) != (e.a[i] | 0))
				Sys.println("    a" + i + " got " + hex(c.a[i]) + " want " + hex(e.a[i]));
			if (c.getSr() != (e.sr & 0xFFFF))
				Sys.println("    sr got " + StringTools.hex(c.getSr(), 4) + " want " + StringTools.hex(e.sr & 0xFFFF, 4));
			final gotUsp = c.s ? c.inactiveSp : c.a[7];
			final gotSsp = c.s ? c.a[7] : c.inactiveSp;
			if ((gotUsp | 0) != (e.usp | 0)) Sys.println("    usp got " + hex(gotUsp) + " want " + hex(e.usp));
			if ((gotSsp | 0) != (e.ssp | 0)) Sys.println("    ssp got " + hex(gotSsp) + " want " + hex(e.ssp));
			if ((c.pc | 0) != (e.pc | 0))
				Sys.println("    pc got " + hex(c.pc) + " want " + hex(e.pc));
			if (c.ird != (e.prefetch[0] & 0xFFFF) || c.irc != (e.prefetch[1] & 0xFFFF))
				Sys.println("    prefetch got [" + StringTools.hex(c.ird, 4) + "," + StringTools.hex(c.irc, 4)
					+ "] want [" + StringTools.hex(e.prefetch[0], 4) + "," + StringTools.hex(e.prefetch[1], 4) + "]");
			for (cell in e.ram) {
				final g = bus.mem.get(cell.addr & 0xFFFFFE);
				if ((g == null ? 0 : g) != (cell.value & 0xFFFF))
					Sys.println("    mem " + StringTools.hex(cell.addr, 6) + " got "
						+ StringTools.hex(g == null ? 0 : g, 4) + " want " + StringTools.hex(cell.value, 4));
			}
		}
		if (!okCycles) Sys.println("    cycles got " + bus.cycles + " want " + t.cycles);
		if (!okTrans) {
			Sys.println("    bus got:");
			for (tr in merge(bus.log)) Sys.println("      " + tr.toString());
			Sys.println("    bus want:");
			for (tr in merge(t.transactions)) Sys.println("      " + tr.toString());
		}
		Sys.println("");
	}

	static function hex(v:Int):String return StringTools.hex(v | 0, 8);
}

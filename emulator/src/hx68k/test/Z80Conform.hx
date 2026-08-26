package hx68k.test;

import haxe.io.Path;
import hx68k.cpu.z80.Z80;
import hx68k.test.Z80Format;

class Z80Conform {
	static inline final SUITE = "../vendor/SingleStepTests-z80/v1bin";

	static function main():Void {
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
		final filter = args.length > 0 && args[0].charAt(0) != "-" ? args[0] : null;
		final verbose = args.indexOf("-f") >= 0;

		if (!sys.FileSystem.exists(SUITE)) {
			Sys.println("converted fixtures not found at " + SUITE);
			Sys.println("run: neko bin/z80convert.n");
			Sys.exit(2);
		}

		final files = [];
		for (name in sys.FileSystem.readDirectory(SUITE)) {
			if (!StringTools.endsWith(name, ".bin")) continue;
			if (filter != null && name.toLowerCase().indexOf(filter.toLowerCase()) < 0) continue;
			files.push(name);
		}
		files.sort((a, b) -> a < b ? -1 : 1);

		var groups = 0;
		var covered = 0;
		var tests = 0;
		var skipped = 0;
		var state = 0;
		var timing = 0;
		var pins = 0;
		var whole = 0;
		var shown = 0;

		final bus = new Z80Bus();
		final cpu = new Z80(bus);

		for (name in files) {
			groups++;
			final group = Path.withoutExtension(name);
			final cases = Z80Format.read(Path.join([SUITE, name]));
			var groupCovered = false;

			for (test in cases) {
				tests++;

				final opcode = bus0(test);
				if (!cpu.isImplemented(opcode)) {
					skipped++;
					continue;
				}
				groupCovered = true;

				bus.load(test.initial, test.ports);
				load(cpu, test.initial);

				var failed = false;
				try {
					cpu.step();
				} catch (e:Dynamic) {
					failed = true;
				}

				final stateOk = !failed && sameState(cpu, bus, test.expected);
				final timingOk = !failed && bus.log.length == test.cycles.length;
				final pinsOk = !failed && timingOk && sameCycles(bus.log, test.cycles);

				if (stateOk) state++;
				if (timingOk) timing++;
				if (pinsOk) pins++;
				if (stateOk && timingOk && pinsOk) whole++;
				else if (verbose && shown < 4) {
					shown++;
					report(test, cpu, bus, stateOk, timingOk, pinsOk);
				}
			}

			if (groupCovered) covered++;
		}

		final ran = tests - skipped;
		Sys.println("");
		Sys.println("groups         : " + covered + " / " + groups);
		Sys.println("tests          : " + tests);
		Sys.println("skipped        : " + skipped + " (opcode not implemented)");
		if (ran == 0) {
			Sys.println("nothing ran");
			return;
		}
		Sys.println("state pass     : " + percent(state, ran));
		Sys.println("cycle pass     : " + percent(timing, ran));
		Sys.println("pin pass       : " + percent(pins, ran));
		Sys.println("FULL PASS      : " + percent(whole, ran) + " of the " + ran + " that ran");
		Sys.println("whole suite    : " + percent(whole, tests));
	}

	static function percent(part:Int, total:Int):String {
		if (total == 0) return "   0%";
		return StringTools.lpad(Std.string(Math.round(part * 1000.0 / total) / 10), " ", 5) + "%";
	}

	static function bus0(test:Z80Test):Int {
		for (cell in test.initial.ram) if (cell.addr == test.initial.pc) return cell.value;
		return 0;
	}

	static function load(cpu:Z80, state:Z80State):Void {
		cpu.pc = state.pc;
		cpu.sp = state.sp;
		cpu.ix = state.ix;
		cpu.iy = state.iy;
		cpu.wz = state.wz;
		cpu.af2 = state.af2;
		cpu.bc2 = state.bc2;
		cpu.de2 = state.de2;
		cpu.hl2 = state.hl2;

		cpu.a = state.a;
		cpu.f = state.f;
		cpu.b = state.b;
		cpu.c = state.c;
		cpu.d = state.d;
		cpu.e = state.e;
		cpu.h = state.h;
		cpu.l = state.l;
		cpu.i = state.i;
		cpu.r = state.r;

		cpu.im = state.im;
		cpu.p = state.p;
		cpu.q = state.q;
		cpu.iff1 = state.iff1 != 0;
		cpu.iff2 = state.iff2 != 0;
		cpu.ei = state.ei != 0;
		cpu.halted = false;
	}

	static function sameState(cpu:Z80, bus:Z80Bus, want:Z80State):Bool {
		if (cpu.pc != want.pc || cpu.sp != want.sp || cpu.ix != want.ix || cpu.iy != want.iy) return false;
		if (cpu.wz != want.wz) return false;
		if (cpu.af2 != want.af2 || cpu.bc2 != want.bc2 || cpu.de2 != want.de2 || cpu.hl2 != want.hl2) return false;
		if (cpu.a != want.a || cpu.f != want.f || cpu.b != want.b || cpu.c != want.c) return false;
		if (cpu.d != want.d || cpu.e != want.e || cpu.h != want.h || cpu.l != want.l) return false;
		if (cpu.i != want.i || cpu.r != want.r) return false;
		if (cpu.im != want.im || cpu.p != want.p || cpu.q != want.q) return false;
		if ((cpu.iff1 ? 1 : 0) != want.iff1 || (cpu.iff2 ? 1 : 0) != want.iff2) return false;
		if ((cpu.ei ? 1 : 0) != want.ei) return false;

		for (cell in want.ram) if (bus.peek(cell.addr) != cell.value) return false;
		return true;
	}

	static function sameCycles(got:Array<Z80Cycle>, want:Array<Z80Cycle>):Bool {
		for (i in 0...want.length) {
			final a = got[i];
			final b = want[i];
			if ((a.pins & 0x0F) != (b.pins & 0x0F)) return false;
			if ((b.pins & Z80Cycle.HAS_ADDRESS) != 0 && a.address != b.address) return false;
			if ((b.pins & Z80Cycle.HAS_VALUE) != 0
				&& ((a.pins & Z80Cycle.HAS_VALUE) == 0 || a.value != b.value)) return false;
			if ((b.pins & Z80Cycle.HAS_VALUE) == 0 && (a.pins & Z80Cycle.HAS_VALUE) != 0) return false;
		}
		return true;
	}

	static function report(test:Z80Test, cpu:Z80, bus:Z80Bus, stateOk:Bool, timingOk:Bool,
			pinsOk:Bool):Void {
		Sys.println("");
		Sys.println("--- " + test.name + (stateOk ? "" : "  state") + (timingOk ? "" : "  cycles")
			+ (pinsOk ? "" : "  pins"));

		if (!stateOk) {
			Sys.println("  want pc=" + hex(test.expected.pc, 4) + " sp=" + hex(test.expected.sp, 4)
				+ " a=" + hex(test.expected.a, 2) + " f=" + hex(test.expected.f, 2)
				+ " wz=" + hex(test.expected.wz, 4) + " r=" + hex(test.expected.r, 2)
				+ " q=" + hex(test.expected.q, 2) + " p=" + test.expected.p
				+ " iff=" + test.expected.iff1 + test.expected.iff2 + " ei=" + test.expected.ei
				+ " im=" + test.expected.im);
			Sys.println("  got  pc=" + hex(cpu.pc, 4) + " sp=" + hex(cpu.sp, 4)
				+ " a=" + hex(cpu.a, 2) + " f=" + hex(cpu.f, 2)
				+ " wz=" + hex(cpu.wz, 4) + " r=" + hex(cpu.r, 2) + " q=" + hex(cpu.q, 2)
				+ " p=" + cpu.p + " iff=" + (cpu.iff1 ? 1 : 0) + (cpu.iff2 ? 1 : 0)
				+ " ei=" + (cpu.ei ? 1 : 0) + " im=" + cpu.im);
		}

		if (!timingOk || !pinsOk) {
			final rows = test.cycles.length > bus.log.length ? test.cycles.length : bus.log.length;
			for (i in 0...rows) {
				final want = i < test.cycles.length ? test.cycles[i].toString() : "-";
				final got = i < bus.log.length ? bus.log[i].toString() : "-";
				Sys.println("  " + StringTools.rpad(want, " ", 22) + got);
			}
		}
	}

	static inline function hex(value:Int, width:Int):String {
		return StringTools.hex(value, width);
	}
}

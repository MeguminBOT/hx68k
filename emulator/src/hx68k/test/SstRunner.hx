package hx68k.test;

import hx68k.test.SstFormat;
import sys.FileSystem;
import haxe.io.Path;

class SstRunner {
	static inline final SUITE = "../vendor/SingleStepTests-m68000/v1";

	static function main() {
		final args = Sys.args();
		final filter = args.length > 0 && args[0].charAt(0) != "-" ? args[0] : null;
		final verbose = args.indexOf("-v") >= 0;

		if (!FileSystem.exists(SUITE)) {
			Sys.println('suite not found at ${SUITE}');
			Sys.exit(2);
		}

		final files = [];
		for (f in FileSystem.readDirectory(SUITE)) {
			if (!StringTools.endsWith(f, ".json.bin")) continue;
			if (filter != null && f.toLowerCase().indexOf(filter.toLowerCase()) < 0) continue;
			files.push(f);
		}
		files.sort((a, b) -> a < b ? -1 : 1);

		if (files.length == 0) {
			Sys.println("no matching test files");
			Sys.exit(2);
		}

		var totalTests = 0;
		var totalTrans = 0;
		var totalCycles = 0;
		final t0 = haxe.Timer.stamp();

		for (f in files) {
			final tests = SstReader.readFile(Path.join([SUITE, f]));
			var trans = 0;
			var cycles = 0;
			for (t in tests) {
				trans += t.transactions.length;
				cycles += t.cycles;
			}

			totalTests += tests.length;
			totalTrans += trans;
			totalCycles += cycles;

			if (verbose || files.length <= 4) {
				final group = f.substr(0, f.length - 9);
				Sys.println('${StringTools.rpad(group, " ", 12)} ${StringTools.lpad("" + tests.length, " ", 6)} tests'
					+ ' ${StringTools.lpad("" + trans, " ", 8)} transactions'
					+ ' ${StringTools.lpad("" + cycles, " ", 9)} cycles');
			}
		}

		final dt = haxe.Timer.stamp() - t0;
		Sys.println("");
		Sys.println('${files.length} files, ${totalTests} tests, ${totalTrans} transactions, ${totalCycles} cycles');
		Sys.println('parsed in ${Math.round(dt * 1000)} ms');

		if (files.length <= 4 && verbose) dumpFirst(Path.join([SUITE, files[0]]));
	}

	static function dumpFirst(path:String) {
		final tests = SstReader.readFile(path);
		final t = tests[0];
		Sys.println("");
		Sys.println('--- ${t.name} ---');
		Sys.println('cycles: ${t.cycles}');
		Sys.println('initial pc=${StringTools.hex(t.initial.pc, 8)} sr=${StringTools.hex(t.initial.sr, 4)}'
			+ ' prefetch=[${StringTools.hex(t.initial.prefetch[0], 4)}, ${StringTools.hex(t.initial.prefetch[1], 4)}]');
		Sys.println('initial ram cells: ${t.initial.ram.length}');
		for (i in 0...(t.initial.ram.length < 6 ? t.initial.ram.length : 6)) {
			final c = t.initial.ram[i];
			Sys.println('  ${StringTools.hex(c.addr, 6)} = ${StringTools.hex(c.value, 4)}');
		}
		Sys.println('final   pc=${StringTools.hex(t.expected.pc, 8)} sr=${StringTools.hex(t.expected.sr, 4)}'
			+ ' prefetch=[${StringTools.hex(t.expected.prefetch[0], 4)}, ${StringTools.hex(t.expected.prefetch[1], 4)}]');
		Sys.println('transactions:');
		for (tr in t.transactions) Sys.println('  ${tr.toString()}');
	}
}

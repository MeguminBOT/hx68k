package hx68k.test;

import hx68k.test.SstFormat;
import haxe.io.Path;

class SstDump {
	static final SUITE = Root.vendor("SingleStepTests-m68000/v1");

	public static function run(args:Array<String>):Void {
		final file = args[0];
		final count = args.length > 1 ? Std.parseInt(args[1]) : 4;
		final skip = args.length > 2 ? Std.parseInt(args[2]) : 0;

		final tests = SstReader.readFile(Path.join([SUITE, file + ".json.bin"]));
		var shown = 0;
		var i = skip;

		while (shown < count && i < tests.length) {
			dump(tests[i]);
			i++;
			shown++;
		}
	}

	static function h(v:Int, n:Int):String return StringTools.hex(v, n);

	static function dump(t:SstTest) {
		Sys.println('--- ${t.name}   [${t.cycles} cycles] ---');
		Sys.println('  in  pc=${h(t.initial.pc, 6)} sr=${h(t.initial.sr, 4)} irc/ird=[${h(t.initial.prefetch[0], 4)},${h(t.initial.prefetch[1], 4)}]');
		var regs = "  in  ";
		for (i in 0...8) regs += 'd$i=${h(t.initial.d[i], 8)} ';
		Sys.println(regs);
		regs = "  in  ";
		for (i in 0...7) regs += 'a$i=${h(t.initial.a[i], 8)} ';
		Sys.println(regs + 'usp=${h(t.initial.usp, 8)} ssp=${h(t.initial.ssp, 8)}');
		Sys.println('  out pc=${h(t.expected.pc, 6)} sr=${h(t.expected.sr, 4)} irc/ird=[${h(t.expected.prefetch[0], 4)},${h(t.expected.prefetch[1], 4)}]');
		Sys.println('  ram:');
		for (cell in t.initial.ram) Sys.println('    ${h(cell.addr, 6)} = ${h(cell.value, 4)}');
		for (tr in t.transactions) Sys.println('      ${tr.toString()}');
		Sys.println("");
	}
}

package hx68k.test;

import hx68k.test.Z80Format;

class Z80Convert {
	static inline final SOURCE = "../vendor/SingleStepTests-z80/v1";
	static inline final TARGET = "../vendor/SingleStepTests-z80/v1bin";

	static function main():Void {
		final filter = Sys.args().length > 0 ? Sys.args()[0] : null;

		if (!sys.FileSystem.exists(SOURCE)) {
			Sys.println("fixtures not found at " + SOURCE);
			Sys.exit(2);
		}
		if (!sys.FileSystem.exists(TARGET)) sys.FileSystem.createDirectory(TARGET);

		final names = [];
		for (name in sys.FileSystem.readDirectory(SOURCE)) {
			if (!StringTools.endsWith(name, ".json")) continue;
			if (filter != null && name.indexOf(filter) < 0) continue;
			names.push(name);
		}
		names.sort((a, b) -> a < b ? -1 : 1);

		final started = haxe.Timer.stamp();
		var written = 0;
		var tests = 0;

		for (name in names) {
			final target = TARGET + "/" + name.substr(0, name.length - 5) + ".bin";
			if (sys.FileSystem.exists(target)) continue;

			final converted = convert(SOURCE + "/" + name);
			sys.io.File.saveBytes(target, Z80Format.write(converted));

			written++;
			tests += converted.length;
			if (written % 100 == 0)
				Sys.println(written + " files, " + tests + " tests, "
					+ Math.round(haxe.Timer.stamp() - started) + " s");
		}

		Sys.println("converted " + written + " files, " + tests + " tests, in "
			+ Math.round(haxe.Timer.stamp() - started) + " s");
	}

	static function convert(path:String):Array<Z80Test> {
		final source:Array<Dynamic> = haxe.Json.parse(sys.io.File.getContent(path));
		final tests = [];

		for (entry in source) {
			final test = new Z80Test();
			test.name = entry.name;
			test.initial = state(entry.initial);
			test.expected = state(Reflect.field(entry, "final"));

			final cycles:Array<Array<Dynamic>> = entry.cycles;
			for (row in cycles) test.cycles.push(cycle(row));

			final ports:Array<Array<Dynamic>> = entry.ports;
			if (ports != null) for (row in ports) {
				final port = new Z80Port();
				port.address = row[0];
				port.value = row[1];
				port.write = row[2] == "w";
				test.ports.push(port);
			}

			tests.push(test);
		}

		return tests;
	}

	static function state(source:Dynamic):Z80State {
		final s = new Z80State();
		s.pc = number(source.pc);
		s.sp = number(source.sp);
		s.ix = number(source.ix);
		s.iy = number(source.iy);
		s.wz = number(source.wz);
		s.af2 = number(Reflect.field(source, "af_"));
		s.bc2 = number(Reflect.field(source, "bc_"));
		s.de2 = number(Reflect.field(source, "de_"));
		s.hl2 = number(Reflect.field(source, "hl_"));

		s.a = number(source.a);
		s.b = number(source.b);
		s.c = number(source.c);
		s.d = number(source.d);
		s.e = number(source.e);
		s.f = number(source.f);
		s.h = number(source.h);
		s.l = number(source.l);
		s.i = number(source.i);
		s.r = number(source.r);

		s.im = number(source.im);
		s.p = number(source.p);
		s.q = number(source.q);
		s.iff1 = number(source.iff1);
		s.iff2 = number(source.iff2);
		s.ei = number(source.ei);

		final ram:Array<Array<Int>> = source.ram;
		if (ram != null) for (cell in ram) s.ram.push({addr: cell[0], value: cell[1]});

		return s;
	}

	static function cycle(row:Array<Dynamic>):Z80Cycle {
		final out = new Z80Cycle();
		var pins = 0;

		if (row[0] != null) {
			out.address = row[0];
			pins |= Z80Cycle.HAS_ADDRESS;
		}
		if (row[1] != null) {
			out.value = row[1];
			pins |= Z80Cycle.HAS_VALUE;
		}

		final lines:String = row[2];
		if (lines.indexOf("r") >= 0) pins |= Z80Cycle.READ;
		if (lines.indexOf("w") >= 0) pins |= Z80Cycle.WRITE;
		if (lines.indexOf("m") >= 0) pins |= Z80Cycle.MEMORY;
		if (lines.indexOf("i") >= 0) pins |= Z80Cycle.PORT;

		out.pins = pins;
		return out;
	}

	static inline function number(value:Dynamic):Int {
		return value == null ? 0 : value;
	}
}

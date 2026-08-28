package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import sys.FileSystem;
import sys.io.File;
import hxres.Assembly.Item;
import hxres.Patterns.Optimization;
import hxres.Patterns.Ordering;
import hxres.Sprite.Aim;
import hxres.Frames.Frame;
import hxres.Aplib.Tally;

private typedef Fixture = {
	final name:String;
	final path:String;
	final depth:Int;
	final declared:Int;
}

class Check {
	static inline final MASK = 0x0EEE;

	static var failures:Int = 0;
	static var checks:Int = 0;

	static function ok(what:String, held:Bool, saying:String):Void {
		checks++;
		if (held) return;
		failures++;
		Sys.println("  FAIL " + what + ": " + saying);
	}

	static function main():Void {
		run(Sys.args());
	}

	public static function run(args:Array<String>):Void {
		final root = args.length > 0 ? args[0] : ".";
		final scratch = root + "/tests/.resources";
		final jar = root + "/vendor/SGDK/bin/rescomp.jar";

		Sys.println("");
		Sys.println("what a PNG decodes to");
		decoding(root);

		Sys.println("the order rescomp's cells reach a solution in");
		ordering();

		if (!hasJava() || !FileSystem.exists(jar)) {
			Sys.println("");
			Sys.println(checks + " resource checks, " + failures + " failures, "
				+ "rescomp comparison skipped with no JVM to compare against");
			if (failures > 0) Sys.exit(1);
			return;
		}

		Sys.println("what rescomp makes of the same palettes");
		palettes(root, scratch, jar);

		Sys.println("what rescomp makes of the same patterns and cells");
		images(root, scratch, jar);

		Sys.println("how rescomp cuts the same frames into hardware sprites");
		cuts(root, scratch, jar);

		Sys.println("what rescomp makes of the same binary data");
		binaries(root, scratch, jar);

		Sys.println("what xgmtool makes of the same VGM");
		tunes(root, scratch);

		Sys.println("what rescomp makes of the same WAV");
		sounds(root, scratch, jar);

		Sys.println("what aplib makes of the same bytes");
		packing(root, scratch);

		Sys.println("what lz4w makes of the same bytes");
		wordPacking(root, scratch);

		Sys.println("");
		Sys.println(checks + " resource checks, " + failures + " failures");
		if (failures > 0) Sys.exit(1);
	}

	static function hasJava():Bool {
		try {
			final probe = new sys.io.Process("java", ["-version"]);
			final code = probe.exitCode();
			probe.close();
			return code == 0;
		} catch (_:Dynamic) {
			return false;
		}
	}

	static function decoding(root:String):Void {
		final blocks = Png.read(root + "/tests/roms/art/gfx/blocks.png");
		ok("blocks.png is 32 by 32", blocks.width == 32 && blocks.height == 32,
			"got " + blocks.width + " by " + blocks.height);
		ok("blocks.png is eight bits indexed", blocks.bits == 8 && blocks.indexed(), "got " + blocks.bits + " bits");
		ok("blocks.png declares sixteen colors", blocks.declared == 16, "got " + blocks.declared);
		ok("blocks.png expands to two hundred and fifty six", blocks.palette.length == 256,
			"got " + blocks.palette.length);

		final entries = blocks.entries(MASK);
		ok("the first color is black", entries[0] == 0x0000, hex(entries[0]));
		ok("the sixteenth color is the brightest", entries[15] == 0x0CCE, hex(entries[15]));
		ok("a color past the palette repeats the last", entries[16] == 0x0CCE, hex(entries[16]));

		final diamond = Png.read(root + "/tests/roms/art/gfx/diamond.png");
		ok("diamond.png is 16 by 16", diamond.width == 16 && diamond.height == 16,
			"got " + diamond.width + " by " + diamond.height);

		var indexes = 0;
		for (i in 0...blocks.indexes.length) if (blocks.indexes.get(i) > indexes) indexes = blocks.indexes.get(i);
		ok("no pixel names a color the palette does not declare", indexes < blocks.declared,
			"the highest index is " + indexes);
	}

	static final SHAPES = [
		[0, 0, 8, 8], [8, 0, 8, 8], [16, 0, 8, 8], [0, 8, 8, 8], [8, 8, 16, 16], [24, 24, 32, 32],
		[-8, -8, 32, 8], [40, 16, 8, 24], [0, 32, 24, 8], [32, 0, 8, 8], [16, 16, 8, 8], [48, 48, 16, 16]
	];

	static final HASHES = [
		-1958739968, -882900992, -881852416, -807403520, 362807296, 516947968,
		358612992, 383516672, -662175744, -880803840, 308281344, 462422016
	];

	static final ORDERS = [
		"0,0,8,8",
		"0,0,8,8 8,0,8,8",
		"0,0,8,8 8,0,8,8 16,0,8,8",
		"0,0,8,8 8,0,8,8 16,0,8,8 0,8,8,8",
		"0,0,8,8 8,0,8,8 16,0,8,8 0,8,8,8 8,8,16,16",
		"0,0,8,8 8,0,8,8 16,0,8,8 0,8,8,8 8,8,16,16 24,24,32,32",
		"0,0,8,8 8,0,8,8 16,0,8,8 0,8,8,8 8,8,16,16 24,24,32,32 -8,-8,32,8",
		"0,0,8,8 8,0,8,8 16,0,8,8 0,8,8,8 8,8,16,16 24,24,32,32 -8,-8,32,8 40,16,8,24",
		"0,0,8,8 8,0,8,8 16,0,8,8 0,8,8,8 8,8,16,16 24,24,32,32 -8,-8,32,8 0,32,24,8 40,16,8,24",
		"0,0,8,8 8,0,8,8 16,0,8,8 0,8,8,8 8,8,16,16 24,24,32,32 -8,-8,32,8 32,0,8,8 0,32,24,8 40,16,8,24",
		"0,0,8,8 8,0,8,8 0,8,8,8 8,8,16,16 -8,-8,32,8 32,0,8,8 16,16,8,8 0,32,24,8 16,0,8,8 24,24,32,32 40,16,8,24",
		"0,0,8,8 8,0,8,8 0,8,8,8 8,8,16,16 -8,-8,32,8 32,0,8,8 16,16,8,8 0,32,24,8 16,0,8,8 24,24,32,32 48,48,16,16 40,16,8,24"
	];

	static function ordering():Void {
		var wrong = -1;
		for (i in 0...SHAPES.length) {
			final shape = SHAPES[i];
			if (HashOrder.hash(new Rect(shape[0], shape[1], shape[2], shape[3])) != HASHES[i]) {
				wrong = i;
				break;
			}
		}
		ok("a rectangle hashes as java.awt.Rectangle does", wrong < 0,
			"shape " + wrong + " hashes " + (wrong < 0 ? 0
				: HashOrder.hash(new Rect(SHAPES[wrong][0], SHAPES[wrong][1], SHAPES[wrong][2], SHAPES[wrong][3])))
				+ " where Java gives " + (wrong < 0 ? 0 : HASHES[wrong]));

		for (count in 1...SHAPES.length + 1) {
			final given = new Array<Rect>();
			for (i in 0...count) given.push(new Rect(SHAPES[i][0], SHAPES[i][1], SHAPES[i][2], SHAPES[i][3]));

			final laid = HashOrder.of(given, r -> r);
			final said = laid.map(r -> r.x + "," + r.y + "," + r.width + "," + r.height).join(" ");
			ok("a set of " + count + " cells iterates as a Java HashSet does", said == ORDERS[count - 1],
				"got " + said + ", Java gives " + ORDERS[count - 1]);
		}
	}

	static function sounds(root:String, scratch:String, jar:String):Void {
		final fixtures = hxres.Sounds.all();
		final lines = new Array<String>();

		for (each in fixtures) {
			final path = scratch + "/" + each.name + ".wav";
			File.saveBytes(path, each.data);
			lines.push('WAV ${each.name} "' + full(path) + '" ' + each.driver + " " + each.rate);
		}

		File.saveContent(scratch + "/sounds.res", lines.join("
") + "
");

		final made = new sys.io.Process("java",
			["-jar", jar, scratch + "/sounds.res", scratch + "/sounds.s"]);
		final said = made.stdout.readAll().toString() + made.stderr.readAll().toString();
		final code = made.exitCode();
		made.close();

		if (code != 0) {
			ok("rescomp runs on the fixture sounds", false, "it exited " + code + "
" + said);
			return;
		}

		final symbols = Assembly.read(File.getContent(scratch + "/sounds.s"));
		final drift = new Array<String>();

		for (each in fixtures) {
			if (symbols.get(each.name) == null) {
				ok(each.name + " is in rescomp's output", false, "no data under " + each.name);
				continue;
			}
			final wanted = numbers(symbols, each.name);

			var held:{bytes:Array<Int>, count:Int} = null;
			try {
				held = hxres.Sounds.made(each);
			} catch (e:Dynamic) {
				ok(each.name + " converts", false, Std.string(e));
				continue;
			}

			final ours = held.bytes;

			if (!each.exact) {
				drift.push(each.name + " " + apart(ours, wanted, held.count));
				continue;
			}

			if (ours.length != wanted.length) {
				ok(each.name + " is the size rescomp makes it", false,
					"rescomp gives " + wanted.length + " bytes, this gives " + ours.length);
				continue;
			}

			var first:Int = -1;
			for (i in 0...wanted.length) {
				if (ours[i] != wanted[i]) {
					first = i;
					break;
				}
			}

			ok(each.name + " matches rescomp byte for byte", first < 0,
				"byte " + first + " is " + hex(ours[first]) + " where rescomp has "
				+ hex(wanted[first]));
		}

		if (drift.length > 0)
			Sys.println("  resampled, which is ours, against rescomp's: " + drift.join(", "));

		resampler();
	}

	static function resampler():Void {
		final flat = hxres.Sounds.constant(16000, 200, 12000);
		final held = new hxres.Wave(flat).resampled(8000);
		var level:Bool = held.length > 0;
		for (value in held) if (Math.abs(value - held[0]) > 1e-9) level = false;
		ok("a constant resamples to that constant", level,
			"it came back with " + held.length + " frames that are not all one value");

		final source = hxres.Sounds.ramp(8000, 100);
		final wave = new hxres.Wave(source);

		ok("the same rate is not resampled at all", wave.resampled(8000).length == 100,
			"100 frames became " + wave.resampled(8000).length);

		final doubled = wave.resampled(16000);
		ok("doubling gives twice the frames", doubled.length == 200,
			"100 frames became " + doubled.length);

		var apart:Float = 0;
		for (index in 0...100) {
			final gap = Math.abs(doubled[index * 2] - wave.frames[index]);
			if (gap > apart) apart = gap;
		}
		ok("doubling leaves every source frame where it was", apart < 1e-9,
			"the worst moved by " + apart);

		final halved = wave.resampled(4000);
		ok("halving gives half the frames", halved.length == 50,
			"100 frames became " + halved.length);

		apart = 0;
		for (index in 0...50) {
			final mean = (wave.frames[index * 2] + wave.frames[(index * 2) + 1]) / 2;
			final gap = Math.abs(halved[index] - mean);
			if (gap > apart) apart = gap;
		}
		ok("halving averages each pair of source frames", apart < 1e-9,
			"the worst is out by " + apart);

		final third = wave.resampled(24000);
		ok("a rate that is not a whole factor still counts right", third.length == 300,
			"100 frames became " + third.length);
	}

	static function apart(ours:Array<Int>, wanted:Array<Int>, real:Int):String {
		var bestShift:Int = 0;
		var bestWorst:Int = -1;
		var bestMean:Int = -1;

		for (shift in 0...13) {
			final count:Int = real - shift;
			if (count <= 0) continue;

			var worst:Int = 0;
			var total:Int = 0;
			for (i in 0...count) {
				final mine:Int = ours[i] > 127 ? ours[i] - 256 : ours[i];
				final theirs:Int = wanted[i + shift] > 127 ? wanted[i + shift] - 256
					: wanted[i + shift];
				final gap:Int = mine > theirs ? mine - theirs : theirs - mine;
				if (gap > worst) worst = gap;
				total += gap;
			}

			final mean:Int = Std.int((total * 10) / count);
			if (bestMean < 0 || mean < bestMean) {
				bestShift = shift;
				bestWorst = worst;
				bestMean = mean;
			}
		}

		if (bestMean < 0) return real + "b too short to line up";

		return real + "b, " + bestShift + " frames behind: worst " + bestWorst
			+ " mean " + (bestMean / 10);
	}

	static function tunes(root:String, scratch:String):Void {
		final tool = root + "/vendor/SGDK/bin/xgmtool.exe";

		if (!FileSystem.exists(tool)) {
			Sys.println("  xgmtool comparison skipped: " + tool + " is not there");
			return;
		}

		for (each in hxres.music.Corpus.all()) {
			final stem = scratch + "/" + StringTools.replace(each.name, " ", "_");
			File.saveBytes(stem + ".vgm", each.data);

			var tune:hxres.music.Vgm = null;
			try {
				tune = new hxres.music.Vgm(each.data, 0);
				tune.convertWaits();
				tune.cleanCommands();
				tune.cleanSamples();
				tune.fixKeyCommands();
			} catch (e:Dynamic) {
				ok(each.name + " reads", false, Std.string(e));
				continue;
			}

			against(tool, each.name + " as a VGM", stem, ".vgm", tune.bytes());

			var made:hxres.music.Xgm = null;
			try {
				made = new hxres.music.Xgm(tune);
			} catch (e:Dynamic) {
				ok(each.name + " converts to XGM", false, Std.string(e));
				continue;
			}

			against(tool, each.name + " as an XGM", stem, ".xgm", made.bytes());

			var compiled:hxres.music.Xgc = null;
			try {
				compiled = new hxres.music.Xgc(made);
			} catch (e:Dynamic) {
				ok(each.name + " compiles to XGC", false, Std.string(e));
				continue;
			}

			against(tool, each.name + " as an XGC", stem, ".bin", compiled.bytes());
		}
	}

	static function against(tool:String, what:String, stem:String, kind:String,
			ours:haxe.io.Bytes):Void {
		final reference = stem + ".ref" + kind;
		if (FileSystem.exists(reference)) FileSystem.deleteFile(reference);

		final ran = new sys.io.Process(tool, [stem + ".vgm", reference, "-s"]);
		final said = ran.stdout.readAll().toString() + ran.stderr.readAll().toString();
		final code = ran.exitCode();
		ran.close();

		if (code != 0 || !FileSystem.exists(reference)) {
			ok(what + " runs through xgmtool", false, "it exited " + code + "
" + said);
			return;
		}

		final wanted = File.getBytes(reference);

		if (ours.length != wanted.length) {
			ok(what + " is the size xgmtool makes it", false,
				"xgmtool gives " + wanted.length + " bytes, this gives " + ours.length);
			return;
		}

		var first:Int = -1;
		for (i in 0...wanted.length) {
			if (ours.get(i) != wanted.get(i)) {
				first = i;
				break;
			}
		}

		ok(what + " matches xgmtool byte for byte", first < 0,
			"byte " + first + " is " + hex(ours.get(first)) + " where xgmtool has "
			+ hex(wanted.get(first)));
	}

	static function palettes(root:String, scratch:String, jar:String):Void {
		if (FileSystem.exists(scratch)) clear(scratch);
		FileSystem.createDirectory(scratch);

		final fixtures = new Array<Fixture>();
		fixtures.push({name: "blocks", path: root + "/tests/roms/art/gfx/blocks.png", depth: 8, declared: 16});
		fixtures.push({name: "diamond", path: root + "/tests/roms/art/gfx/diamond.png", depth: 8, declared: 16});

		for (declared in [1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 32, 64, 65, 200, 256]) {
			final name = "wide" + declared;
			final path = scratch + "/" + name + ".png";
			File.saveBytes(path, fixture(8, declared));
			fixtures.push({name: name, path: path, depth: 8, declared: declared});
		}

		for (depth in [1, 2, 4]) {
			final size = 1 << depth;
			for (declared in (size > 2 ? [1, 2, size] : [1, 2])) {
				if (declared > size) continue;
				final name = "deep" + depth + "n" + declared;
				final path = scratch + "/" + name + ".png";
				File.saveBytes(path, fixture(depth, declared));
				fixtures.push({name: name, path: path, depth: depth, declared: declared});
			}
		}

		final lines = new Array<String>();
		for (each in fixtures) lines.push('PALETTE ${each.name} "' + full(each.path) + '"');
		File.saveContent(scratch + "/palettes.res", lines.join("\n") + "\n");

		final made = new sys.io.Process("java",
			["-jar", jar, scratch + "/palettes.res", scratch + "/palettes.s"]);
		final said = made.stdout.readAll().toString() + made.stderr.readAll().toString();
		final code = made.exitCode();
		made.close();

		if (code != 0) {
			ok("rescomp runs on the fixture palettes", false, "it exited " + code + "\n" + said);
			return;
		}

		final symbols = Assembly.read(File.getContent(scratch + "/palettes.s"));

		for (each in fixtures) {
			final label = names(symbols, each.name);
			final theirs = label == null ? null : symbols.get(label);
			if (theirs == null) {
				ok(each.name + " is in rescomp's output", false, "no data label under " + each.name);
				continue;
			}

			final wanted = Assembly.words(theirs);
			final ours = capped(Png.read(each.path).entries(MASK), 64);

			if (ours.length != wanted.length) {
				ok(each.name + " has as many entries as rescomp gives it", false,
					"rescomp gives " + wanted.length + ", this gives " + ours.length);
				continue;
			}

			var first = -1;
			for (i in 0...wanted.length) if (ours[i] != wanted[i]) {
				first = i;
				break;
			}

			ok(each.name + " matches rescomp entry for entry", first < 0,
				"entry " + first + " is " + hex(ours[first]) + " where rescomp has " + hex(wanted[first]));
		}
	}

	static function names(symbols:Map<String, Array<Item>>, resource:String):Null<String> {
		final found = references(symbols, resource);
		return found.length > 0 ? found[0] : null;
	}

	static function references(symbols:Map<String, Array<Item>>, resource:String):Array<String> {
		final out = new Array<String>();
		final structure = symbols.get(resource);
		if (structure == null) return out;
		for (item in structure) switch (item) {
			case Reference(name): out.push(name);
			case _:
		}
		return out;
	}

	static function numbers(symbols:Map<String, Array<Item>>, resource:String):Array<Int> {
		final out = new Array<Int>();
		final structure = symbols.get(resource);
		if (structure == null) return out;
		for (item in structure) switch (item) {
			case Number(value, _): out.push(value);
			case _:
		}
		return out;
	}

	static function images(root:String, scratch:String, jar:String):Void {
		final made = new Array<{name:String, path:String}>();

		made.push({name: "blocks", path: full(root + "/tests/roms/art/gfx/blocks.png")});
		for (shape in ["flat", "dupes", "flips", "lines", "priority", "mixed"]) {
			final path = scratch + "/" + shape + ".png";
			File.saveBytes(path, drawing(shape));
			made.push({name: shape, path: full(path)});
		}

		final lines = new Array<String>();
		for (each in made) {
			lines.push('IMAGE i${each.name} "${each.path}"');
			lines.push('TILESET t${each.name} "${each.path}"');
		}
		File.saveContent(scratch + "/images.res", lines.join("\n") + "\n");

		final run = new sys.io.Process("java", ["-jar", jar, scratch + "/images.res", scratch + "/images.s"]);
		final said = run.stdout.readAll().toString() + run.stderr.readAll().toString();
		final code = run.exitCode();
		run.close();

		if (code != 0) {
			ok("rescomp runs on the fixture images", false, "it exited " + code + "\n" + said);
			return;
		}

		final symbols = Assembly.read(File.getContent(scratch + "/images.s"));

		for (each in made) {
			final picture = Png.read(each.path);
			final patterns = Patterns.of(picture, Optimization.Every, Ordering.Row, false);
			final cells = Cells.of(picture, patterns, 0, Optimization.Every, Ordering.Row);

			final parts = references(symbols, "i" + each.name);
			if (parts.length < 3) {
				ok(each.name + " is an image in rescomp's output", false,
					"it names " + parts.length + " parts where three were expected");
				continue;
			}

			final counted = numbers(symbols, parts[1]);
			ok(each.name + " has as many patterns as rescomp finds",
				counted.length > 1 && counted[1] == patterns.count(),
				"rescomp finds " + (counted.length > 1 ? "" + counted[1] : "nothing")
					+ ", this finds " + patterns.count());

			compare(each.name + " patterns", symbols, names(symbols, parts[1]), longs(patterns.data()));
			compare(each.name + " cells", symbols, names(symbols, parts[2]), words(cells.entries));

			final alone = numbers(symbols, "t" + each.name);
			ok(each.name + " is the same set on its own",
				alone.length > 1 && alone[1] == patterns.count(),
				"rescomp finds " + (alone.length > 1 ? "" + alone[1] : "nothing")
					+ ", this finds " + patterns.count());
			compare(each.name + " patterns alone", symbols, names(symbols, "t" + each.name), longs(patterns.data()));

			reaches(each.name, patterns, cells);
		}
	}

	static function reaches(name:String, patterns:Patterns, cells:Cells):Void {
		var flips = 0;
		var lines = 0;
		var priorities = 0;
		for (entry in cells.entries) {
			if ((entry & ((1 << Cells.HORIZONTAL_SHIFT) | (1 << Cells.VERTICAL_SHIFT))) != 0) flips++;
			if (((entry >> Cells.LINE_SHIFT) & 3) != 0) lines++;
			if ((entry & (1 << Cells.PRIORITY_SHIFT)) != 0) priorities++;
		}

		final shared = cells.entries.length - patterns.count();

		switch (name) {
			case "dupes":
				ok("the duplicate fixture reaches deduplication", shared > 0,
					cells.entries.length + " cells against " + patterns.count() + " patterns");
			case "flips":
				ok("the flip fixture reaches flip matching", flips > 0, "no cell carries a flip bit");
			case "lines":
				ok("the palette line fixture reaches more than line zero", lines > 0,
					"every cell names palette line zero");
			case "priority":
				ok("the priority fixture reaches the priority bit", priorities > 0,
					"no cell carries the priority bit");
			case "mixed":
				ok("the mixed fixture reaches all four at once",
					shared > 0 && flips > 0 && lines > 0 && priorities > 0,
					shared + " shared, " + flips + " flipped, " + lines + " off line zero, "
						+ priorities + " with priority");
			case _:
		}
	}

	static function payloads():Array<{name:String, data:Bytes}> {
		final out = new Array<{name:String, data:Bytes}>();

		function add(name:String, length:Int, make:Int->Int):Void {
			final data = Bytes.alloc(length);
			for (i in 0...length) data.set(i, make(i) & 0xFF);
			out.push({name: name, data: data});
		}

		add("zeroes", 512, _ -> 0);
		add("ones", 512, _ -> 1);
		add("counting", 512, i -> i);
		add("alternating", 512, i -> (i & 1) == 0 ? 0 : 0xFF);
		add("shortruns", 512, i -> Std.int(i / 3));
		add("longruns", 4096, i -> Std.int(i / 300));
		add("nearrepeat", 1024, i -> i % 17);
		add("farrepeat", 8192, i -> i % 2000);
		add("random", 2048, i -> (i * 1103515245 + 12345) >> 16);
		add("mostlyzero", 2048, i -> (i % 64) == 0 ? (i % 251) : 0);
		add("tiny", 2, i -> i);
		add("three", 3, i -> 0);
		add("odd", 4095, i -> (i * 7) % 11);

		// isolated two word matches at offsets past the short form's reach, so the parse has to weigh
		// a long match against the literals it displaces rather than winning outright
		final sparse = Bytes.alloc(8192);
		for (i in 0...sparse.length) sparse.set(i, ((i * 2654435) >> 5) & 0xFF);
		var mark = 700;
		while (mark + 4 < Std.int(sparse.length / 2)) {
			for (k in 0...4) sparse.set((mark * 2) + k, sparse.get(((mark - 600) * 2) + k));
			mark += 37;
		}
		out.push({name: "farpairs", data: sparse});

		final lone = Bytes.alloc(6000);
		for (i in 0...lone.length) lone.set(i, ((i * 40503) >> 7) & 0xFF);
		var spot = 900;
		while (spot + 6 < Std.int(lone.length / 2)) {
			for (k in 0...6) lone.set((spot * 2) + k, lone.get(((spot - 400) * 2) + k));
			spot += 11;
		}
		out.push({name: "nearpairs", data: lone});

		final text = "the quick brown fox jumps over the lazy dog. ";
		final many = Bytes.alloc(text.length * 40);
		for (i in 0...many.length) many.set(i, text.charCodeAt(i % text.length));
		out.push({name: "text", data: many});

		return out;
	}

	static function packing(root:String, scratch:String):Void {
		final tool = root + "/vendor/SGDK/bin/apj.jar";
		if (!FileSystem.exists(tool)) {
			ok("apj.jar is present to compare against", false, "no jar at " + tool);
			return;
		}

		for (each in payloads()) {
			final source = scratch + "/pack_" + each.name + ".dat";
			final packed = scratch + "/pack_" + each.name + ".apj";
			File.saveBytes(source, each.data);

			final run = new sys.io.Process("java", ["-jar", tool, "p", source, packed, "-s"]);
			run.stdout.readAll();
			run.stderr.readAll();
			final code = run.exitCode();
			run.close();

			if (code != 0 || !FileSystem.exists(packed)) {
				ok(each.name + " packs with apj.jar", false, "it exited " + code);
				continue;
			}

			final theirs = File.getBytes(packed);
			final ours = Aplib.pack(each.data);

			if (ours.length != theirs.length) {
				ok(each.name + " packs to the same length as apj", false,
					"apj gives " + theirs.length + " bytes, this gives " + ours.length
						+ " for " + each.data.length + " in");
				continue;
			}

			var first = -1;
			for (i in 0...theirs.length) if (theirs.get(i) != ours.get(i)) {
				first = i;
				break;
			}

			ok(each.name + " packs byte for byte as apj does", first < 0,
				"byte " + first + " is 0x" + StringTools.hex(ours.get(first), 2) + " where apj has 0x"
					+ StringTools.hex(theirs.get(first), 2));

			final tally = new Tally();
			var back:Null<Bytes> = null;
			try {
				back = Aplib.unpack(ours, tally);
			} catch (e:haxe.Exception) {
				ok(each.name + " unpacks again", false, e.message);
				continue;
			}

			ok(each.name + " round trips through the unpacker", same(back, each.data),
				back.length == each.data.length
					? "the same length but different bytes"
					: "came back " + back.length + " bytes where it went in " + each.data.length);

			reached.literals += tally.literals;
			reached.zeroes += tally.zeroes;
			reached.tinies += tally.tinies;
			reached.shorts += tally.shorts;
			reached.longs += tally.longs;
			reached.repeats += tally.repeats;
			packedSummary.push(each.name + " " + each.data.length + "->" + ours.length + " " + tally);
		}

		Sys.println("  " + packedSummary.join(", "));
		ok("the corpus reaches a literal", reached.literals > 0, "none emitted");
		ok("the corpus reaches a zero block", reached.zeroes > 0, "none emitted");
		ok("the corpus reaches a tiny match", reached.tinies > 0, "none emitted");
		ok("the corpus reaches a short match", reached.shorts > 0, "none emitted");
		ok("the corpus reaches a long match", reached.longs > 0, "none emitted");
		ok("the corpus reaches a repeated offset", reached.repeats > 0, "none emitted");
	}

	static function wordPacking(root:String, scratch:String):Void {
		final tool = root + "/vendor/SGDK/bin/lz4w.jar";
		if (!FileSystem.exists(tool)) {
			ok("lz4w.jar is present to compare against", false, "no jar at " + tool);
			return;
		}

		final summary = new Array<String>();

		for (each in payloads()) {
			final source = scratch + "/word_" + each.name + ".dat";
			final packed = scratch + "/word_" + each.name + ".lz4w";
			File.saveBytes(source, each.data);
			if (FileSystem.exists(packed)) FileSystem.deleteFile(packed);

			final run = new sys.io.Process("java", ["-jar", tool, "p", source, packed, "-s"]);
			run.stdout.readAll();
			run.stderr.readAll();
			final code = run.exitCode();
			run.close();

			if (code != 0 || !FileSystem.exists(packed)) {
				ok(each.name + " packs with lz4w.jar", false, "it exited " + code);
				continue;
			}

			final theirs = File.getBytes(packed);
			final ours = Lz4w.pack(each.data);

			if (ours.length != theirs.length) {
				ok(each.name + " packs to the same length as lz4w", false,
					"lz4w gives " + theirs.length + " bytes, this gives " + ours.length
						+ " for " + each.data.length + " in");
				continue;
			}

			var first = -1;
			for (i in 0...theirs.length) if (theirs.get(i) != ours.get(i)) {
				first = i;
				break;
			}

			ok(each.name + " packs byte for byte as lz4w does", first < 0,
				"byte " + first + " is 0x" + StringTools.hex(ours.get(first), 2) + " where lz4w has 0x"
					+ StringTools.hex(theirs.get(first), 2));

			summary.push(each.name + " " + each.data.length + "->" + ours.length);
		}

		Sys.println("  " + summary.join(", "));
	}

	static var reached:Tally = new Tally();
	static var packedSummary:Array<String> = [];

	static function same(left:Bytes, right:Bytes):Bool {
		if (left.length != right.length) return false;
		for (i in 0...left.length) if (left.get(i) != right.get(i)) return false;
		return true;
	}

	static function binaries(root:String, scratch:String, jar:String):Void {
		final sizes = [1, 2, 3, 15, 16, 17, 100, 255, 256];
		final shapes = [
			{align: 2, sizeAlign: 2, fill: 0},
			{align: 2, sizeAlign: 16, fill: 0xAA},
			{align: 4, sizeAlign: 4, fill: 0xFF},
			{align: 256, sizeAlign: 256, fill: 0},
			{align: 2, sizeAlign: 0, fill: 0}
		];

		final made = new Array<{name:String, path:String, align:Int, sizeAlign:Int, fill:Int}>();
		final lines = new Array<String>();

		for (size in sizes) {
			final path = scratch + "/blob" + size + ".dat";
			final blob = Bytes.alloc(size);
			for (i in 0...size) blob.set(i, (i * 7) & 0xFF);
			File.saveBytes(path, blob);

			for (at in 0...shapes.length) {
				final shape = shapes[at];
				final name = "b" + size + "x" + at;
				made.push({name: name, path: path, align: shape.align, sizeAlign: shape.sizeAlign,
					fill: shape.fill});
				lines.push('BIN ${name} "' + full(path) + '" ${shape.align} ${shape.sizeAlign} '
					+ '${shape.fill} NONE TRUE');
			}
		}

		File.saveContent(scratch + "/binaries.res", lines.join("\n") + "\n");

		final run = new sys.io.Process("java", ["-jar", jar, scratch + "/binaries.res", scratch + "/binaries.s"]);
		final said = run.stdout.readAll().toString() + run.stderr.readAll().toString();
		final code = run.exitCode();
		run.close();

		if (code != 0) {
			ok("rescomp runs on the fixture data", false, "it exited " + code + "\n" + said);
			return;
		}

		final symbols = Assembly.read(File.getContent(scratch + "/binaries.s"));

		for (each in made) {
			final theirs = symbols.get(each.name);
			if (theirs == null) {
				ok(each.name + " is in rescomp's output", false, "no label named " + each.name);
				continue;
			}
			compare(each.name, symbols, each.name,
				Emitter.evened(Emitter.sized(File.getBytes(each.path), each.sizeAlign, each.fill)));
		}
	}

	static function cuts(root:String, scratch:String, jar:String):Void {
		final made = new Array<{name:String, path:String, across:Int, down:Int}>();
		made.push({name: "diamond", path: full(root + "/tests/roms/art/gfx/diamond.png"), across: 2, down: 2});

		for (shape in ["blob", "ring", "cross", "corners", "sparse", "tall", "wideframes", "twoanims",
				"bigblob", "bigring", "bigcross", "diagonal", "scatter", "hook", "samemask"]) {
			final path = scratch + "/" + shape + ".png";
			final made2 = frame(shape);
			File.saveBytes(path, made2.bytes);
			made.push({name: shape, path: full(path), across: made2.across, down: made2.down});
		}

		final lines = new Array<String>();
		for (each in made) lines.push('SPRITE s${each.name} "${each.path}" ${each.across} ${each.down} NONE 0');
		File.saveContent(scratch + "/sprites.res", lines.join("\n") + "\n");

		final run = new sys.io.Process("java", ["-jar", jar, scratch + "/sprites.res", scratch + "/sprites.s"]);
		final said = run.stdout.readAll().toString() + run.stderr.readAll().toString();
		final code = run.exitCode();
		run.close();

		if (code != 0) {
			ok("rescomp runs on the fixture sprites", false, "it exited " + code + "\n" + said);
			return;
		}

		final symbols = Assembly.read(File.getContent(scratch + "/sprites.s"));
		final cuts = new Array<hxres.Frames.Cut>();

		for (each in made) {
			final picture = Png.read(each.path);
			var frames:Null<Frames> = null;
			try {
				frames = new Frames(picture, each.across, each.down, 0, Aim.Balanced, cuts);
			} catch (e:haxe.Exception) {
				ok(each.name + " can be cut", false, e.message);
				continue;
			}

			final head = numbers(symbols, "s" + each.name);
			final refs = references(symbols, "s" + each.name);

			if (head.length < 5 || refs.length < 2) {
				ok(each.name + " is a sprite in rescomp's output", false, "its structure does not read");
				continue;
			}

			ok(each.name + " is the size rescomp gives it",
				head[0] == frames.across * 8 && head[1] == frames.down * 8,
				"rescomp says " + head[0] + " by " + head[1] + ", this says "
					+ (frames.across * 8) + " by " + (frames.down * 8));

			ok(each.name + " has as many animations as rescomp finds", head[2] == frames.animations.length,
				"rescomp finds " + head[2] + ", this finds " + frames.animations.length);

			ok(each.name + " needs as many patterns as rescomp at most", head[3] == frames.mostPatterns(),
				"rescomp needs " + head[3] + ", this needs " + frames.mostPatterns());

			ok(each.name + " needs as many hardware sprites as rescomp at most", head[4] == frames.mostPieces(),
				"rescomp needs " + head[4] + ", this needs " + frames.mostPieces());

			animations(each.name, symbols, refs[1], frames);

			cutSummary.push(each.name + " " + frames.animations.length + "a " + countFrames(frames) + "f "
				+ frames.mostPieces() + "s " + frames.mostPatterns() + "p");
			if (frames.mostPieces() > 1) manySprites++;
			if (countFrames(frames) > 1) manyFrames++;
			if (frames.animations.length > 1) manyAnimations++;
		}

		Sys.println("  " + cutSummary.join(", "));
		ok("a fixture frame needs more than one hardware sprite", manySprites > 0,
			"every fixture was cut into a single sprite, so no merge was ever tried");
		ok("a fixture animation has more than one frame", manyFrames > 0, "every fixture is one frame");
		ok("a fixture has more than one animation", manyAnimations > 0, "every fixture is one animation");
	}

	static var cutSummary:Array<String> = [];
	static var manySprites:Int = 0;
	static var manyFrames:Int = 0;
	static var manyAnimations:Int = 0;

	static function countFrames(frames:Frames):Int {
		var total = 0;
		for (animation in frames.animations) total += animation.frames.length;
		return total;
	}

	static function animations(name:String, symbols:Map<String, Array<Item>>, list:String, frames:Frames):Void {
		final named = references(symbols, list);
		if (named.length != frames.animations.length) {
			ok(name + " lists as many animations as rescomp", false,
				"rescomp lists " + named.length + ", this lists " + frames.animations.length);
			return;
		}

		for (index in 0...named.length) {
			final animation = frames.animations[index];
			final head = numbers(symbols, named[index]);
			final refs = references(symbols, named[index]);
			if (head.length < 1 || refs.length < 1) {
				ok(name + " animation " + index + " reads", false, "its structure does not read");
				continue;
			}

			ok(name + " animation " + index + " has as many frames as rescomp",
				head[0] == (animation.frames.length << 8) | animation.loop,
				"rescomp says " + head[0] + ", this says " + ((animation.frames.length << 8) | animation.loop));

			final held = references(symbols, refs[0]);
			if (held.length != animation.frames.length) {
				ok(name + " animation " + index + " lists as many frames as rescomp", false,
					"rescomp lists " + held.length + ", this lists " + animation.frames.length);
				continue;
			}

			for (at in 0...held.length) {
				final frame = animation.frames[at];
				final theirs = symbols.get(held[at]);
				if (theirs == null) {
					ok(name + " frame " + index + "." + at + " reads", false, "no label named " + held[at]);
					continue;
				}

				final ours = frameWords(frame);
				final wanted = frameWordsOf(theirs);

				ok(name + " frame " + index + "." + at + " is cut as rescomp cuts it",
					sameWords(ours, wanted),
					"rescomp gives " + wanted.map(v -> "" + v).join(" ") + ", this gives "
						+ ours.map(v -> "" + v).join(" "));

				final data = references(symbols, held[at]);
				if (data.length > 0) {
					final tiles = references(symbols, data[0]);
					if (tiles.length > 0)
						compare(name + " frame " + index + "." + at + " patterns", symbols, tiles[0],
							longs(frame.patterns.data()));
				}
			}
		}
	}

	static function frameWords(frame:Frame):Array<Int> {
		final out = [((frame.leading() << 8) & 0xFF00) | (frame.timer & 0xFF)];
		for (piece in frame.pieces) {
			final bytes = piece.bytes();
			out.push((bytes[0] << 8) | bytes[1]);
			out.push((bytes[2] << 8) | bytes[3]);
			out.push((bytes[4] << 8) | (bytes[5] & 0xFF));
		}
		return out;
	}

	static function frameWordsOf(items:Array<Item>):Array<Int> {
		final out = new Array<Int>();
		for (item in items) switch (item) {
			case Number(value, 2): out.push(value & 0xFFFF);
			case _:
		}
		return out;
	}

	static function sameWords(left:Array<Int>, right:Array<Int>):Bool {
		if (left.length != right.length) return false;
		for (i in 0...left.length) if (left[i] != right[i]) return false;
		return true;
	}

	static function compare(what:String, symbols:Map<String, Array<Item>>, label:Null<String>, ours:Bytes):Void {
		final theirs = label == null ? null : symbols.get(label);
		if (theirs == null) {
			ok(what + " is in rescomp's output", false, "no data label to read");
			return;
		}

		final wanted = Assembly.bytes(theirs);
		if (wanted.length != ours.length) {
			ok(what + " is as long as rescomp's", false,
				"rescomp writes " + wanted.length + " bytes, this writes " + ours.length);
			return;
		}

		var first = -1;
		for (i in 0...wanted.length) if (wanted.get(i) != ours.get(i)) {
			first = i;
			break;
		}

		ok(what + " matches rescomp byte for byte", first < 0,
			"byte " + first + " is 0x" + StringTools.hex(ours.get(first), 2) + " where rescomp has 0x"
				+ StringTools.hex(wanted.get(first), 2));
	}

	static function longs(values:Array<Int>):Bytes {
		final out = Bytes.alloc(values.length * 4);
		for (i in 0...values.length) writeInt(out, i * 4, values[i]);
		return out;
	}

	static function words(values:Array<Int>):Bytes {
		final out = Bytes.alloc(values.length * 2);
		for (i in 0...values.length) {
			out.set(i * 2, (values[i] >> 8) & 0xFF);
			out.set(i * 2 + 1, values[i] & 0xFF);
		}
		return out;
	}

	static function drawing(shape:String):Bytes {
		final across = 4;
		final down = 4;
		final width = across * 8;
		final height = down * 8;
		final pixels = Bytes.alloc(width * height);

		for (j in 0...down) {
			for (i in 0...across) {
				final cell = (j * across) + i;
				var source = cell;
				var flip = 0;
				var line = 0;
				var priority = false;

				switch (shape) {
					case "flat":
					case "dupes": source = cell % 5;
					case "flips":
						source = Std.int(cell / 4);
						flip = cell % 4;
					case "lines":
						source = cell % 6;
						line = Std.int(cell / 4) & 3;
					case "priority":
						source = cell % 6;
						priority = (cell & 1) != 0;
					case _:
						source = cell % 7;
						flip = cell % 4;
						line = Std.int(cell / 5) & 3;
						priority = (cell % 3) == 0;
				}

				for (y in 0...8) {
					for (x in 0...8) {
						final readX = (flip == 1 || flip == 3) ? 7 - x : x;
						final readY = (flip == 2 || flip == 3) ? 7 - y : y;
						final color = glyph(source, readX, readY);
						final value = color | (line << 4) | (priority ? 0x80 : 0);
						pixels.set(((j * 8) + y) * width + (i * 8) + x, value);
					}
				}
			}
		}

		final palette = Bytes.alloc(256 * 3);
		for (i in 0...256) {
			palette.set(i * 3, (i * 7) & 0xFF);
			palette.set(i * 3 + 1, (i * 13) & 0xFF);
			palette.set(i * 3 + 2, (i * 29) & 0xFF);
		}

		final rows = new BytesBuffer();
		for (y in 0...height) {
			rows.addByte(0);
			rows.addBytes(pixels, y * width, width);
		}

		final header = Bytes.alloc(13);
		writeInt(header, 0, width);
		writeInt(header, 4, height);
		header.set(8, 8);
		header.set(9, 3);

		final out = new BytesBuffer();
		for (b in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) out.addByte(b);
		chunk(out, "IHDR", header);
		chunk(out, "PLTE", palette);
		chunk(out, "IDAT", haxe.zip.Compress.run(rows.getBytes(), 9));
		chunk(out, "IEND", Bytes.alloc(0));
		return out.getBytes();
	}

	static function frame(shape:String):{bytes:Bytes, across:Int, down:Int} {
		final big = StringTools.startsWith(shape, "big") || shape == "diagonal" || shape == "scatter"
			|| shape == "hook" || shape == "samemask";
		final across = switch (shape) {
			case "tall": 2;
			case _: big ? 8 : 4;
		}
		final down = switch (shape) {
			case "tall": 4;
			case _: big ? 8 : 3;
		}
		final columns = switch (shape) {
			case "wideframes": 3;
			case "twoanims": 2;
			case "samemask": 4;
			case _: 1;
		}
		final rows = shape == "twoanims" ? 2 : 1;

		final width = across * columns * 8;
		final height = down * rows * 8;
		final pixels = Bytes.alloc(width * height);

		for (y in 0...height) {
			for (x in 0...width) {
				final inX = x % (across * 8);
				final inY = y % (down * 8);
				final frameX = Std.int(x / (across * 8));
				final frameY = Std.int(y / (down * 8));
				pixels.set((y * width) + x, ink(shape, inX, inY, across * 8, down * 8, frameX + frameY));
			}
		}

		final palette = Bytes.alloc(16 * 3);
		for (i in 0...16) {
			palette.set(i * 3, (i * 17) & 0xFF);
			palette.set(i * 3 + 1, (0x40 + i * 11) & 0xFF);
			palette.set(i * 3 + 2, (0xC0 - i * 7) & 0xFF);
		}

		final rowBytes = new BytesBuffer();
		for (y in 0...height) {
			rowBytes.addByte(0);
			rowBytes.addBytes(pixels, y * width, width);
		}

		final header = Bytes.alloc(13);
		writeInt(header, 0, width);
		writeInt(header, 4, height);
		header.set(8, 8);
		header.set(9, 3);

		final out = new BytesBuffer();
		for (b in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) out.addByte(b);
		chunk(out, "IHDR", header);
		chunk(out, "PLTE", palette);
		chunk(out, "IDAT", haxe.zip.Compress.run(rowBytes.getBytes(), 9));
		chunk(out, "IEND", Bytes.alloc(0));
		return {bytes: out.getBytes(), across: across, down: down};
	}

	static function ink(shape:String, x:Int, y:Int, width:Int, height:Int, index:Int):Int {
		final midX = width / 2;
		final midY = height / 2;
		final dx = x - midX;
		final dy = y - midY;
		final radius = Math.sqrt((dx * dx) + (dy * dy));

		return switch (shape) {
			case "blob": radius < midX * 0.8 ? 1 + (index % 14) : 0;
			case "ring": (radius < midX * 0.9 && radius > midX * 0.5) ? 2 + (index % 13) : 0;
			case "cross":
				((x >= midX - 4 && x < midX + 4) || (y >= midY - 4 && y < midY + 4)) ? 3 + (index % 12) : 0;
			case "corners":
				((x < 8 || x >= width - 8) && (y < 8 || y >= height - 8)) ? 4 + (index % 11) : 0;
			case "sparse": ((x >> 3) + (y >> 3) + index) % 3 == 0 ? 5 + (index % 10) : 0;
			case "tall": (x >= 4 && x < width - 4 && y >= 2) ? 6 + (index % 9) : 0;
			case "wideframes": radius < midY * (0.5 + (index * 0.2)) ? 1 + (index % 14) : 0;
			case "bigblob": radius < midX * 0.95 ? 1 + (index % 14) : 0;
			case "bigring": (radius < midX * 0.95 && radius > midX * 0.45) ? 2 + (index % 13) : 0;
			case "bigcross":
				((x >= midX - 12 && x < midX + 12) || (y >= midY - 12 && y < midY + 12)) ? 3 + (index % 12) : 0;
			case "diagonal": (x - y < 10 && y - x < 10) ? 4 + (index % 11) : 0;
			case "scatter": (((x >> 3) * 5 + (y >> 3) * 3 + index) % 4) == 0 ? 5 + (index % 10) : 0;
			case "hook": ((x < 16) || (y >= height - 16 && x < width - 8)) ? 6 + (index % 9) : 0;
			case "samemask": (radius < midX * 0.85 && radius > midX * 0.3) ? 1 + ((x + y + index) % 14) : 0;
			case _: (radius < midY * 0.9 && ((x + y + index) & 7) != 0) ? 2 + (index % 13) : 0;
		}
	}

	static function glyph(source:Int, x:Int, y:Int):Int {
		return switch (source % 8) {
			case 0: 0;
			case 1: (x + y) & 0xF == 0 ? 0 : ((x * 2 + y) % 15) + 1;
			case 2: x < 4 ? 0 : ((y % 7) + 1);
			case 3: y < 3 ? ((x % 5) + 1) : 0;
			case 4: (x == y) ? 0xF : ((x + 1) % 8);
			case 5: ((x * y) % 13) + 1;
			case 6: (y > x) ? ((x % 6) + 2) : 0;
			case _: ((x ^ y) % 16);
		}
	}

	static function capped(entries:Array<Int>, most:Int):Array<Int> {
		final limit = (most + 15) & 0xF0;
		return entries.length > limit ? entries.slice(0, limit) : entries;
	}

	static function fixture(depth:Int, declared:Int):Bytes {
		final side = 8;
		final palette = Bytes.alloc(declared * 3);
		for (i in 0...declared) {
			palette.set(i * 3, (i * 17) & 0xFF);
			palette.set(i * 3 + 1, (0x50 + i * 3) & 0xFF);
			palette.set(i * 3 + 2, (0xA0 - i * 5) & 0xFF);
		}
		if (declared > 1) {
			palette.set((declared - 1) * 3, 0xF0);
			palette.set((declared - 1) * 3 + 1, 0x50);
			palette.set((declared - 1) * 3 + 2, 0xA0);
		}

		final stride = Std.int(((side * depth) + 7) / 8);
		final rows = new BytesBuffer();
		for (y in 0...side) {
			rows.addByte(0);
			final line = Bytes.alloc(stride);
			for (x in 0...side) {
				final value = (x + y) % declared;
				final bit = x * depth;
				final shift = 8 - depth - (bit & 7);
				line.set(bit >> 3, line.get(bit >> 3) | (value << shift));
			}
			rows.addBytes(line, 0, stride);
		}

		final header = Bytes.alloc(13);
		writeInt(header, 0, side);
		writeInt(header, 4, side);
		header.set(8, depth);
		header.set(9, 3);

		final out = new BytesBuffer();
		for (b in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) out.addByte(b);
		chunk(out, "IHDR", header);
		chunk(out, "PLTE", palette);
		chunk(out, "IDAT", haxe.zip.Compress.run(rows.getBytes(), 9));
		chunk(out, "IEND", Bytes.alloc(0));
		return out.getBytes();
	}

	static function chunk(into:BytesBuffer, tag:String, body:Bytes):Void {
		final length = Bytes.alloc(4);
		writeInt(length, 0, body.length);
		into.addBytes(length, 0, 4);

		final whole = Bytes.alloc(4 + body.length);
		whole.blit(0, Bytes.ofString(tag), 0, 4);
		whole.blit(4, body, 0, body.length);
		into.addBytes(whole, 0, whole.length);

		final crc = Bytes.alloc(4);
		writeInt(crc, 0, haxe.crypto.Crc32.make(whole));
		into.addBytes(crc, 0, 4);
	}

	static function writeInt(into:Bytes, at:Int, value:Int):Void {
		into.set(at, (value >> 24) & 0xFF);
		into.set(at + 1, (value >> 16) & 0xFF);
		into.set(at + 2, (value >> 8) & 0xFF);
		into.set(at + 3, value & 0xFF);
	}

	static function clear(path:String):Void {
		for (entry in FileSystem.readDirectory(path)) {
			final full = path + "/" + entry;
			if (FileSystem.isDirectory(full)) clear(full) else FileSystem.deleteFile(full);
		}
		FileSystem.deleteDirectory(path);
	}

	static function full(path:String):String {
		return StringTools.replace(FileSystem.absolutePath(path), "\\", "/");
	}

	static function hex(value:Int):String {
		return "0x" + StringTools.hex(value, 4);
	}
}
#end

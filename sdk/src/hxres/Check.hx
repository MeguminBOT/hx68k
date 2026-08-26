package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import sys.FileSystem;
import sys.io.File;
import hxres.Assembly.Item;
import hxres.Patterns.Optimisation;
import hxres.Patterns.Ordering;

typedef Fixture = {
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
		final blocks = Png.read(root + "/samples/art/gfx/blocks.png");
		ok("blocks.png is 32 by 32", blocks.width == 32 && blocks.height == 32,
			"got " + blocks.width + " by " + blocks.height);
		ok("blocks.png is eight bits indexed", blocks.bits == 8 && blocks.indexed(), "got " + blocks.bits + " bits");
		ok("blocks.png declares sixteen colours", blocks.declared == 16, "got " + blocks.declared);
		ok("blocks.png expands to two hundred and fifty six", blocks.palette.length == 256,
			"got " + blocks.palette.length);

		final entries = blocks.entries(MASK);
		ok("the first colour is black", entries[0] == 0x0000, hex(entries[0]));
		ok("the sixteenth colour is the brightest", entries[15] == 0x0CCE, hex(entries[15]));
		ok("a colour past the palette repeats the last", entries[16] == 0x0CCE, hex(entries[16]));

		final diamond = Png.read(root + "/samples/art/gfx/diamond.png");
		ok("diamond.png is 16 by 16", diamond.width == 16 && diamond.height == 16,
			"got " + diamond.width + " by " + diamond.height);

		var indexes = 0;
		for (i in 0...blocks.indexes.length) if (blocks.indexes.get(i) > indexes) indexes = blocks.indexes.get(i);
		ok("no pixel names a colour the palette does not declare", indexes < blocks.declared,
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

	static function palettes(root:String, scratch:String, jar:String):Void {
		if (FileSystem.exists(scratch)) clear(scratch);
		FileSystem.createDirectory(scratch);

		final fixtures = new Array<Fixture>();
		fixtures.push({name: "blocks", path: root + "/samples/art/gfx/blocks.png", depth: 8, declared: 16});
		fixtures.push({name: "diamond", path: root + "/samples/art/gfx/diamond.png", depth: 8, declared: 16});

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

		made.push({name: "blocks", path: full(root + "/samples/art/gfx/blocks.png")});
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
			final patterns = Patterns.of(picture, Optimisation.Every, Ordering.Row, false);
			final cells = Cells.of(picture, patterns, 0, Optimisation.Every, Ordering.Row);

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
						final colour = glyph(source, readX, readY);
						final value = colour | (line << 4) | (priority ? 0x80 : 0);
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

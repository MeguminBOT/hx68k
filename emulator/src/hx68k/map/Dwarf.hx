package hx68k.map;

typedef DwarfRow = {
	final address:Int;
	final file:String;
	final line:Int;
	final isStatement:Bool;
	final endSequence:Bool;
}

class Dwarf {
	public final rows:Array<DwarfRow> = [];
	public final byFile:Map<String, Array<DwarfRow>> = [];

	public function new(elf:Elf) {
		final section = elf.section(".debug_line");
		if (section == null) throw "the ELF carries no .debug_line: build with -g";

		final reader = new Reader(elf.bytes, section.offset);
		final end = section.offset + section.size;
		while (reader.position < end) unit(reader);

		rows.sort((a, b) -> a.address == b.address ? (a.endSequence ? -1 : 1) : (a.address < b.address ? -1 : 1));

		for (row in rows) {
			final name = haxe.io.Path.withoutDirectory(row.file);
			var group = byFile.get(name);
			if (group == null) {
				group = [];
				byFile.set(name, group);
			}
			group.push(row);
		}
	}

	function unit(reader:Reader):Void {
		final length = reader.u32();
		final unitEnd = reader.position + length;
		final version = reader.u16();
		if (version < 2 || version > 4) {
			reader.position = unitEnd;
			return;
		}

		final headerLength = reader.u32();
		final programStart = reader.position + headerLength;
		final minimumInstruction = reader.u8();
		if (version >= 4) reader.u8();
		final defaultIsStatement = reader.u8() != 0;
		final lineBase = reader.s8();
		final lineRange = reader.u8();
		final opcodeBase = reader.u8();

		final standardLengths = [];
		for (i in 1...opcodeBase) standardLengths.push(reader.u8());

		final directories = [""];
		while (true) {
			final name = reader.string();
			if (name.length == 0) break;
			directories.push(name);
		}

		final files = [""];
		while (true) {
			final name = reader.string();
			if (name.length == 0) break;
			final directory = reader.uleb();
			reader.uleb();
			reader.uleb();
			files.push(directory == 0 ? name : directories[directory] + "/" + name);
		}

		reader.position = programStart;
		run(reader, unitEnd, files, minimumInstruction, defaultIsStatement, lineBase, lineRange,
			opcodeBase, standardLengths);
	}

	function run(reader:Reader, unitEnd:Int, files:Array<String>, minimumInstruction:Int,
			defaultIsStatement:Bool, lineBase:Int, lineRange:Int, opcodeBase:Int,
			standardLengths:Array<Int>):Void {
		var address = 0;
		var file = 1;
		var line = 1;
		var isStatement = defaultIsStatement;

		inline function emit(endSequence:Bool):Void {
			rows.push({
				address: address,
				file: file < files.length ? files[file] : "",
				line: line,
				isStatement: isStatement,
				endSequence: endSequence
			});
		}

		while (reader.position < unitEnd) {
			final opcode = reader.u8();

			if (opcode >= opcodeBase) {
				final adjusted = opcode - opcodeBase;
				address += Std.int(adjusted / lineRange) * minimumInstruction;
				line += lineBase + adjusted % lineRange;
				emit(false);
				continue;
			}

			switch (opcode) {
				case 0:
					final length = reader.uleb();
					final next = reader.position + length;
					switch (reader.u8()) {
						case 1:
							emit(true);
							address = 0;
							file = 1;
							line = 1;
							isStatement = defaultIsStatement;
						case 2: address = reader.u32();
						case _:
					}
					reader.position = next;
				case 1: emit(false);
				case 2: address += reader.uleb() * minimumInstruction;
				case 3: line += reader.sleb();
				case 4: file = reader.uleb();
				case 5: reader.uleb();
				case 6: isStatement = !isStatement;
				case 7:
				case 8: address += Std.int((255 - opcodeBase) / lineRange) * minimumInstruction;
				case 9: address += reader.u16();
				case 10:
				case 11:
				case 12: reader.uleb();
				case _:
					for (i in 0...standardLengths[opcode - 1]) reader.uleb();
			}
		}
	}

	public function firstAddress(file:String, line:Int):Null<Int> {
		final group = byFile.get(file);
		if (group == null) return null;

		var best:Null<DwarfRow> = null;
		for (row in group) {
			if (row.endSequence || row.line != line) continue;
			if (best == null || row.address < best.address) best = row;
		}
		return best == null ? null : best.address;
	}

	public function at(file:String, address:Int, floor:Int):Null<DwarfRow> {
		final group = byFile.get(file);
		if (group == null) return null;

		var best:Null<DwarfRow> = null;
		for (row in group) {
			if (row.address > address || row.address < floor) continue;
			if (best == null || row.address >= best.address) best = row;
		}
		return best == null || best.endSequence ? null : best;
	}
}

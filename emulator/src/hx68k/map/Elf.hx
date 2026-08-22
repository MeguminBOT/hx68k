package hx68k.map;

import haxe.io.Bytes;

typedef Section = {
	final name:String;
	final offset:Int;
	final size:Int;
	final link:Int;
	final entrySize:Int;
}

typedef Symbol = {
	final name:String;
	final address:Int;
	final size:Int;
	final kind:Int;
}

class Elf {
	public static inline final FUNCTION = 2;
	public static inline final OBJECT = 1;

	public final bytes:Bytes;
	public final symbols:Array<Symbol> = [];

	final table:Array<Section> = [];
	final byName:Map<String, Int> = [];
	final addresses:Map<String, Int> = [];

	public function new(path:String) {
		bytes = sys.io.File.getBytes(path);
		if (bytes.length < 52 || bytes.get(0) != 0x7F || bytes.getString(1, 3) != "ELF")
			throw path + " is not an ELF file";
		if (bytes.get(4) != 1 || bytes.get(5) != 2)
			throw path + " is not a big-endian 32-bit ELF";

		final head = new Reader(bytes, 32);
		final start = head.u32();
		head.position = 46;
		final entrySize = head.u16();
		final count = head.u16();
		final nameIndex = head.u16();
		final nameHeader = new Reader(bytes, start + nameIndex * entrySize + 16);
		final names = nameHeader.u32();

		for (i in 0...count) {
			final reader = new Reader(bytes, start + i * entrySize);
			final name = reader.u32();
			reader.position += 12;
			final offset = reader.u32();
			final size = reader.u32();
			final link = reader.u32();
			reader.position += 8;
			final entry = reader.u32();
			final section:Section = {
				name: new Reader(bytes, names + name).string(),
				offset: offset,
				size: size,
				link: link,
				entrySize: entry
			};
			byName.set(section.name, table.length);
			table.push(section);
		}

		readSymbols();
	}

	public function section(name:String):Null<Section> {
		final index = byName.get(name);
		return index == null ? null : table[index];
	}

	public function addressOf(symbol:String):Null<Int> {
		return addresses.get(symbol);
	}

	public function functionAt(address:Int):Null<Symbol> {
		var best:Null<Symbol> = null;
		for (symbol in symbols) {
			if (symbol.kind != FUNCTION || symbol.address > address) continue;
			if (symbol.size > 0 && address >= symbol.address + symbol.size) continue;
			if (best == null || symbol.address > best.address) best = symbol;
		}
		return best;
	}

	function readSymbols():Void {
		final symtab = section(".symtab");
		if (symtab == null || symtab.entrySize == 0) return;
		final strings = table[symtab.link].offset;

		final count = Std.int(symtab.size / symtab.entrySize);
		for (i in 0...count) {
			final reader = new Reader(bytes, symtab.offset + i * symtab.entrySize);
			final name = reader.u32();
			final value = reader.u32();
			final size = reader.u32();
			final info = reader.u8();
			if (name == 0) continue;

			final symbol:Symbol = {
				name: new Reader(bytes, strings + name).string(),
				address: value,
				size: size,
				kind: info & 0x0F
			};
			symbols.push(symbol);
			if (!addresses.exists(symbol.name)) addresses.set(symbol.name, symbol.address);
		}
	}
}

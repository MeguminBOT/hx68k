package hx68k.map;

enum abstract Where(Int) from Int to Int {
	var Nowhere = 0;
	var InRegister = 1;
	var AtFrameOffset = 2;
	var AtRegisterOffset = 3;
	var AtAddress = 4;
	var InList = 5;
	var TheCallFrameAddress = 6;

	public function toString():String {
		return switch (cast this : Where) {
			case Nowhere: "nowhere";
			case InRegister: "in a register";
			case AtFrameOffset: "at a frame offset";
			case AtRegisterOffset: "at a register offset";
			case AtAddress: "at an address";
			case InList: "in a location list";
			case TheCallFrameAddress: "the call frame address";
		}
	}
}

typedef Location = {
	final where:Where;
	final register:Int;
	final value:Int;
}

typedef Variable = {
	final name:String;
	final owner:String;
	final parameter:Bool;
	final location:Location;
}

typedef Subprogram = {
	final name:String;
	final low:Int;
	final high:Int;
	final frameBase:Location;
	final variables:Array<Variable>;
}

private typedef Attribute = {
	final at:Int;
	final form:Int;
	final constant:Int;
}

private typedef Abbreviation = {
	final tag:Int;
	final children:Bool;
	final attributes:Array<Attribute>;
}

class Variables {
	static inline final TAG_FORMAL_PARAMETER = 0x05;
	static inline final TAG_LEXICAL_BLOCK = 0x0B;
	static inline final TAG_SUBPROGRAM = 0x2E;
	static inline final TAG_VARIABLE = 0x34;

	static inline final AT_LOCATION = 0x02;
	static inline final AT_NAME = 0x03;
	static inline final AT_LOW_PC = 0x11;
	static inline final AT_HIGH_PC = 0x12;
	static inline final AT_FRAME_BASE = 0x40;

	static inline final FORM_ADDR = 0x01;

	public final subprograms:Array<Subprogram> = [];

	final elf:Elf;
	final strings:Null<Elf.Section>;
	final abbreviations:Map<Int, Map<Int, Abbreviation>> = [];

	public function new(elf:Elf) {
		this.elf = elf;
		this.strings = elf.section(".debug_str");

		final info = elf.section(".debug_info");
		if (info == null) throw "the ELF carries no .debug_info: build with -g";

		final reader = new Reader(elf.bytes, info.offset);
		final end = info.offset + info.size;
		while (reader.position < end) unit(reader);

		var kept = 0;
		for (subprogram in subprograms) {
			if (elf.addressOf(subprogram.name) != subprogram.low) continue;
			subprograms[kept++] = subprogram;
		}
		while (subprograms.length > kept) subprograms.pop();
	}

	public function named(name:String):Null<Subprogram> {
		for (subprogram in subprograms) if (subprogram.name == name) return subprogram;
		return null;
	}

	public function at(address:Int):Null<Subprogram> {
		for (subprogram in subprograms) {
			if (address >= subprogram.low && address < subprogram.high) return subprogram;
		}
		return null;
	}

	function unit(reader:Reader):Void {
		final length = reader.u32();
		final unitEnd = reader.position + length;
		final version = reader.u16();

		if (version < 2 || version > 4) {
			reader.position = unitEnd;
			return;
		}

		final abbreviationOffset = reader.u32();
		final addressSize = reader.u8();
		final table = abbreviationsAt(abbreviationOffset);

		final owners:Array<Null<Subprogram>> = [null];

		while (reader.position < unitEnd) {
			final code = reader.uleb();
			if (code == 0) {
				if (owners.length > 1) owners.pop();
				continue;
			}

			final abbreviation = table.get(code);
			if (abbreviation == null) {
				reader.position = unitEnd;
				return;
			}

			final die = read(reader, abbreviation, addressSize);
			final owner = owners[owners.length - 1];
			var inherits = owner;

			switch (abbreviation.tag) {
				case TAG_SUBPROGRAM:
					inherits = null;
					if (die.low != null && die.name != null) {
						inherits = {
							name: die.name,
							low: die.low,
							high: die.highIsAddress ? die.high : die.low + die.high,
							frameBase: die.frameBase == null ? nowhere() : die.frameBase,
							variables: []
						};
						subprograms.push(inherits);
					}

				case TAG_FORMAL_PARAMETER, TAG_VARIABLE:
					if (owner != null && die.name != null) {
						owner.variables.push({
							name: die.name,
							owner: owner.name,
							parameter: abbreviation.tag == TAG_FORMAL_PARAMETER,
							location: die.location == null ? nowhere() : die.location
						});
					}

				case TAG_LEXICAL_BLOCK:

				case _:
					inherits = null;
			}

			if (abbreviation.children) owners.push(inherits);
		}
	}

	function read(reader:Reader, abbreviation:Abbreviation, addressSize:Int):{
		name:Null<String>, low:Null<Int>, high:Int, highIsAddress:Bool,
		location:Null<Location>, frameBase:Null<Location>
	} {
		var name:Null<String> = null;
		var low:Null<Int> = null;
		var high = 0;
		var highIsAddress = false;
		var location:Null<Location> = null;
		var frameBase:Null<Location> = null;

		for (attribute in abbreviation.attributes) {
			if (attribute.form == 0x08) {
				final inlined = reader.string();
				if (attribute.at == AT_NAME) name = inlined;
				continue;
			}

			final block = blockOf(reader, attribute.form);
			final value = block < 0 ? valueOf(reader, attribute.form, attribute.constant, addressSize) : 0;

			switch (attribute.at) {
				case AT_NAME if (block < 0): name = text(reader, attribute.form, value);
				case AT_LOW_PC if (block < 0): low = value;
				case AT_HIGH_PC if (block < 0):
					high = value;
					highIsAddress = attribute.form == FORM_ADDR;
				case AT_LOCATION:
					location = block >= 0 ? expression(reader, block) : {where: InList, register: -1, value: value};
				case AT_FRAME_BASE:
					frameBase = block >= 0 ? expression(reader, block) : nowhere();
				case _:
			}

			if (block >= 0) reader.position += block;
		}

		return {
			name: name, low: low, high: high, highIsAddress: highIsAddress,
			location: location, frameBase: frameBase
		};
	}

	function blockOf(reader:Reader, form:Int):Int {
		return switch (form) {
			case 0x03: reader.u16();
			case 0x04: reader.u32();
			case 0x09, 0x18: reader.uleb();
			case 0x0A: reader.u8();
			case _: -1;
		}
	}

	function valueOf(reader:Reader, form:Int, constant:Int, addressSize:Int):Int {
		return switch (form) {
			case 0x01: addressSize == 8 ? {reader.u32(); reader.u32();} : reader.u32();
			case 0x05, 0x12: reader.u16();
			case 0x06, 0x10, 0x13, 0x17, 0x1F, 0x0E: reader.u32();
			case 0x07, 0x14, 0x20: {reader.u32(); reader.u32();}
			case 0x0B, 0x11, 0x0C, 0x1A, 0x25, 0x29: reader.u8();
			case 0x0D: reader.sleb();
			case 0x0F, 0x15, 0x1B, 0x22, 0x23: reader.uleb();
			case 0x19: 0;
			case 0x21: constant;
			case 0x1E: {for (_ in 0...4) reader.u32(); 0;}
			case 0x16: valueOf(reader, reader.uleb(), constant, addressSize);
			case _: 0;
		}
	}

	function text(reader:Reader, form:Int, value:Int):Null<String> {
		if (form != 0x0E || strings == null) return null;
		final at = strings.offset + value;
		var end = at;
		while (elf.bytes.get(end) != 0) end++;
		return elf.bytes.getString(at, end - at);
	}

	function expression(reader:Reader, length:Int):Location {
		if (length == 0) return nowhere();

		final start = reader.position;
		final operation = elf.bytes.get(start);
		final operand = new Reader(elf.bytes, start + 1);

		if (operation == 0x03 && length == 5) return {where: AtAddress, register: -1, value: operand.u32()};
		if (operation == 0x91) return {where: AtFrameOffset, register: -1, value: operand.sleb()};
		if (operation >= 0x50 && operation <= 0x6F && length == 1)
			return {where: InRegister, register: operation - 0x50, value: 0};
		if (operation >= 0x70 && operation <= 0x8F)
			return {where: AtRegisterOffset, register: operation - 0x70, value: operand.sleb()};
		if (operation == 0x9C) return {where: TheCallFrameAddress, register: -1, value: 0};

		return nowhere();
	}

	static inline function nowhere():Location {
		return {where: Nowhere, register: -1, value: 0};
	}

	function abbreviationsAt(offset:Int):Map<Int, Abbreviation> {
		final known = abbreviations.get(offset);
		if (known != null) return known;

		final table:Map<Int, Abbreviation> = [];
		abbreviations.set(offset, table);

		final section = elf.section(".debug_abbrev");
		if (section == null) return table;

		final reader = new Reader(elf.bytes, section.offset + offset);
		final end = section.offset + section.size;

		while (reader.position < end) {
			final code = reader.uleb();
			if (code == 0) break;

			final tag = reader.uleb();
			final children = reader.u8() != 0;
			final attributes = new Array<Attribute>();

			while (true) {
				final at = reader.uleb();
				final form = reader.uleb();
				final constant = form == 0x21 ? reader.sleb() : 0;
				if (at == 0 && form == 0) break;
				attributes.push({at: at, form: form, constant: constant});
			}

			table.set(code, {tag: tag, children: children, attributes: attributes});
		}

		return table;
	}
}

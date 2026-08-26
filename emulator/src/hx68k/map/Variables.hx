package hx68k.map;

enum abstract Where(Int) from Int to Int {
	var Nowhere = 0;
	var InRegister = 1;
	var AtFrameOffset = 2;
	var AtRegisterOffset = 3;
	var AtAddress = 4;
	var InList = 5;
	var TheCallFrameAddress = 6;
	var Constant = 7;

	public function toString():String {
		return switch (cast this : Where) {
			case Nowhere: "nowhere";
			case InRegister: "in a register";
			case AtFrameOffset: "at a frame offset";
			case AtRegisterOffset: "at a register offset";
			case AtAddress: "at an address";
			case InList: "in a location list";
			case TheCallFrameAddress: "the call frame address";
			case Constant: "a constant";
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
	var width:Int;
	var signed:Bool;
}

typedef Subprogram = {
	final name:String;
	final low:Int;
	final high:Int;
	final base:Int;
	final version:Int;
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
	static inline final TAG_COMPILE_UNIT = 0x11;

	static inline final AT_LOCATION = 0x02;
	static inline final AT_NAME = 0x03;
	static inline final AT_LOW_PC = 0x11;
	static inline final AT_HIGH_PC = 0x12;
	static inline final AT_FRAME_BASE = 0x40;
	static inline final AT_BYTE_SIZE = 0x0B;
	static inline final AT_ENCODING = 0x3E;
	static inline final AT_TYPE = 0x49;

	static inline final FORM_ADDR = 0x01;

	public final subprograms:Array<Subprogram> = [];

	final elf:Elf;
	final strings:Null<Elf.Section>;
	final abbreviations:Map<Int, Map<Int, Abbreviation>> = [];
	final sizes:Map<Int, Int> = [];
	final encodings:Map<Int, Int> = [];
	final references:Map<Int, Int> = [];
	final pending:Array<{variable:Variable, type:Int}> = [];

	public function new(elf:Elf) {
		this.elf = elf;
		this.strings = elf.section(".debug_str");

		final info = elf.section(".debug_info");
		if (info == null) throw "the ELF carries no .debug_info: build with -g";

		final reader = new Reader(elf.bytes, info.offset);
		final end = info.offset + info.size;
		while (reader.position < end) unit(reader, info.offset);

		for (waiting in pending) {
			waiting.variable.width = widthOf(waiting.type);
			waiting.variable.signed = signedOf(waiting.type);
		}

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

	public function placeOf(subprogram:Subprogram, variable:Variable, address:Int):Location {
		if (variable.location.where != InList) return variable.location;
		if (subprogram.version >= 5) return listed(subprogram, variable.location.value, address);

		final section = elf.section(".debug_loc");
		if (section == null) return nowhere();

		final reader = new Reader(elf.bytes, section.offset + variable.location.value);
		final end = section.offset + section.size;
		var base = subprogram.base;

		while (reader.position + 8 <= end) {
			final from = reader.u32();
			final to = reader.u32();

			if (from == 0 && to == 0) return nowhere();

			if (from == 0xFFFFFFFF) {
				base = to;
				continue;
			}

			final length = reader.u16();
			if (address >= base + from && address < base + to) return expression(reader, length);
			reader.position += length;
		}

		return nowhere();
	}

	function listed(subprogram:Subprogram, at:Int, address:Int):Location {
		final section = elf.section(".debug_loclists");
		if (section == null) return nowhere();

		final reader = new Reader(elf.bytes, section.offset + at);
		final end = section.offset + section.size;
		var base = subprogram.base;
		var otherwise:Location = nowhere();

		while (reader.position < end) {
			final kind = reader.u8();

			if (kind == 0x00) return otherwise;

			if (kind == 0x06) {
				base = reader.u32();
				continue;
			}

			if (kind == 0x05) {
				final length = reader.uleb();
				otherwise = expression(reader, length);
				reader.position += length;
				continue;
			}

			var from = 0;
			var to = 0;

			switch (kind) {
				case 0x04:
					from = base + reader.uleb();
					to = base + reader.uleb();
				case 0x07:
					from = reader.u32();
					to = reader.u32();
				case 0x08:
					from = reader.u32();
					to = from + reader.uleb();
				case _:
					return otherwise;
			}

			final length = reader.uleb();
			if (address >= from && address < to) return expression(reader, length);
			reader.position += length;
		}

		return otherwise;
	}

	public function at(address:Int):Null<Subprogram> {
		for (subprogram in subprograms) {
			if (address >= subprogram.low && address < subprogram.high) return subprogram;
		}
		return null;
	}

	function unit(reader:Reader, sectionStart:Int):Void {
		final unitStart = reader.position - sectionStart;
		final length = reader.u32();
		final unitEnd = reader.position + length;
		final version = reader.u16();

		if (version < 2 || version > 5) {
			reader.position = unitEnd;
			return;
		}

		if (version >= 5) reader.u8();
		final addressSize = version >= 5 ? reader.u8() : 0;
		final abbreviationOffset = reader.u32();
		if (version < 5) reader.u8();
		final table = abbreviationsAt(abbreviationOffset);

		final owners:Array<Null<Subprogram>> = [null];
		var unitBase = 0;

		while (reader.position < unitEnd) {
			final code = reader.uleb();
			if (code == 0) {
				if (owners.length > 1) owners.pop();
				continue;
			}

			final offset = reader.position - sectionStart - 1;
			final abbreviation = table.get(code);
			if (abbreviation == null) {
				reader.position = unitEnd;
				return;
			}

			final die = read(reader, abbreviation, addressSize, unitStart);
			if (die.byteSize != null) sizes.set(offset, die.byteSize);
			if (die.encoding != null) encodings.set(offset, die.encoding);
			if (die.type != null) references.set(offset, die.type);
			final owner = owners[owners.length - 1];
			var inherits = owner;

			switch (abbreviation.tag) {
				case TAG_COMPILE_UNIT:
					if (die.low != null) unitBase = die.low;
					inherits = null;

				case TAG_SUBPROGRAM:
					inherits = null;
					if (die.low != null && die.name != null) {
						inherits = {
							name: die.name,
							low: die.low,
							high: die.highIsAddress ? die.high : die.low + die.high,
							base: unitBase,
							version: version,
							frameBase: die.frameBase == null ? nowhere() : die.frameBase,
							variables: []
						};
						subprograms.push(inherits);
					}

				case TAG_FORMAL_PARAMETER, TAG_VARIABLE:
					if (owner != null && die.name != null) {
						final variable:Variable = {
							name: die.name,
							owner: owner.name,
							parameter: abbreviation.tag == TAG_FORMAL_PARAMETER,
							location: die.location == null ? nowhere() : die.location,
							width: 4,
							signed: true
						};
						owner.variables.push(variable);
						if (die.type != null) pending.push({variable: variable, type: die.type});
					}

				case TAG_LEXICAL_BLOCK:

				case _:
					inherits = null;
			}

			if (abbreviation.children) owners.push(inherits);
		}
	}

	function read(reader:Reader, abbreviation:Abbreviation, addressSize:Int, unitStart:Int):{
		name:Null<String>, low:Null<Int>, high:Int, highIsAddress:Bool,
		location:Null<Location>, frameBase:Null<Location>,
		byteSize:Null<Int>, encoding:Null<Int>, type:Null<Int>
	} {
		var name:Null<String> = null;
		var low:Null<Int> = null;
		var high = 0;
		var highIsAddress = false;
		var location:Null<Location> = null;
		var frameBase:Null<Location> = null;
		var byteSize:Null<Int> = null;
		var encoding:Null<Int> = null;
		var type:Null<Int> = null;

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
				case AT_BYTE_SIZE if (block < 0): byteSize = value;
				case AT_ENCODING if (block < 0): encoding = value;
				case AT_TYPE if (block < 0):
					type = attribute.form == 0x10 ? value : unitStart + value;
				case _:
			}

			if (block >= 0) reader.position += block;
		}

		return {
			name: name, low: low, high: high, highIsAddress: highIsAddress,
			location: location, frameBase: frameBase,
			byteSize: byteSize, encoding: encoding, type: type
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

		if (operation >= 0x30 && operation <= 0x4F && length == 2 && elf.bytes.get(start + 1) == 0x9F)
			return {where: Constant, register: -1, value: operation - 0x30};
		if (operation == 0x10 || operation == 0x11) {
			final value = operation == 0x10 ? operand.uleb() : operand.sleb();
			if (operand.position - start == length - 1 && elf.bytes.get(operand.position) == 0x9F)
				return {where: Constant, register: -1, value: value};
			return nowhere();
		}

		if (operation == 0x03 && length == 5) return {where: AtAddress, register: -1, value: operand.u32()};

		if (operation == 0x91) {
			final offset = operand.sleb();
			if (operand.position - start != length) return nowhere();
			return {where: AtFrameOffset, register: -1, value: offset};
		}

		if (operation >= 0x50 && operation <= 0x6F && length == 1)
			return {where: InRegister, register: operation - 0x50, value: 0};

		if (operation >= 0x70 && operation <= 0x8F) {
			final offset = operand.sleb();
			if (operand.position - start != length) return nowhere();
			return {where: AtRegisterOffset, register: operation - 0x70, value: offset};
		}

		if (operation == 0x9C && length == 1) return {where: TheCallFrameAddress, register: -1, value: 0};

		return nowhere();
	}

	function widthOf(type:Int):Int {
		var at = type;
		for (_ in 0...16) {
			final size = sizes.get(at);
			if (size != null) return size;
			final next = references.get(at);
			if (next == null) return 4;
			at = next;
		}
		return 4;
	}

	function signedOf(type:Int):Bool {
		var at = type;
		for (_ in 0...16) {
			final encoding = encodings.get(at);
			if (encoding != null) return encoding == 0x05 || encoding == 0x06;
			final next = references.get(at);
			if (next == null) return true;
			at = next;
		}
		return true;
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

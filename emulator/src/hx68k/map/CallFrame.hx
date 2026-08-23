package hx68k.map;

typedef Cfa = {
	final register:Int;
	final offset:Int;
}

private typedef Cie = {
	final codeAlignment:Int;
	final dataAlignment:Int;
	final start:Int;
	final end:Int;
}

private typedef Fde = {
	final low:Int;
	final high:Int;
	final cie:Int;
	final start:Int;
	final end:Int;
}

class CallFrame {
	public final frames:Array<Fde> = [];

	final elf:Elf;
	final cies:Map<Int, Cie> = [];

	public function new(elf:Elf) {
		this.elf = elf;

		final section = elf.section(".debug_frame");
		if (section == null) throw "the ELF carries no .debug_frame: build with -g";

		final reader = new Reader(elf.bytes, section.offset);
		final end = section.offset + section.size;

		while (reader.position + 4 <= end) {
			final start = reader.position;
			final length = reader.u32();
			if (length == 0 || length == 0xFFFFFFFF) break;

			final entryEnd = reader.position + length;
			final id = reader.u32();

			if (id == 0xFFFFFFFF) readCie(reader, start - section.offset, entryEnd);
			else readFde(reader, id, entryEnd);

			reader.position = entryEnd;
		}

		var kept = 0;
		for (fde in frames) {
			final symbol = elf.functionAt(fde.low);
			if (fde.low == 0 || symbol == null || symbol.address != fde.low) continue;
			frames[kept++] = fde;
		}
		while (frames.length > kept) frames.pop();

		frames.sort((a, b) -> a.low < b.low ? -1 : (a.low == b.low ? 0 : 1));
	}

	public function at(address:Int):Null<Cfa> {
		final fde = covering(address);
		if (fde == null) return null;

		final cie = cies.get(fde.cie);
		if (cie == null) return null;

		var register = -1;
		var offset = 0;
		var location = fde.low;

		final initial = run(cie, cie.start, cie.end, address, location, register, offset);
		if (initial == null) return null;

		final walked = run(cie, fde.start, fde.end, address, location, initial.register, initial.offset);
		if (walked == null) return null;

		return walked.register < 0 ? null : {register: walked.register, offset: walked.offset};
	}

	public function covering(address:Int):Null<Fde> {
		for (fde in frames) if (address >= fde.low && address < fde.high) return fde;
		return null;
	}

	function run(cie:Cie, from:Int, to:Int, address:Int, start:Int, register:Int, offset:Int):Null<Cfa> {
		final reader = new Reader(elf.bytes, from);
		final remembered = new Array<Cfa>();

		var location = start;
		var cfaRegister = register;
		var cfaOffset = offset;

		while (reader.position < to) {
			final operation = reader.u8();
			final high = operation & 0xC0;
			final low = operation & 0x3F;

			if (high == 0x40) {
				location += low * cie.codeAlignment;
				if (location > address) break;
				continue;
			}

			if (high == 0x80) {
				reader.uleb();
				continue;
			}

			if (high == 0xC0) continue;

			switch (low) {
				case 0x00:
				case 0x01:
					location = reader.u32();
					if (location > address) break;
				case 0x02:
					location += reader.u8() * cie.codeAlignment;
					if (location > address) break;
				case 0x03:
					location += reader.u16() * cie.codeAlignment;
					if (location > address) break;
				case 0x04:
					location += reader.u32() * cie.codeAlignment;
					if (location > address) break;
				case 0x0C:
					cfaRegister = reader.uleb();
					cfaOffset = reader.uleb();
				case 0x0D: cfaRegister = reader.uleb();
				case 0x0E: cfaOffset = reader.uleb();
				case 0x12:
					cfaRegister = reader.uleb();
					cfaOffset = reader.sleb() * cie.dataAlignment;
				case 0x13: cfaOffset = reader.sleb() * cie.dataAlignment;
				case 0x0A: remembered.push({register: cfaRegister, offset: cfaOffset});
				case 0x0B:
					if (remembered.length > 0) {
						final back = remembered.pop();
						cfaRegister = back.register;
						cfaOffset = back.offset;
					}
				case 0x0F: return null;
				case 0x10, 0x16:
					reader.uleb();
					reader.position += reader.uleb();
				case 0x05, 0x09, 0x14: {reader.uleb(); reader.uleb();}
				case 0x11, 0x15: {reader.uleb(); reader.sleb();}
				case 0x06, 0x07, 0x08, 0x2E: reader.uleb();
				case _: return null;
			}
		}

		return {register: cfaRegister, offset: cfaOffset};
	}

	function readCie(reader:Reader, offset:Int, end:Int):Void {
		final version = reader.u8();

		var augmented = false;
		while (true) {
			final byte = reader.u8();
			if (byte == 0) break;
			augmented = true;
		}
		if (augmented) return;

		if (version >= 4) {
			reader.u8();
			reader.u8();
		}

		final codeAlignment = reader.uleb();
		final dataAlignment = reader.sleb();

		if (version == 1) reader.u8() else reader.uleb();

		cies.set(offset, {
			codeAlignment: codeAlignment,
			dataAlignment: dataAlignment,
			start: reader.position,
			end: end
		});
	}

	function readFde(reader:Reader, cie:Int, end:Int):Void {
		final low = reader.u32();
		final range = reader.u32();

		frames.push({low: low, high: low + range, cie: cie, start: reader.position, end: end});
	}
}

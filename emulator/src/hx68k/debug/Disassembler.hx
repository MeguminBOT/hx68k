package hx68k.debug;

typedef Instruction = {
	final address:Int;
	final text:String;
	final length:Int;
}

class Disassembler {
	static final CONDITIONS = [
		"T", "F", "HI", "LS", "CC", "CS", "NE", "EQ",
		"VC", "VS", "PL", "MI", "GE", "LT", "GT", "LE"
	];

	static final SIZES = [".b", ".w", ".l"];

	final code:Code;
	var cursor:Int = 0;
	var start:Int = 0;

	public function new(code:Code) {
		this.code = code;
	}

	public function at(address:Int):Instruction {
		start = address & 0xFFFFFF;
		cursor = start;

		final text = decode(next());
		return {address: start, text: text, length: cursor - start};
	}

	inline function next():Int {
		final w = code.word(cursor & 0xFFFFFF) & 0xFFFF;
		cursor += 2;
		return w;
	}

	function decode(op:Int):String {
		return switch (op >> 12) {
			case 0x0: immediateGroup(op);
			case 0x1: move(op, 0);
			case 0x2: move(op, 2);
			case 0x3: move(op, 1);
			case 0x4: miscGroup(op);
			case 0x5: quickGroup(op);
			case 0x6: branch(op);
			case 0x7: (op & 0x0100) != 0 ? unknown(op) : "MOVEQ #" + signedHex(s8(op)) + ",D" + ((op >> 9) & 7);
			case 0x8: orGroup(op);
			case 0x9: subGroup(op);
			case 0xB: compareGroup(op);
			case 0xC: andGroup(op);
			case 0xD: addGroup(op);
			case 0xE: shiftGroup(op);
			case _: unknown(op);
		}
	}

	function immediateGroup(op:Int):String {
		if ((op & 0xF138) == 0x0108) return movep(op);
		if ((op & 0x0100) != 0) return bitOperation(op, "D" + ((op >> 9) & 7));
		if (((op >> 9) & 7) == 4) return bitOperation(op, "#" + hex(next() & 0xFF, 2));

		final name = switch ((op >> 9) & 7) {
			case 0: "ORI";
			case 1: "ANDI";
			case 2: "SUBI";
			case 3: "ADDI";
			case 5: "EORI";
			case 6: "CMPI";
			case _: null;
		}
		if (name == null) return unknown(op);

		final size = (op >> 6) & 3;
		if (size == 3) return unknown(op);

		if ((op & 0x3F) == 0x3C) {
			if (name != "ORI" && name != "ANDI" && name != "EORI") return unknown(op);
			if (size == 0) return name + " #" + hex(next() & 0xFF, 2) + ",CCR";
			if (size == 1) return name + " #" + hex(next(), 4) + ",SR";
			return unknown(op);
		}

		final value = immediate(size);
		final mode = (op >> 3) & 7;
		final target = effectiveAddress(op & 7, mode, size);
		if (target == null) return unknown(op);
		if (name == "CMPI" ? !isData(mode) : !isDataAlterable(mode, op & 7)) return unknown(op);
		return name + SIZES[size] + " " + value + "," + target;
	}

	function bitOperation(op:Int, source:String):String {
		final name = switch ((op >> 6) & 3) {
			case 0: "BTST";
			case 1: "BCHG";
			case 2: "BCLR";
			case _: "BSET";
		}

		final mode = (op >> 3) & 7;
		final register = op & 7;
		final size = mode == 0 ? 2 : 0;

		final allowed = name == "BTST" ? isData(mode) : isDataAlterable(mode, register);
		if (!allowed) return unknown(op);

		final target = effectiveAddress(register, mode, size);
		if (target == null) return unknown(op);
		return name + " " + source + "," + target;
	}

	function movep(op:Int):String {
		final size = (op & 0x0040) != 0 ? ".l" : ".w";
		final displacement = "(" + signedHex(s16(next())) + ",A" + (op & 7) + ")";
		final register = "D" + ((op >> 9) & 7);

		return (op & 0x0080) != 0
			? "MOVEP" + size + " " + register + "," + displacement
			: "MOVEP" + size + " " + displacement + "," + register;
	}

	function move(op:Int, size:Int):String {
		final sourceMode = (op >> 3) & 7;
		if (size == 0 && sourceMode == 1) return unknown(op);

		final source = effectiveAddress(op & 7, sourceMode, size);
		if (source == null) return unknown(op);

		final destinationMode = (op >> 6) & 7;
		final destinationRegister = (op >> 9) & 7;
		if (size == 0 && destinationMode == 1) return unknown(op);
		if (!isAlterable(destinationMode, destinationRegister)) return unknown(op);

		final destination = effectiveAddress(destinationRegister, destinationMode, size);
		if (destination == null) return unknown(op);

		return (destinationMode == 1 ? "MOVEA" : "MOVE") + SIZES[size] + " " + source + "," + destination;
	}

	function miscGroup(op:Int):String {
		final mode = (op >> 3) & 7;
		final register = op & 7;

		if ((op & 0x01C0) == 0x01C0) {
			if (!isControl(mode, register)) return unknown(op);
			final source = effectiveAddress(register, mode, 2);
			return source == null ? unknown(op) : "LEA " + source + ",A" + ((op >> 9) & 7);
		}

		if ((op & 0x01C0) == 0x0180) {
			if (!isData(mode)) return unknown(op);
			final source = effectiveAddress(register, mode, 1);
			return source == null ? unknown(op) : "CHK.w " + source + ",D" + ((op >> 9) & 7);
		}

		if ((op & 0xFB80) == 0x4880 && mode != 0) return movem(op);

		return switch (op & 0xFFF8) {
			case 0x4840: "SWAP D" + register;
			case 0x4880: "EXT.w D" + register;
			case 0x48C0: "EXT.l D" + register;
			case 0x4E50: "LINK A" + register + ",#" + signedHex(s16(next()));
			case 0x4E58: "UNLK A" + register;
			case 0x4E60: "MOVE A" + register + ",USP";
			case 0x4E68: "MOVE USP,A" + register;
			case _: miscRest(op);
		}
	}

	function miscRest(op:Int):String {
		switch (op) {
			case 0x4AFC: return "ILLEGAL";
			case 0x4E70: return "RESET";
			case 0x4E71: return "NOP";
			case 0x4E72: return "STOP #" + hex(next(), 4);
			case 0x4E73: return "RTE";
			case 0x4E75: return "RTS";
			case 0x4E76: return "TRAPV";
			case 0x4E77: return "RTR";
			case _:
		}

		if ((op & 0xFFF0) == 0x4E40) return "TRAP #" + (op & 15);

		final mode = (op >> 3) & 7;
		final register = op & 7;
		final size = (op >> 6) & 3;

		if ((op & 0xFF80) == 0x4E80) {
			if (!isControl(mode, register)) return unknown(op);
			final target = effectiveAddress(register, mode, 2);
			if (target == null) return unknown(op);
			return ((op & 0x0040) != 0 ? "JMP " : "JSR ") + target;
		}

		if ((op & 0xFFC0) == 0x4800) return single(op, "NBCD", 0);
		if ((op & 0xFFC0) == 0x4AC0) return single(op, "TAS", 0);

		if ((op & 0xFFC0) == 0x4840) {
			if (!isControl(mode, register)) return unknown(op);
			final target = effectiveAddress(register, mode, 2);
			return target == null ? unknown(op) : "PEA " + target;
		}

		if (size == 3) return statusMove(op);

		final name = switch ((op >> 9) & 7) {
			case 0: "NEGX";
			case 1: "CLR";
			case 2: "NEG";
			case 3: "NOT";
			case 5: "TST";
			case _: null;
		}
		if (name == null) return unknown(op);
		if (name == "TST" ? !isData(mode) : !isDataAlterable(mode, register)) return unknown(op);

		final target = effectiveAddress(register, mode, size);
		return target == null ? unknown(op) : name + SIZES[size] + " " + target;
	}

	function single(op:Int, name:String, size:Int):String {
		final mode = (op >> 3) & 7;
		final register = op & 7;
		if (!isDataAlterable(mode, register)) return unknown(op);

		final target = effectiveAddress(register, mode, size);
		return target == null ? unknown(op) : name + " " + target;
	}

	function statusMove(op:Int):String {
		final mode = (op >> 3) & 7;
		final register = op & 7;

		return switch ((op >> 9) & 7) {
			case 0:
				if (!isDataAlterable(mode, register)) unknown(op);
				else {
					final target = effectiveAddress(register, mode, 1);
					target == null ? unknown(op) : "MOVE SR," + target;
				}
			case 2, 3:
				if (!isData(mode)) unknown(op);
				else {
					final source = effectiveAddress(register, mode, 1);
					final into = ((op >> 9) & 7) == 2 ? ",CCR" : ",SR";
					source == null ? unknown(op) : "MOVE " + source + into;
				}
			case _: unknown(op);
		}
	}

	function movem(op:Int):String {
		final mask = next();
		final mode = (op >> 3) & 7;
		final register = op & 7;
		final size = (op & 0x0040) != 0 ? 2 : 1;
		final toRegisters = (op & 0x0400) != 0;

		final allowed = toRegisters
			? mode == 3 || isControl(mode, register)
			: mode == 4 || isControlAlterable(mode, register);
		if (!allowed) return unknown(op);

		final target = effectiveAddress(register, mode, size);
		if (target == null) return unknown(op);

		final list = registerList(mask, mode == 4);
		return "MOVEM" + SIZES[size] + " " + (toRegisters ? target + "," + list : list + "," + target);
	}

	function quickGroup(op:Int):String {
		final size = (op >> 6) & 3;
		final mode = (op >> 3) & 7;
		final register = op & 7;

		if (size == 3) {
			final condition = CONDITIONS[(op >> 8) & 15];

			if (mode == 1) {
				final displacement = s16(next());
				return (condition == "F" ? "DBRA" : "DB" + condition)
					+ " D" + register + "," + hex((start + 2 + displacement) & 0xFFFFFF, 6);
			}

			if (!isDataAlterable(mode, register)) return unknown(op);
			final target = effectiveAddress(register, mode, 0);
			return target == null ? unknown(op) : "S" + condition + " " + target;
		}

		if (mode == 1 && size == 0) return unknown(op);
		if (mode != 1 && !isDataAlterable(mode, register)) return unknown(op);

		final target = effectiveAddress(register, mode, size);
		if (target == null) return unknown(op);

		final count = ((op >> 9) & 7) == 0 ? 8 : ((op >> 9) & 7);
		return ((op & 0x0100) != 0 ? "SUBQ" : "ADDQ") + SIZES[size] + " #" + count + "," + target;
	}

	function branch(op:Int):String {
		final condition = (op >> 8) & 15;
		final name = switch (condition) {
			case 0: "BRA";
			case 1: "BSR";
			case _: "B" + CONDITIONS[condition];
		}

		final byte = op & 0xFF;
		if (byte != 0) return name + ".s " + hex((start + 2 + s8(byte)) & 0xFFFFFF, 6);
		return name + ".w " + hex((start + 2 + s16(next())) & 0xFFFFFF, 6);
	}

	function orGroup(op:Int):String {
		if ((op & 0x01F0) == 0x0100) return decimal(op, "SBCD");
		if (((op >> 6) & 3) == 3) return unsized(op, (op & 0x0100) != 0 ? "DIVS.w" : "DIVU.w");
		return alu(op, "OR");
	}

	function andGroup(op:Int):String {
		if ((op & 0x01F0) == 0x0100) return decimal(op, "ABCD");
		if ((op & 0x01F8) == 0x0140) return "EXG D" + ((op >> 9) & 7) + ",D" + (op & 7);
		if ((op & 0x01F8) == 0x0148) return "EXG A" + ((op >> 9) & 7) + ",A" + (op & 7);
		if ((op & 0x01F8) == 0x0188) return "EXG D" + ((op >> 9) & 7) + ",A" + (op & 7);
		if (((op >> 6) & 3) == 3) return unsized(op, (op & 0x0100) != 0 ? "MULS.w" : "MULU.w");
		return alu(op, "AND");
	}

	function subGroup(op:Int):String {
		if (((op >> 6) & 3) == 3) return address(op, "SUBA");
		if ((op & 0x0130) == 0x0100) return extended(op, "SUBX");
		return alu(op, "SUB");
	}

	function addGroup(op:Int):String {
		if (((op >> 6) & 3) == 3) return address(op, "ADDA");
		if ((op & 0x0130) == 0x0100) return extended(op, "ADDX");
		return alu(op, "ADD");
	}

	function compareGroup(op:Int):String {
		if (((op >> 6) & 3) == 3) return address(op, "CMPA");

		final size = (op >> 6) & 3;
		final mode = (op >> 3) & 7;
		final register = op & 7;

		if ((op & 0x0100) == 0) {
			if (size == 0 && mode == 1) return unknown(op);
			final source = effectiveAddress(register, mode, size);
			return source == null ? unknown(op) : "CMP" + SIZES[size] + " " + source + ",D" + ((op >> 9) & 7);
		}

		if (mode == 1)
			return "CMPM" + SIZES[size] + " (A" + register + ")+,(A" + ((op >> 9) & 7) + ")+";

		if (!isDataAlterable(mode, register)) return unknown(op);
		final target = effectiveAddress(register, mode, size);
		return target == null ? unknown(op) : "EOR" + SIZES[size] + " D" + ((op >> 9) & 7) + "," + target;
	}

	function alu(op:Int, name:String):String {
		final size = (op >> 6) & 3;
		final mode = (op >> 3) & 7;
		final register = op & 7;

		if ((op & 0x0100) == 0) {
			final logical = name == "OR" || name == "AND";
			if (mode == 1 && (size == 0 || logical)) return unknown(op);

			final source = effectiveAddress(register, mode, size);
			return source == null ? unknown(op) : name + SIZES[size] + " " + source + ",D" + ((op >> 9) & 7);
		}

		if (!isMemoryAlterable(mode, register)) return unknown(op);
		final target = effectiveAddress(register, mode, size);
		return target == null ? unknown(op) : name + SIZES[size] + " D" + ((op >> 9) & 7) + "," + target;
	}

	function address(op:Int, name:String):String {
		final size = (op & 0x0100) != 0 ? 2 : 1;
		final source = effectiveAddress(op & 7, (op >> 3) & 7, size);
		return source == null ? unknown(op) : name + SIZES[size] + " " + source + ",A" + ((op >> 9) & 7);
	}

	function unsized(op:Int, name:String):String {
		final mode = (op >> 3) & 7;
		if (!isData(mode)) return unknown(op);

		final source = effectiveAddress(op & 7, mode, 1);
		return source == null ? unknown(op) : name + " " + source + ",D" + ((op >> 9) & 7);
	}

	function extended(op:Int, name:String):String {
		final size = (op >> 6) & 3;
		if (size == 3) return unknown(op);

		final x = (op >> 9) & 7;
		final y = op & 7;
		return (op & 0x0008) != 0
			? name + SIZES[size] + " -(A" + y + "),-(A" + x + ")"
			: name + SIZES[size] + " D" + y + ",D" + x;
	}

	function decimal(op:Int, name:String):String {
		final x = (op >> 9) & 7;
		final y = op & 7;
		return (op & 0x0008) != 0
			? name + " -(A" + y + "),-(A" + x + ")"
			: name + " D" + y + ",D" + x;
	}

	function shiftGroup(op:Int):String {
		final size = (op >> 6) & 3;
		final left = (op & 0x0100) != 0;

		if (size == 3) {
			final kind = (op >> 9) & 7;
			final mode = (op >> 3) & 7;
			if (kind > 3 || !isMemoryAlterable(mode, op & 7)) return unknown(op);

			final target = effectiveAddress(op & 7, mode, 1);
			return target == null ? unknown(op) : shiftName(kind, left) + ".w " + target;
		}

		final source = (op & 0x0020) != 0
			? "D" + ((op >> 9) & 7)
			: "#" + (((op >> 9) & 7) == 0 ? 8 : ((op >> 9) & 7));

		return shiftName((op >> 3) & 3, left) + SIZES[size] + " " + source + ",D" + (op & 7);
	}

	inline function shiftName(kind:Int, left:Bool):String {
		final stem = switch (kind) {
			case 0: "AS";
			case 1: "LS";
			case 2: "ROX";
			case _: "RO";
		}
		return stem + (left ? "L" : "R");
	}

	function effectiveAddress(register:Int, mode:Int, size:Int):Null<String> {
		return switch (mode) {
			case 0: "D" + register;
			case 1: "A" + register;
			case 2: "(A" + register + ")";
			case 3: "(A" + register + ")+";
			case 4: "-(A" + register + ")";
			case 5: "(" + signedHex(s16(next())) + ",A" + register + ")";
			case 6: indexed("A" + register);
			case 7: switch (register) {
					case 0: "(" + hex(s16(next()) & 0xFFFFFF, 6) + ").w";
					case 1: absolute();
					case 2: "(" + signedHex(s16(next())) + ",PC)";
					case 3: indexed("PC");
					case 4: immediate(size);
					case _: null;
				}
			case _: null;
		}
	}

	function absolute():String {
		final high = next();
		final low = next();
		return "(" + hex(((high << 16) | low) & 0xFFFFFF, 6) + ").l";
	}

	function indexed(base:String):String {
		final extension = next();
		final index = (extension & 0x8000) != 0 ? "A" : "D";
		final width = (extension & 0x0800) != 0 ? ".l" : ".w";

		return "(" + signedHex(s8(extension)) + "," + base + ","
			+ index + ((extension >> 12) & 7) + width + ")";
	}

	function immediate(size:Int):String {
		if (size == 0) return "#" + hex(next() & 0xFF, 2);
		if (size == 1) return "#" + hex(next(), 4);

		final high = next();
		final low = next();
		return "#$" + StringTools.hex(high, 4) + StringTools.hex(low, 4);
	}

	static function registerList(mask:Int, reversed:Bool):String {
		if (mask == 0) return "#" + hex(0, 4);

		final present = new Array<Bool>();
		for (i in 0...16) present.push((mask & (1 << (reversed ? 15 - i : i))) != 0);

		final parts = new Array<String>();
		var i = 0;

		while (i < 16) {
			if (!present[i]) {
				i++;
				continue;
			}

			var end = i;
			while (end + 1 < 16 && present[end + 1] && end + 1 != 8) end++;
			parts.push(end > i ? registerName(i) + "-" + registerName(end) : registerName(i));
			i = end + 1;
		}

		return parts.join("/");
	}

	static inline function registerName(n:Int):String {
		return n < 8 ? "D" + n : "A" + (n - 8);
	}

	static inline function isControl(mode:Int, register:Int):Bool {
		if (mode == 0 || mode == 1 || mode == 3 || mode == 4) return false;
		return mode != 7 || register <= 3;
	}

	static inline function isAlterable(mode:Int, register:Int):Bool {
		return mode != 7 || register <= 1;
	}

	static inline function isControlAlterable(mode:Int, register:Int):Bool {
		return isControl(mode, register) && isAlterable(mode, register);
	}

	static inline function isDataAlterable(mode:Int, register:Int):Bool {
		return mode != 1 && isAlterable(mode, register);
	}

	static inline function isMemoryAlterable(mode:Int, register:Int):Bool {
		return mode != 0 && isDataAlterable(mode, register);
	}

	static inline function isData(mode:Int):Bool {
		return mode != 1;
	}

	function unknown(op:Int):String {
		cursor = start + 2;
		return "dc.w " + hex(op, 4);
	}

	static inline function s8(v:Int):Int {
		return (v & 0x80) != 0 ? (v & 0xFF) - 0x100 : v & 0xFF;
	}

	static inline function s16(v:Int):Int {
		return (v & 0x8000) != 0 ? (v & 0xFFFF) - 0x10000 : v & 0xFFFF;
	}

	static inline function hex(value:Int, digits:Int):String {
		return "$" + StringTools.hex(value, digits);
	}

	static inline function signedHex(value:Int):String {
		return value < 0 ? "-$" + StringTools.hex(-value, 1) : "$" + StringTools.hex(value, 1);
	}
}

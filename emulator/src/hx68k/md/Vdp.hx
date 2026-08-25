package hx68k.md;

import haxe.io.Bytes;
import haxe.ds.Vector;

@:allow(hx68k.md.Savestate)
final class Vdp {
	public static inline final MASTER_HZ = 53693175;

	public static inline final MASTER_PER_LINE = 3420;
	public static inline final LINES_NTSC = 262;
	public static inline final ACTIVE_LINES = 224;
	public static inline final ACTIVE_TICKS = 2560;

	public static inline final VINT_LEVEL = 6;
	public static inline final HINT_LEVEL = 4;

	public final registers:Vector<Int> = new Vector<Int>(32);
	public final vram:Bytes = Bytes.alloc(0x10000);
	public final cram:Vector<Int> = new Vector<Int>(64);
	public final vsram:Vector<Int> = new Vector<Int>(40);
	public final renderer:Renderer = new Renderer();

	public var rendering:Bool = true;

	public var line(default, null):Int = 0;
	public var frame(default, null):Int = 0;
	public var writes(default, null):Int = 0;
	public var reads(default, null):Int = 0;

	public var colours(default, null):Int = 0;

	final memory:Memory;

	var dot:Int = 0;
	var next:Int = ACTIVE_TICKS;
	var address:Int = 0;
	var code:Int = 0;
	var pending:Bool = false;
	var filling:Bool = false;
	var vint:Bool = false;
	var hint:Bool = false;
	var hintCounter:Int = 0;

	public function new(memory:Memory) {
		this.memory = memory;
		reset();
	}

	public function reset():Void {
		for (i in 0...registers.length) registers[i] = 0;
		for (i in 0...cram.length) cram[i] = 0;
		colours++;
		for (i in 0...vsram.length) vsram[i] = 0;
		vram.fill(0, vram.length, 0);

		registers[15] = 2;
		line = 0;
		frame = 0;
		dot = 0;
		next = ACTIVE_TICKS;
		address = 0;
		code = 0;
		pending = false;
		filling = false;
		vint = false;
		hint = false;
		hintCounter = 0;
		writes = 0;
		reads = 0;
	}

	public inline function tick(master:Int):Void {
		dot += master;
		if (dot >= next) events();
	}

	function events():Void {
		while (dot >= next) {
			if (next == ACTIVE_TICKS) {
				endOfDisplay();
				next = MASTER_PER_LINE;
			} else {
				dot -= MASTER_PER_LINE;
				endOfLine();
				next = ACTIVE_TICKS;
			}
		}
	}

	function endOfDisplay():Void {
		if (rendering && line < ACTIVE_LINES) renderer.line(this, line);

		if (line <= ACTIVE_LINES) {
			if (hintCounter <= 0) {
				hintCounter = registers[10];
				hint = true;
			} else {
				hintCounter--;
			}
		} else {
			hintCounter = registers[10];
		}
	}

	function endOfLine():Void {
		line++;
		if (line == ACTIVE_LINES) vint = true;
		if (line >= LINES_NTSC) {
			line = 0;
			frame++;
		}
	}

	public function irqLevel():Int {
		if (vint && (registers[1] & 0x20) != 0) return VINT_LEVEL;
		if (hint && (registers[0] & 0x10) != 0) return HINT_LEVEL;
		return 0;
	}

	public function acknowledge(level:Int):Void {
		if (level == VINT_LEVEL) vint = false else hint = false;
	}

	public function writeControl(value:Int):Void {
		if (!pending && (value & 0xC000) == 0x8000) {
			registers[(value >> 8) & 0x1F] = value & 0xFF;
			return;
		}

		if (!pending) {
			address = (address & 0xC000) | (value & 0x3FFF);
			code = (code & 0x3C) | ((value >> 14) & 0x03);
			pending = true;
			return;
		}

		address = (address & 0x3FFF) | ((value & 0x03) << 14);
		code = (code & 0x03) | ((value >> 2) & 0x3C);
		pending = false;
		if ((code & 0x20) != 0) startDma();
	}

	public function writeData(value:Int):Void {
		writes++;
		pending = false;
		if (filling) fillVram(value) else store(value);
	}

	public function readData():Int {
		reads++;
		pending = false;
		final value = switch (code & 0x0F) {
			case 0x00: readVram(address);
			case 0x08: cram[(address >> 1) & 63];
			case 0x04: vsram[(address >> 1) % vsram.length];
			case _: 0;
		}
		address = (address + registers[15]) & 0xFFFF;
		return value;
	}

	public function readStatus():Int {
		reads++;
		pending = false;

		var value = 0x3400 | 0x0200;
		if (line >= ACTIVE_LINES) value |= 0x0008;
		if (dot >= ACTIVE_TICKS) value |= 0x0004;
		if (vint) value |= 0x0080;
		return value;
	}

	public function readCounter():Int {
		reads++;
		final v = line <= 0xEA ? line : line - 0xEB + 0xE5;
		final step = Std.int(dot * 211 / MASTER_PER_LINE);
		final h = step <= 0xB6 ? step : step - 0xB7 + 0xE4;
		return ((v & 0xFF) << 8) | (h & 0xFF);
	}

	public function planeBase():Int {
		return (registers[2] & 0x38) << 10;
	}

	public function planeWidth():Int {
		return switch (registers[16] & 0x03) {
			case 0: 32;
			case 1: 64;
			case _: 128;
		}
	}

	public function planeEntry(column:Int, row:Int):Int {
		return readVram(planeBase() + ((row * planeWidth()) + column) * 2);
	}

	inline function readVram(at:Int):Int {
		final even = at & 0xFFFE;
		return (vram.get(even) << 8) | vram.get(even | 1);
	}

	inline function writeVram(at:Int, value:Int):Void {
		final even = at & 0xFFFE;
		vram.set(even, (value >> 8) & 0xFF);
		vram.set(even | 1, value & 0xFF);
	}

	function store(value:Int):Void {
		switch (code & 0x0F) {
			case 0x01: writeVram(address, value);
			case 0x03:
				cram[(address >> 1) & 63] = value & 0x0EEE;
				colours++;
			case 0x05: vsram[(address >> 1) % vsram.length] = value & 0x07FF;
			case _:
		}
		address = (address + registers[15]) & 0xFFFF;
	}

	function startDma():Void {
		var length = registers[19] | (registers[20] << 8);
		if (length == 0) length = 0x10000;

		if ((registers[23] & 0x80) != 0) {
			if ((registers[23] & 0x40) == 0) filling = true else copyVram(length);
			return;
		}
		transfer(length);
	}

	function transfer(length:Int):Void {
		final bank = (registers[23] & 0x7F) << 17;
		var word = registers[21] | (registers[22] << 8);

		for (i in 0...length) {
			store(memory.readWord(bank | ((word << 1) & 0x1FFFE)));
			word = (word + 1) & 0xFFFF;
		}

		registers[21] = word & 0xFF;
		registers[22] = (word >> 8) & 0xFF;
		registers[19] = 0;
		registers[20] = 0;
	}

	function copyVram(length:Int):Void {
		var source = registers[21] | (registers[22] << 8);

		for (i in 0...length) {
			vram.set(address & 0xFFFF, vram.get(source & 0xFFFF));
			address = (address + registers[15]) & 0xFFFF;
			source = (source + 1) & 0xFFFF;
		}

		registers[21] = source & 0xFF;
		registers[22] = (source >> 8) & 0xFF;
		registers[19] = 0;
		registers[20] = 0;
	}

	function fillVram(value:Int):Void {
		var length = registers[19] | (registers[20] << 8);
		if (length == 0) length = 0x10000;

		filling = false;
		store(value);

		final byte = (value >> 8) & 0xFF;
		for (i in 1...length) {
			vram.set((address ^ 1) & 0xFFFF, byte);
			address = (address + registers[15]) & 0xFFFF;
		}

		registers[19] = 0;
		registers[20] = 0;
	}
}

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

	public static inline final FIFO_DEPTH = 4;

	public static inline final SLOTS_H40 = 210;

	public static inline final SLOTS_H32 = 171;

	static inline final DMA_TRANSFER = 1;

	static inline final DMA_FILL = 2;

	static inline final DMA_COPY = 3;

	public static inline final H_LAST_H40 = 0xB6;

	public static inline final H_RESUME_H40 = 0xE4;

	public static inline final H_LAST_H32 = 0x93;

	public static inline final H_RESUME_H32 = 0xE9;

	public static inline final V_LAST = 0xEA;

	public static inline final V_RESUME = 0xE5;

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

	public final lineWrote:Vector<Int> = new Vector<Int>(LINES_NTSC);
	public final lineLanded:Vector<Int> = new Vector<Int>(LINES_NTSC);
	public final lineCarried:Vector<Int> = new Vector<Int>(LINES_NTSC);
	public final lineStalled:Vector<Int> = new Vector<Int>(LINES_NTSC);
	public final lineDeepest:Vector<Int> = new Vector<Int>(LINES_NTSC);
	public final lineShape:Vector<Int> = new Vector<Int>(LINES_NTSC);

	public var colours(default, null):Int = 0;

	public var spriteOverflow:Bool = false;
	public var spriteCollision:Bool = false;

	public var wide(default, null):Bool = false;
	public var interlace(default, null):Int = 0;

	var showing:Bool = false;
	var slots:Int = SLOTS_H32;
	var vintOn:Bool = false;
	var hintOn:Bool = false;

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

	final fifoCode:Vector<Int> = new Vector<Int>(FIFO_DEPTH);
	final fifoAddress:Vector<Int> = new Vector<Int>(FIFO_DEPTH);
	final fifoValue:Vector<Int> = new Vector<Int>(FIFO_DEPTH);

	public var queued(default, null):Int = 0;
	public var stalledFor(default, null):Int = 0;

	var dmaMode:Int = 0;
	var dmaLeft:Int = 0;
	var dmaWord:Int = 0;
	var dmaBank:Int = 0;
	var dmaByte:Int = 0;
	var dmaFetched:Bool = false;

	var fifoHead:Int = 0;
	var served:Int = 0;

	var atWrote:Int = 0;
	var atLanded:Int = 0;
	var atCarried:Int = 0;
	var atStalled:Int = 0;
	var atDeepest:Int = 0;

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
		for (i in 0...FIFO_DEPTH) {
			fifoCode[i] = 0;
			fifoAddress[i] = 0;
			fifoValue[i] = 0;
		}
		spriteOverflow = false;
		spriteCollision = false;
		decode();
		fifoHead = 0;
		queued = 0;
		stalledFor = 0;
		dmaMode = 0;
		dmaLeft = 0;
		dmaWord = 0;
		dmaBank = 0;
		dmaByte = 0;
		dmaFetched = false;
		served = 0;
		atWrote = 0;
		atLanded = 0;
		atCarried = 0;
		atStalled = 0;
		atDeepest = 0;
		for (i in 0...LINES_NTSC) {
			lineWrote[i] = 0;
			lineLanded[i] = 0;
			lineCarried[i] = 0;
			lineStalled[i] = 0;
			lineDeepest[i] = 0;
			lineShape[i] = 0;
		}
		writes = 0;
		reads = 0;
	}

	public inline function tick(master:Int):Void {
		dot += master;
		if (queued > 0 || dmaMode != 0) drain();

		if (dot >= next) {
			events();
			if (queued > 0 || dmaMode != 0) drain();
		}
	}

	function decode():Void {
		wide = (registers[12] & 0x81) == 0x81;
		slots = wide ? SLOTS_H40 : SLOTS_H32;
		showing = (registers[1] & 0x40) != 0;
		vintOn = (registers[1] & 0x20) != 0;
		hintOn = (registers[0] & 0x10) != 0;

		interlace = switch (registers[12] & 0x06) {
			case 0x02: 1;
			case 0x06: 2;
			case _: 0;
		}
	}

	inline function blanked():Bool {
		return !showing || line >= ACTIVE_LINES;
	}

	public function slotIsExternal(at:Int):Bool {
		return externalSlot(at, wide, blanked());
	}

	public static function externalSlot(at:Int, wide:Bool, open:Bool):Bool {
		if (at < 14) return open;

		final tail = wide ? 174 : 142;

		if (at < tail) {
			final within = (at - 14) % 32;
			if (within == 25) return false;
			return open || within == 1 || within == 9 || within == 17;
		}

		if (open) return true;
		return wide ? (at == 174 || at == 175 || at == 199)
			: (at == 142 || at == 143 || at == 157 || at == 171);
	}

	function drain():Void {
		final total = slots;
		final reached = Std.int(dot * total / MASTER_PER_LINE);
		final now = reached > total ? total : reached;

		while (served < now && (queued > 0 || dmaMode != 0)) {
			served++;
			if (dmaMode == DMA_TRANSFER) feed();
			if (!slotIsExternal(served)) continue;
			if (queued > 0) pop() else step();
		}

		if (served < now) served = now;
	}

	public function transferring():Bool {
		return dmaMode == DMA_TRANSFER;
	}

	public function running():Bool {
		return dmaMode != 0;
	}

	function step():Void {
		switch (dmaMode) {
			case DMA_FILL: fillByte();
			case DMA_COPY: copyByte();
			case _:
		}
	}

	function feed():Void {
		while (queued < FIFO_DEPTH && dmaLeft > 0) {
			enqueue(code, address, memory.readWord(dmaBank | ((dmaWord << 1) & 0x1FFFE)));
			address = (address + registers[15]) & 0xFFFF;
			advanceSource();
			countDown();
		}
	}

	function fillByte():Void {
		atCarried++;
		vram.set((address ^ 1) & 0xFFFF, dmaByte);
		address = (address + registers[15]) & 0xFFFF;
		countDown();
	}

	function copyByte():Void {
		if (!dmaFetched) {
			dmaByte = vram.get(dmaWord & 0xFFFF);
			dmaFetched = true;
			return;
		}

		dmaFetched = false;
		atCarried++;
		vram.set(address & 0xFFFF, dmaByte);
		address = (address + registers[15]) & 0xFFFF;
		advanceSource();
		countDown();
	}

	inline function advanceSource():Void {
		dmaWord = (dmaWord + 1) & 0xFFFF;
		registers[21] = dmaWord & 0xFF;
		registers[22] = (dmaWord >> 8) & 0xFF;
	}

	function countDown():Void {
		dmaLeft--;
		registers[19] = dmaLeft & 0xFF;
		registers[20] = (dmaLeft >> 8) & 0xFF;
		if (dmaLeft <= 0) dmaMode = 0;
	}

	function pop():Void {
		commit(fifoCode[fifoHead], fifoAddress[fifoHead], fifoValue[fifoHead]);
		fifoHead = (fifoHead + 1) % FIFO_DEPTH;
		queued--;
		atLanded++;
	}

	function until():Int {
		final total = slots;
		final last = served + total * 2;
		var at = served;

		while (at < last) {
			at++;
			var index = at;
			while (index >= total) index -= total;
			if (slotIsExternal(index)) break;
		}

		final when = Std.int((at + 1) * MASTER_PER_LINE / total);
		return when > dot ? when - dot : 0;
	}

	inline function enqueue(atCode:Int, at:Int, value:Int):Void {
		final slot = (fifoHead + queued) % FIFO_DEPTH;
		fifoCode[slot] = atCode;
		fifoAddress[slot] = at;
		fifoValue[slot] = value;
		queued++;
		if (queued > atDeepest) atDeepest = queued;
	}

	function push(value:Int):Int {
		var held = 0;

		if (queued == FIFO_DEPTH) {
			held = until();
			pop();
		}

		enqueue(code, address, value);
		stalledFor += held;
		atStalled += held;

		address = (address + registers[15]) & 0xFFFF;
		return held;
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
		lineWrote[line] = atWrote;
		lineLanded[line] = atLanded;
		lineCarried[line] = atCarried;
		lineStalled[line] = atStalled;
		lineDeepest[line] = atDeepest;
		lineShape[line] = (wide ? 2 : 0) | (blanked() ? 1 : 0);

		atWrote = 0;
		atLanded = 0;
		atCarried = 0;
		atStalled = 0;
		atDeepest = 0;

		served = 0;
		line++;
		if (line == ACTIVE_LINES) vint = true;
		if (line >= LINES_NTSC) {
			line = 0;
			frame++;
		}
	}

	public inline function interlaced():Bool {
		return interlace == 2;
	}

	public function irqLevel():Int {
		if (vint && vintOn) return VINT_LEVEL;
		if (hint && hintOn) return HINT_LEVEL;
		return 0;
	}

	public function acknowledge(level:Int):Void {
		if (level == VINT_LEVEL) vint = false else hint = false;
	}

	public function writeControl(value:Int):Void {
		if (!pending && (value & 0xC000) == 0x8000) {
			final index = (value >> 8) & 0x1F;
			if (index < 11 || (registers[1] & 0x04) != 0) registers[index] = value & 0xFF;
			if (index == 0 || index == 1 || index == 12) decode();
			code = code & 0x3C;
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

	public function writeData(value:Int):Int {
		writes++;
		atWrote++;
		pending = false;

		if (filling) return startFill(value);

		return push(value);
	}

	public function readData():Int {
		reads++;
		pending = false;
		final value = switch (code & 0x0F) {
			case 0x00: readVram(address);
			case 0x0C: (exposed() & 0xFF00) | vram.get((address ^ 1) & 0xFFFF);
			case 0x08: (cram[(address >> 1) & 63] & 0x0EEE) | (exposed() & 0xF111);
			case 0x04: (vsram[(address >> 1) % vsram.length] & 0x07FF) | (exposed() & 0xF800);
			case _: 0;
		}
		address = (address + registers[15]) & 0xFFFF;
		return value;
	}

	inline function exposed():Int {
		return fifoValue[(fifoHead + queued) % FIFO_DEPTH];
	}

	public function readStatus():Int {
		reads++;
		pending = false;

		var value = 0x3400 | (queued == 0 ? 0x0200 : 0x0000);
		if (line >= ACTIVE_LINES) value |= 0x0008;
		if (dot >= ACTIVE_TICKS) value |= 0x0004;
		if (vint) value |= 0x0080;
		if (queued == FIFO_DEPTH) value |= 0x0100;
		if (dmaMode != 0) value |= 0x0002;
		if (interlaced() && (frame & 1) != 0) value |= 0x0010;
		if (spriteOverflow) value |= 0x0040;
		if (spriteCollision) value |= 0x0020;

		spriteOverflow = false;
		spriteCollision = false;
		return value;
	}

	public function readCounter():Int {
		reads++;
		final v = line <= V_LAST ? line : line - V_LAST - 1 + V_RESUME;
		return ((v & 0xFF) << 8) | horizontal();
	}

	public function horizontal():Int {
		final last = wide ? H_LAST_H40 : H_LAST_H32;
		final resume = wide ? H_RESUME_H40 : H_RESUME_H32;
		final step = Std.int(dot * countsPerLine() / MASTER_PER_LINE);
		return (step <= last ? step : step - last - 1 + resume) & 0xFF;
	}

	public inline function countsPerLine():Int {
		return wide
			? H_LAST_H40 + 1 + 0x100 - H_RESUME_H40
			: H_LAST_H32 + 1 + 0x100 - H_RESUME_H32;
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
		final swap = (at & 1) != 0;
		vram.set(even, (swap ? value : value >> 8) & 0xFF);
		vram.set(even | 1, (swap ? value >> 8 : value) & 0xFF);
	}

	function commit(atCode:Int, at:Int, value:Int):Void {
		switch (atCode & 0x0F) {
			case 0x01:
				writeVram(at, value);
			case 0x03:
				cram[(at >> 1) & 63] = value & 0x0EEE;
				colours++;
			case 0x05: vsram[(at >> 1) % vsram.length] = value & 0x07FF;
			case _:
		}
	}

	function startDma():Void {
		final length = requested();

		if ((registers[23] & 0x80) != 0) {
			if ((registers[23] & 0x40) == 0) filling = true else startCopy(length);
			return;
		}

		startTransfer(length);
	}

	inline function requested():Int {
		final length = registers[19] | (registers[20] << 8);
		return length == 0 ? 0x10000 : length;
	}

	function startTransfer(length:Int):Void {
		dmaBank = (registers[23] & 0x7F) << 17;
		dmaWord = registers[21] | (registers[22] << 8);
		dmaLeft = length;
		dmaMode = DMA_TRANSFER;
	}

	function startCopy(length:Int):Void {
		dmaWord = registers[21] | (registers[22] << 8);
		dmaLeft = length;
		dmaFetched = false;
		dmaMode = DMA_COPY;
	}

	function startFill(value:Int):Int {
		filling = false;

		final length = requested();
		final held = push(value);

		dmaByte = (value >> 8) & 0xFF;
		dmaLeft = length;
		dmaMode = DMA_FILL;
		return held;
	}
}

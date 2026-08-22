package hxmd.test;

import haxe.ds.IntMap;
import hxmd.cpu.m68k.Bus;
import hxmd.test.SstFormat;

class SstBus implements Bus {
	public var mem:IntMap<Int>;
	public var log:Array<SstTransaction>;
	public var cycles:Int;

	var pendingIdle:Int;

	public function new() {
		mem = new IntMap<Int>();
		log = [];
		cycles = 0;
		pendingIdle = 0;
	}

	public function load(state:SstState):Void {
		mem = new IntMap<Int>();
		for (cell in state.ram) mem.set(cell.addr & 0xFFFFFE, cell.value & 0xFFFF);
		log = [];
		cycles = 0;
		pendingIdle = 0;
	}

	inline function peek(addr:Int):Int {
		final v = mem.get(addr);
		return v == null ? 0 : v;
	}

	function flushIdle():Void {
		if (pendingIdle == 0) return;
		final tr = new SstTransaction();
		tr.kind = Idle;
		tr.cycles = pendingIdle;
		log.push(tr);
		pendingIdle = 0;
	}

	public function idle(n:Int):Void {
		pendingIdle += n;
		cycles += n;
	}

	public function read(addr:Int, fc:Int, uds:Bool, lds:Bool):Int {
		flushIdle();
		cycles += 4;

		final word = peek(addr);
		final data = (uds && lds) ? word : (uds ? (word & 0xFF00) : (word & 0x00FF));

		final tr = new SstTransaction();
		tr.kind = Read;
		tr.cycles = 4;
		tr.fc = fc;
		tr.addr = addr;
		tr.data = data;
		tr.uds = uds ? 1 : 0;
		tr.lds = lds ? 1 : 0;
		log.push(tr);

		return data;
	}

	public function write(addr:Int, fc:Int, data:Int, uds:Bool, lds:Bool):Void {
		flushIdle();
		cycles += 4;

		final old = peek(addr);
		final next = if (uds && lds) data & 0xFFFF
			else if (uds) (old & 0x00FF) | (data & 0xFF00)
			else (old & 0xFF00) | (data & 0x00FF);
		mem.set(addr, next);

		final tr = new SstTransaction();
		tr.kind = Write;
		tr.cycles = 4;
		tr.fc = fc;
		tr.addr = addr;
		tr.data = data & 0xFFFF;
		tr.uds = uds ? 1 : 0;
		tr.lds = lds ? 1 : 0;
		log.push(tr);
	}

	public function faultAccess(read:Bool, addr:Int, fc:Int, data:Int):Int {
		flushIdle();
		cycles += 4;

		final value = read ? peek(addr) : (data & 0xFFFF);

		final tr = new SstTransaction();
		tr.kind = read ? ReadAddressError : WriteAddressError;
		tr.cycles = 4;
		tr.fc = fc;
		tr.addr = addr;
		tr.data = value;
		tr.uds = 1;
		tr.lds = 1;
		log.push(tr);

		return value;
	}

	public function finish():Void {
		flushIdle();
	}
}

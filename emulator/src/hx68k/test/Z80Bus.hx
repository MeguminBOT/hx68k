package hx68k.test;

import haxe.ds.IntMap;
import hx68k.cpu.z80.Bus;
import hx68k.test.Z80Format;

class Z80Bus implements Bus {
	public var memory:IntMap<Int> = new IntMap<Int>();
	public var log:Array<Z80Cycle> = [];
	public var ports:Array<Z80Port> = [];

	public var answers:Array<Int> = [];

	var last:Int = 0;

	public function new() {}

	public function load(state:Z80State, expected:Array<Z80Port>):Void {
		memory = new IntMap<Int>();
		for (cell in state.ram) memory.set(cell.addr, cell.value);

		answers = [];
		for (port in expected) if (!port.write) answers.push(port.value);

		log = [];
		ports = [];
		last = 0;
	}

	public function peek(address:Int):Int {
		final value = memory.get(address & 0xFFFF);
		return value == null ? 0 : value;
	}

	public function fetch(address:Int, refresh:Int):Int {
		emit(address, -1, 0);
		emit(address, -1, Z80Cycle.READ | Z80Cycle.MEMORY);
		final value = peek(address);
		emit(refresh, value, 0);
		emit(refresh, -1, 0);
		return value;
	}

	public function read(address:Int):Int {
		emit(address, -1, 0);
		emit(address, -1, Z80Cycle.READ | Z80Cycle.MEMORY);
		final value = peek(address);
		emit(address, value, 0);
		return value;
	}

	public function write(address:Int, value:Int):Void {
		emit(address, -1, 0);
		emit(address, value, Z80Cycle.WRITE | Z80Cycle.MEMORY);
		memory.set(address & 0xFFFF, value & 0xFF);
		emit(address, -1, 0);
	}

	public function input(port:Int):Int {
		final value = answers.length > 0 ? answers.shift() : 0;

		emit(port, -1, 0);
		emit(port, -1, 0);
		emit(port, -1, Z80Cycle.READ | Z80Cycle.PORT);
		emit(port, value, 0);

		final record = new Z80Port();
		record.address = port;
		record.value = value;
		record.write = false;
		ports.push(record);

		return value;
	}

	public function output(port:Int, value:Int):Void {
		emit(port, -1, 0);
		emit(port, -1, 0);
		emit(port, value, Z80Cycle.WRITE | Z80Cycle.PORT);
		emit(port, -1, 0);

		final record = new Z80Port();
		record.address = port;
		record.value = value;
		record.write = true;
		ports.push(record);
	}

	public function idle(states:Int):Void {
		for (i in 0...states) emit(last, -1, 0);
	}

	function emit(address:Int, value:Int, pins:Int):Void {
		final cycle = new Z80Cycle();
		cycle.address = address & 0xFFFF;
		cycle.value = value < 0 ? 0 : value & 0xFF;
		cycle.pins = pins | Z80Cycle.HAS_ADDRESS | (value < 0 ? 0 : Z80Cycle.HAS_VALUE);
		log.push(cycle);
		last = cycle.address;
	}
}

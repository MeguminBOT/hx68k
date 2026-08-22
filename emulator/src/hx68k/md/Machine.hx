package hx68k.md;

import haxe.io.Bytes;
import haxe.ds.Vector;
import hx68k.cpu.m68k.Bus;
import hx68k.cpu.m68k.M68000;

class Machine implements Bus implements Memory {
	public static inline final MASTER_PER_68K = 7;
	public static inline final RAM_SIZE = 0x10000;
	public static inline final Z80_RAM_SIZE = 0x2000;

	public final cpu:M68000;
	public final vdp:Vdp;
	public final ram:Bytes = Bytes.alloc(RAM_SIZE);
	public final z80Ram:Bytes = Bytes.alloc(Z80_RAM_SIZE);

	public var cycles(default, null):Int = 0;
	public var rom(default, null):Bytes = Bytes.alloc(0);

	final banks:Vector<Int> = new Vector<Int>(8);

	var z80BusRequest:Bool = false;

	public function new() {
		vdp = new Vdp(this);
		cpu = new M68000(this);
		for (i in 0...banks.length) banks[i] = i;
	}

	public function load(path:String):Void {
		rom = sys.io.File.getBytes(path);
		reset();
	}

	public function reset():Void {
		ram.fill(0, ram.length, 0);
		z80Ram.fill(0, z80Ram.length, 0);
		for (i in 0...banks.length) banks[i] = i;

		z80BusRequest = false;
		cycles = 0;

		vdp.reset();
		cpu.reset();
	}

	public function runFrame():Void {
		final target = vdp.frame + 1;
		while (vdp.frame != target) step();
	}

	public function step():Void {
		cpu.step();

		final level = vdp.irqLevel();
		if (level > cpu.imask) {
			vdp.acknowledge(level);
			cpu.interrupt(level);
		}
	}

	public function idle(n:Int):Void {
		advance(n);
	}

	public function read(addr:Int, fc:Int, uds:Bool, lds:Bool):Int {
		advance(4);
		final word = readWord(addr);
		return uds && lds ? word : (uds ? word & 0xFF00 : word & 0x00FF);
	}

	public function write(addr:Int, fc:Int, data:Int, uds:Bool, lds:Bool):Void {
		advance(4);
		store(addr & 0xFFFFFE, data & 0xFFFF, uds, lds);
	}

	public function faultAccess(read:Bool, addr:Int, fc:Int, data:Int):Int {
		advance(4);
		return 0xFFFF;
	}

	inline function advance(n:Int):Void {
		cycles += n;
		vdp.tick(n * MASTER_PER_68K);
	}

	public function readWord(address:Int):Int {
		final at = address & 0xFFFFFE;

		if (at < 0x400000) return cartridge(at);
		if (at >= 0xE00000) return ramWord(at);
		if (at >= 0xC00000) return vdpRead(at);

		if (at >= 0xA00000 && at < 0xA04000) {
			final z = at & 0x1FFE;
			return (z80Ram.get(z) << 8) | z80Ram.get(z | 1);
		}
		if (at >= 0xA04000 && at < 0xA06000) return 0x0000;
		if (at >= 0xA10000 && at < 0xA10020) {
			final value = io(at);
			return (value << 8) | value;
		}
		if (at >= 0xA11100 && at < 0xA11200) return z80BusRequest ? 0x0000 : 0x0100;

		return 0xFFFF;
	}

	function store(at:Int, value:Int, uds:Bool, lds:Bool):Void {
		if (at >= 0xE00000) {
			final r = at & 0xFFFF;
			if (uds) ram.set(r, (value >> 8) & 0xFF);
			if (lds) ram.set(r | 1, value & 0xFF);
			return;
		}

		if (at >= 0xC00000) {
			vdpWrite(at, both(value, uds, lds));
			return;
		}

		if (at >= 0xA00000 && at < 0xA04000) {
			final z = at & 0x1FFE;
			if (uds) z80Ram.set(z, (value >> 8) & 0xFF);
			if (lds) z80Ram.set(z | 1, value & 0xFF);
			return;
		}

		if (at >= 0xA11100 && at < 0xA11200) {
			z80BusRequest = (both(value, uds, lds) & 0x0100) != 0;
			return;
		}

		if (at >= 0xA130F0 && at < 0xA13100) {
			final index = ((at | 1) & 0x0F) >> 1;
			if (index > 0) banks[index] = (value & 0x3F);
			return;
		}
	}

	inline function both(value:Int, uds:Bool, lds:Bool):Int {
		if (uds && lds) return value;
		final byte = uds ? (value >> 8) & 0xFF : value & 0xFF;
		return (byte << 8) | byte;
	}

	inline function ramWord(at:Int):Int {
		final r = at & 0xFFFF;
		return (ram.get(r) << 8) | ram.get(r | 1);
	}

	inline function cartridge(at:Int):Int {
		final mapped = (banks[at >> 19] << 19) | (at & 0x7FFFE);
		return mapped + 1 < rom.length ? (rom.get(mapped) << 8) | rom.get(mapped + 1) : 0xFFFF;
	}

	function vdpRead(at:Int):Int {
		final port = at & 0x1F;
		if (port < 0x04) return vdp.readData();
		if (port < 0x08) return vdp.readStatus();
		if (port < 0x10) return vdp.readCounter();
		return 0x0000;
	}

	function vdpWrite(at:Int, value:Int):Void {
		final port = at & 0x1F;
		if (port < 0x04) vdp.writeData(value);
		else if (port < 0x08) vdp.writeControl(value);
	}

	function io(at:Int):Int {
		return switch (at & 0x1F) {
			case 0x00, 0x01: 0xA0;
			case 0x02, 0x03, 0x04, 0x05, 0x06, 0x07: 0x7F;
			case _: 0x00;
		}
	}
}

package hx68k.md;

import haxe.io.Bytes;
import hx68k.cpu.z80.Bus;

@:allow(hx68k.md.Savestate)
class Z80Bus implements Bus {
	public var states(default, null):Int = 0;

	public var soundWrites(default, null):Int = 0;

	public final ram:Bytes;

	final machine:Machine;

	var bank:Int = 0;

	public function new(machine:Machine, ram:Bytes) {
		this.machine = machine;
		this.ram = ram;
	}

	public function reset():Void {
		states = 0;
		soundWrites = 0;
		bank = 0;
	}

	public function fetch(address:Int, refresh:Int):Int {
		states += 4;
		return peek(address);
	}

	public function read(address:Int):Int {
		states += 3;
		return peek(address);
	}

	public function write(address:Int, value:Int):Void {
		states += 3;
		poke(address, value);
	}

	public function input(port:Int):Int {
		states += 4;
		return 0xFF;
	}

	public function output(port:Int, value:Int):Void {
		states += 4;
	}

	public function idle(count:Int):Void {
		states += count;
	}

	function peek(address:Int):Int {
		final at = address & 0xFFFF;

		if (at < 0x4000) return ram.get(at & 0x1FFF);
		if (at < 0x6000) return machine.sound.ym.read();
		if (at >= 0x8000) {
			states += machine.tookBus();
			return machine.readWord(window(at)) >> ((at & 1) == 0 ? 8 : 0) & 0xFF;
		}

		return 0xFF;
	}

	function poke(address:Int, value:Int):Void {
		final at = address & 0xFFFF;

		if (at < 0x4000) {
			ram.set(at & 0x1FFF, value & 0xFF);
			return;
		}

		if (at >= 0x6000 && at < 0x6100) {
			bank = ((bank >> 1) | ((value & 1) << 8)) & 0x1FF;
			return;
		}

		if (at >= 0x4000 && at < 0x6000) {
			soundWrites++;
			machine.sound.ym.write(at & 3, value);
			return;
		}

		if (at >= 0x7F00 && at < 0x8000) {
			if ((at & 0x1F) == 0x11) soundWrites++;
			machine.writeByte(0xC00000 | (at & 0x1F), value);
			return;
		}
	}

	inline function window(at:Int):Int {
		return ((bank << 15) | (at & 0x7FFF)) & 0xFFFFFF;
	}
}

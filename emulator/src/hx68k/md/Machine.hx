package hx68k.md;

import haxe.io.Bytes;
import haxe.ds.Vector;
import hx68k.cpu.m68k.Bus;
import hx68k.cpu.m68k.M68000;
import hx68k.cpu.z80.Z80;

@:allow(hx68k.md.Savestate)
class Machine implements Bus implements Memory {
	public static inline final MASTER_PER_68K = 7;
	public static inline final MASTER_PER_Z80 = 15;
	public static inline final RAM_SIZE = 0x10000;
	public static inline final Z80_RAM_SIZE = 0x2000;

	public final cpu:M68000;
	public final z80:Z80;
	public final z80Bus:Z80Bus;
	public final vdp:Vdp;
	public final sound:Sound = new Sound();
	public final ram:Bytes = Bytes.alloc(RAM_SIZE);
	public final z80Ram:Bytes = Bytes.alloc(Z80_RAM_SIZE);

	public static inline final EVERY = 128;
	public static inline final STOLEN = 2;

	public static inline final HOLDS_68K = 11;
	public static inline final HOLDS_Z80_TENTHS = 33;

	public var cycles(default, null):Int = 0;

	var counted:Int = 0;
	var owed:Bool = false;

	public var heldByZ80:Int = 0;

	public var z80Tenths:Int = 0;
	public var interrupts(default, null):Int = 0;
	public var rom(default, null):Bytes = Bytes.alloc(0);

	public var save(default, null):Bytes = Bytes.alloc(0);
	public var saveFrom(default, null):Int = 0;
	public var saveTo(default, null):Int = -1;
	public var saveOn:Bool = false;
	public var saveLocked:Bool = false;

	public final buttons:Vector<Int> = new Vector<Int>(3);

	final banks:Vector<Int> = new Vector<Int>(8);
	final padControl:Vector<Int> = new Vector<Int>(3);
	final padData:Vector<Int> = new Vector<Int>(3);

	var z80BusRequest:Bool = false;
	var z80Running:Bool = false;
	var z80Master:Int = 0;
	var z80Pending:Bool = false;

	var z80Hold:Int = 0;

	public var z80Raised(default, null):Int = 0;
	public var z80Taken(default, null):Int = 0;
	public var z80Dropped(default, null):Int = 0;
	var lastLine:Int = 0;

	public function new() {
		vdp = new Vdp(this);
		cpu = new M68000(this);
		z80Bus = new Z80Bus(this, z80Ram);
		z80 = new Z80(z80Bus);
		for (i in 0...banks.length) banks[i] = i;
		for (i in 0...buttons.length) buttons[i] = 0;
	}

	public static inline final SAVE_AT = 0x1B0;

	public static inline final SAVE_CONTROL = 0xA130F1;

	public static inline final REGION_AT = 0x1F0;
	public static inline final REGION_LENGTH = 16;

	public function load(path:String):Void {
		insert(sys.io.File.getBytes(path));
	}

	public function insert(cartridge:Bytes):Void {
		rom = cartridge;
		declaredSave();
		vdp.standard(palByHeader(rom));
		sound.standard(vdp.masterHz);
		reset();
	}

	function declaredSave():Void {
		saveFrom = 0;
		saveTo = -1;
		saveOn = false;
		saveLocked = false;
		save = Bytes.alloc(0);

		if (rom.length < SAVE_AT + 12) return;
		if (rom.get(SAVE_AT) != "R".code || rom.get(SAVE_AT + 1) != "A".code) return;

		final from = long(SAVE_AT + 4);
		final to = long(SAVE_AT + 8);
		if (to < from || from < 0x200000 || to > 0x3FFFFF) return;

		saveFrom = from & 0xFFFFFE;
		saveTo = to | 1;
		save = Bytes.alloc(saveTo - saveFrom + 1);
	}

	inline function long(at:Int):Int {
		return (rom.get(at) << 24) | (rom.get(at + 1) << 16) | (rom.get(at + 2) << 8) | rom.get(at + 3);
	}

	inline function saving(at:Int):Bool {
		return saveOn && at >= saveFrom && at < saveTo;
	}

	public static function palByHeader(rom:Bytes):Bool {
		if (rom.length < REGION_AT + REGION_LENGTH) return false;

		var europe = false;
		var elsewhere = false;

		for (i in 0...REGION_LENGTH) {
			switch (rom.get(REGION_AT + i)) {
				case "E".code, "e".code, "8".code: europe = true;
				case "J".code, "j".code, "U".code, "u".code, "1".code, "4".code: elsewhere = true;
				case _:
			}
		}

		return europe && !elsewhere;
	}

	public function reset():Void {
		sound.reset();
		z80Pending = false;
		z80Hold = 0;
		lastLine = 0;
		ram.fill(0, ram.length, 0);
		z80Ram.fill(0, z80Ram.length, 0);
		for (i in 0...banks.length) banks[i] = i;

		saveOn = false;
		saveLocked = false;

		z80BusRequest = false;
		z80Running = false;
		z80Master = 0;
		cycles = 0;

		z80Bus.reset();
		z80.pc = 0;
		z80.sp = 0;
		z80.i = 0;
		z80.r = 0;
		z80.iff1 = false;
		z80.iff2 = false;
		z80.im = 0;
		z80.halted = false;

		for (i in 0...padControl.length) {
			padControl[i] = 0;
			padData[i] = 0;
		}

		vdp.reset();
		cpu.reset();
	}

	public function runFrame():Void {
		final target = vdp.frame + 1;
		while (vdp.frame != target) step();
	}

	public function step():Void {
		cpu.step();

		if (vdp.line != lastLine) {
			if (vdp.line == vdp.activeLines) {
				z80Pending = true;
				z80Hold = Vdp.MASTER_PER_LINE;
				z80Raised++;
			}
			lastLine = vdp.line;
		}

		final level = vdp.irqLevel();
		if (level > cpu.imask) {
			vdp.acknowledge(level);
			cpu.interrupt(level);
			interrupts++;
		}
	}

	public function idle(n:Int):Void {
		advance(n);
	}

	public function read(addr:Int, fc:Int, uds:Bool, lds:Bool):Int {
		advance(4 + stolen());
		final word = readWord(addr);
		return uds && lds ? word : (uds ? word & 0xFF00 : word & 0x00FF);
	}

	public function write(addr:Int, fc:Int, data:Int, uds:Bool, lds:Bool):Void {
		final at = addr & 0xFFFFFE;
		final toVdp = at >= 0xC00000 && at < 0xE00000;

		advance(4 + (toVdp ? 0 : stolen()));

		if (toVdp && (at & 0x1F) < 0x04) {
			final held = vdp.holdFor();
			if (held > 0) advance(Std.int((held + MASTER_PER_68K - 1) / MASTER_PER_68K));
		}

		store(at, data & 0xFFFF, uds, lds);
		while (vdp.transferring()) advance(1);
	}

	public function faultAccess(read:Bool, addr:Int, fc:Int, data:Int):Int {
		advance(4);
		return 0xFFFF;
	}

	public var audible:Bool = true;

	inline function stolen():Int {
		var n = 0;

		if (owed) {
			owed = false;
			n += STOLEN;
		}

		if (heldByZ80 > 0) {
			n += heldByZ80;
			heldByZ80 = 0;
		}

		return n;
	}

	public function tookBus():Int {
		heldByZ80 += HOLDS_68K;

		z80Tenths += HOLDS_Z80_TENTHS;
		final waited = Std.int(z80Tenths / 10);
		z80Tenths -= waited * 10;
		return waited;
	}

	inline function advance(n:Int):Void {
		counted += n;
		while (counted >= EVERY) {
			counted -= EVERY;
			owed = true;
		}

		cycles += n;
		final master = n * MASTER_PER_68K;
		vdp.tick(master);
		if (audible) sound.tick(master);
		runZ80(master);
	}

	public var stoppedFor(default, null):Int = 0;
	public var requestedFor(default, null):Int = 0;
	public var haltedFor(default, null):Int = 0;

	function runZ80(master:Int):Void {
		z80Master += master;

		if (z80Pending) {
			z80Hold -= master;
			if (z80Hold <= 0) {
				z80Pending = false;
				z80Dropped++;
			}
		}

		if (!z80Running || z80BusRequest) {
			if (z80Running) requestedFor += master; else stoppedFor += master;
			if (z80Master > MASTER_PER_Z80) z80Master = MASTER_PER_Z80;
			return;
		}

		while (z80Master >= MASTER_PER_Z80) {
			if (z80Pending) {
				final before = z80Bus.states;
				if (z80.interrupt()) {
					z80Pending = false;
					z80Taken++;
					z80Master -= (z80Bus.states - before) * MASTER_PER_Z80;
					continue;
				}
			}

			if (z80.halted) {
				haltedFor += z80Master;
				z80Master = 0;
				return;
			}

			final before = z80Bus.states;
			z80.step();
			z80Master -= (z80Bus.states - before) * MASTER_PER_Z80;
		}
	}

	public function readWord(address:Int):Int {
		final at = address & 0xFFFFFE;

		if (at < 0x400000) {
			if (saving(at)) {
				final base = at - saveFrom;
				return (save.get(base) << 8) | save.get(base + 1);
			}
			return cartridge(at);
		}
		if (at >= 0xE00000) return ramWord(at);
		if (at >= 0xC00000) return vdpRead(at);

		if (at >= 0xA00000 && at < 0xA04000) {
			final z = at & 0x1FFE;
			return (z80Ram.get(z) << 8) | z80Ram.get(z | 1);
		}
		if (at >= 0xA04000 && at < 0xA06000) {
			final answer = sound.ym.read();
			return (answer << 8) | answer;
		}
		if (at >= 0xA10000 && at < 0xA10020) {
			final value = io(at);
			return (value << 8) | value;
		}
		if (at >= 0xA11100 && at < 0xA11200) return z80BusRequest ? 0x0000 : 0x0100;

		return 0xFFFF;
	}

	function store(at:Int, value:Int, uds:Bool, lds:Bool):Int {
		if (at >= 0xE00000) {
			final r = at & 0xFFFF;
			if (uds) ram.set(r, (value >> 8) & 0xFF);
			if (lds) ram.set(r | 1, value & 0xFF);
			return 0;
		}

		if (at >= 0xC00000) return vdpWrite(at, both(value, uds, lds));

		if (at >= 0xA00000 && at < 0xA04000) {
			final z = at & 0x1FFE;
			if (uds) z80Ram.set(z, (value >> 8) & 0xFF);
			if (lds) z80Ram.set(z | 1, value & 0xFF);
			return 0;
		}

		if (at >= 0xA04000 && at < 0xA06000) {
			final port = at & 2;
			if (uds) sound.writeYm(port, (value >> 8) & 0xFF);
			if (lds) sound.writeYm(port | 1, value & 0xFF);
			return 0;
		}

		if (at >= 0xA11100 && at < 0xA11200) {
			z80BusRequest = (both(value, uds, lds) & 0x0100) != 0;
			return 0;
		}

		if (at >= 0xA13000 && at < 0xA13100) {
			if ((at | 1) == SAVE_CONTROL && lds && save.length > 0) {
				final control = value & 0xFF;
				saveOn = (control & 1) != 0;
				saveLocked = (control & 2) != 0;
			}
			return 0;
		}

		if (at < 0x400000) {
			if (saving(at) && !saveLocked) {
				final base = at - saveFrom;
				if (uds) save.set(base, (value >> 8) & 0xFF);
				if (lds) save.set(base + 1, value & 0xFF);
			}
			return 0;
		}

		if (at >= 0xA11200 && at < 0xA11300) {
			final released = (both(value, uds, lds) & 0x0100) != 0;
			if (!released) {
				z80Running = false;
				z80.pc = 0;
				z80.sp = 0;
				z80.i = 0;
				z80.r = 0;
				z80.iff1 = false;
				z80.iff2 = false;
				z80.im = 0;
				z80.halted = false;
				z80Bus.reset();
			} else if (!z80Running) {
				z80Running = true;
				z80Master = 0;
			}
			return 0;
		}

		if (at >= 0xA10000 && at < 0xA10020) {
			final offset = at & 0x1F;
			final byte = both(value, uds, lds) & 0xFF;
			if (offset >= 2 && offset <= 6) {
				final port = (offset >> 1) - 1;
				final was = trigger(port);
				padData[port] = byte;
				if (!was && trigger(port)) vdp.trigger();
			} else if (offset >= 8 && offset <= 12) {
				final port = (offset >> 1) - 4;
				final was = trigger(port);
				padControl[port] = byte;
				if (!was && trigger(port)) vdp.trigger();
			}
			return 0;
		}

		if (at >= 0xA130F0 && at < 0xA13100) {
			final index = ((at | 1) & 0x0F) >> 1;
			if (index > 0) banks[index] = (value & 0x3F);
		}

		return 0;
	}

	public function writeByte(address:Int, value:Int):Void {
		final at = address & 0xFFFFFE;
		final odd = (address & 1) != 0;
		store(at, odd ? value & 0xFF : (value & 0xFF) << 8, !odd, odd);
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

	function vdpWrite(at:Int, value:Int):Int {
		final port = at & 0x1F;
		if (port < 0x04) vdp.writeData(value);
		else if (port < 0x08) vdp.writeControl(value);
		else if (port >= 0x10 && port < 0x18) sound.writePsg(value);
		return 0;
	}

	function io(at:Int):Int {
		final offset = at & 0x1F;
		if (offset <= 1) return vdp.pal ? 0xE0 : 0xA0;
		if (offset >= 2 && offset <= 6) return pad((offset >> 1) - 1);
		if (offset >= 8 && offset <= 12) return padControl[(offset >> 1) - 4];
		return 0x00;
	}

	function trigger(port:Int):Bool {
		return (padControl[port] & 0x40) != 0 ? (padData[port] & 0x40) != 0 : true;
	}

	function pad(port:Int):Int {
		final control = padControl[port];
		final high = (control & 0x40) != 0 ? (padData[port] & 0x40) != 0 : true;
		final released = ~buttons[port];
		final lines = high ? released & 0x3F : (released & 0x03) | (((released >> 6) & 0x03) << 4);
		return (((lines | 0x40) & ~control) | (padData[port] & control)) & 0x7F;
	}
}

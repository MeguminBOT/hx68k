package hxres.music;

#if (macro || md_runtime)
class Ym2612 {
	static final DUALS:Array<Array<Int>> = [
		[0x24, 0x25], [0xA4, 0xA0], [0xA5, 0xA1], [0xA6, 0xA2], [0xAC, 0xA8], [0xAD, 0xA9],
		[0xAE, 0xAA]
	];

	final registers:Array<Array<Int>>;
	final init:Array<Array<Bool>>;

	public function new() {
		registers = [for (_ in 0...2) [for (_ in 0...0x100) -1]];
		init = [for (_ in 0...2) [for (_ in 0...0x100) false]];
	}

	public function copy():Ym2612 {
		final out = new Ym2612();
		for (port in 0...2) {
			for (register in 0...0x100) {
				out.registers[port][register] = registers[port][register];
				out.init[port][register] = init[port][register];
			}
		}
		return out;
	}

	public function initialize():Void {
		for (port in 0...2) {
			for (register in 0...0x100) {
				registers[port][register] = register < 0x20 ? 0 : 0xFF;
				init[port][register] = true;
			}
		}
	}

	public static function canIgnore(port:Int, register:Int):Bool {
		switch (register) {
			case 0x22 | 0x24 | 0x25 | 0x26 | 0x27 | 0x28 | 0x2B: return port == 1;
			case _:
		}
		if (register >= 0x30 && register < 0xB8) return (register & 3) == 3;
		return true;
	}

	public static function dualOf(register:Int):Array<Int> {
		for (dual in DUALS) if (dual[0] == register || dual[1] == register) return dual;
		return null;
	}

	public function get(port:Int, register:Int):Int {
		if (canIgnore(port, register)) return 0;
		return registers[port][register];
	}

	public function set(port:Int, register:Int, value:Int):Bool {
		if (canIgnore(port, register)) return false;

		var written:Int = value;

		if (port == 0) {
			if (register == 0x28) {
				final held:Int = registers[port][value & 7];
				written &= 0xF0;
				if (held != written) {
					registers[port][value & 7] = written;
					return true;
				}
				return false;
			}
			if (register == 0x27) written &= 0xC0;
		}

		registers[port][register] = written;
		init[port][register] = true;
		return false;
	}

	function isSame(state:Ym2612, port:Int, register:Int):Bool {
		if (!init[port][register] && !state.init[port][register]) return true;
		return (init[port][register] || canIgnore(port, register))
			&& get(port, register) == state.get(port, register);
	}

	inline function isDiff(state:Ym2612, port:Int, register:Int):Bool {
		return !isSame(state, port, register);
	}

	public function delta(state:Ym2612):Array<VgmCommand> {
		final out = new Array<VgmCommand>();

		for (dual in DUALS) {
			final first:Int = dual[0];
			final second:Int = dual[1];

			if (isDiff(state, 0, first) || isDiff(state, 0, second)) {
				out.push(VgmCommand.ym(0, first, state.get(0, first)));
				out.push(VgmCommand.ym(0, second, state.get(0, second)));
			}

			if (first > 0x30 && (isDiff(state, 1, first) || isDiff(state, 1, second))) {
				out.push(VgmCommand.ym(1, first, state.get(1, first)));
				out.push(VgmCommand.ym(1, second, state.get(1, second)));
			}
		}

		for (port in 0...2) {
			for (register in 0...0x100) {
				if (canIgnore(port, register) || (port == 0 && register == 0x28)) continue;
				if (dualOf(register) != null) continue;
				if (isDiff(state, port, register))
					out.push(VgmCommand.ym(port, register, state.get(port, register)));
			}
		}

		return out;
	}
}
#end

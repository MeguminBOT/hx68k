package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;

class Psg {
	final registers:Array<Array<Int>>;
	final init:Array<Array<Bool>>;
	var index:Int;
	var type:Int;

	public function new() {
		registers = [for (_ in 0...4) [-1, -1]];
		init = [for (_ in 0...4) [false, false]];
		index = -1;
		type = -1;
	}

	public function copy():Psg {
		final out = new Psg();
		for (i in 0...4) {
			out.registers[i][0] = registers[i][0];
			out.registers[i][1] = registers[i][1];
			out.init[i][0] = init[i][0];
			out.init[i][1] = init[i][1];
		}
		return out;
	}

	public function get(where:Int, kind:Int):Int {
		return switch (kind) {
			case 0: where == 3 ? registers[where][kind] & 0x7 : registers[where][kind] & 0x3FF;
			case 1: registers[where][kind] & 0xF;
			case _: 0;
		}
	}

	public function write(value:Int):Void {
		if ((value & 0x80) != 0) writeLow(value & 0x7F);
		else writeHigh(value & 0x7F);
	}

	function writeLow(value:Int):Void {
		index = (value >> 5) & 0x03;
		type = (value >> 4) & 0x01;

		if (type == 0 && index == 3) {
			registers[index][type] &= ~0x7;
			registers[index][type] |= value & 0x7;
		} else {
			registers[index][type] &= ~0xF;
			registers[index][type] |= value & 0xF;
		}
		init[index][type] = true;
	}

	function writeHigh(value:Int):Void {
		if (index < 0 || type < 0) return;

		if (type == 0 && index == 3) {
			registers[index][type] &= ~0x7;
			registers[index][type] |= value & 0x7;
		} else if (type == 1) {
			registers[index][type] &= ~0xF;
			registers[index][type] |= value & 0xF;
		} else {
			registers[index][type] &= ~0x3F0;
			registers[index][type] |= (value & 0x3F) << 4;
		}
		init[index][type] = true;
	}

	function isSame(state:Psg, where:Int, kind:Int):Bool {
		if (!init[where][kind] && !state.init[where][kind]) return true;
		return init[where][kind] && state.get(where, kind) == get(where, kind);
	}

	function isLowSame(state:Psg, where:Int, kind:Int):Bool {
		if (!init[where][kind] && !state.init[where][kind]) return true;
		return init[where][kind] && (state.get(where, kind) & 0xF) == (get(where, kind) & 0xF);
	}

	function isHighSame(state:Psg, where:Int, kind:Int):Bool {
		if (!init[where][kind] && !state.init[where][kind]) return true;
		return init[where][kind] && (state.get(where, kind) & 0x3F0) == (get(where, kind) & 0x3F0);
	}

	inline function isDiff(state:Psg, where:Int, kind:Int):Bool {
		return !isSame(state, where, kind);
	}

	inline function isLowDiffOnly(state:Psg, where:Int, kind:Int):Bool {
		return !isLowSame(state, where, kind) && isHighSame(state, where, kind);
	}

	static function lowWrite(where:Int, kind:Int, value:Int):VgmCommand {
		final held = Bytes.alloc(2);
		held.set(0, VgmCommand.WRITE_SN76489);
		held.set(1, 0x80 | (where << 5) | (kind << 4) | (value & 0xF));
		return VgmCommand.read(held, 0, -1);
	}

	static function fullWrite(where:Int, kind:Int, value:Int):Array<VgmCommand> {
		final out = [lowWrite(where, kind, value)];
		if (kind == 0 && where != 3) {
			final held = Bytes.alloc(2);
			held.set(0, VgmCommand.WRITE_SN76489);
			held.set(1, (value >> 4) & 0x3F);
			out.push(VgmCommand.read(held, 0, -1));
		}
		return out;
	}

	public function delta(state:Psg):Array<VgmCommand> {
		final out = new Array<VgmCommand>();
		for (where in 0...4) {
			for (kind in 0...2) {
				if (kind == 0) {
					if (isLowDiffOnly(state, where, kind))
						out.push(lowWrite(where, kind, state.get(where, kind)));
					else if (isDiff(state, where, kind))
						for (c in fullWrite(where, kind, state.get(where, kind))) out.push(c);
				} else if (isDiff(state, where, kind)) {
					for (c in fullWrite(where, kind, state.get(where, kind))) out.push(c);
				}
			}
		}
		return out;
	}
}
#end

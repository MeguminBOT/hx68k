package hx68k.debug;

import hx68k.md.Machine;

class MachineCode implements Code {
	final machine:Machine;

	public function new(machine:Machine) {
		this.machine = machine;
	}

	public function word(address:Int):Int {
		final at = address & 0xFFFFFE;
		if (at < 0x400000 || at >= 0xE00000) return machine.readWord(at);
		return 0xFFFF;
	}
}

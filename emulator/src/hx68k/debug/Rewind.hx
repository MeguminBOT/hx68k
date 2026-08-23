package hx68k.debug;

import haxe.io.Bytes;
import hx68k.md.Machine;
import hx68k.md.Savestate;

class Rewind {
	public final machine:Machine;
	public final capacity:Int;

	public var depth(default, null):Int = 0;

	final ring:Array<Bytes>;

	var next:Int = 0;

	public function new(machine:Machine, capacity:Int = 60) {
		this.machine = machine;
		this.capacity = capacity;
		this.ring = [for (_ in 0...capacity) null];
	}

	public function frame():Void {
		ring[next] = Savestate.of(machine);
		next = (next + 1) % capacity;
		if (depth < capacity) depth++;
		machine.runFrame();
	}

	public function back(frames:Int):Bool {
		if (frames < 1 || frames > depth) return false;

		final index = ((next - frames) % capacity + capacity) % capacity;
		Savestate.into(machine, ring[index]);
		next = index;
		depth -= frames;
		return true;
	}
}

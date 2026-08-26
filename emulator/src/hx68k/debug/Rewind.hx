package hx68k.debug;

import haxe.io.Bytes;
import hx68k.md.Machine;
import hx68k.md.Savestate;

class Rewind {
	public final machine:Machine;
	public final capacity:Int;

	public var depth(default, null):Int = 0;
	public var at(default, null):Int = 0;

	final ring:Array<Bytes>;

	var head:Int = 0;

	public function new(machine:Machine, capacity:Int = 60) {
		this.machine = machine;
		this.capacity = capacity;
		this.ring = [for (_ in 0...capacity) null];
	}

	public function frame():Void {
		if (at > 0) {
			depth -= at;
			at = 0;
		}

		machine.runFrame();
		record();
	}

	public function back(frames:Int):Bool {
		return seek(at + frames);
	}

	public function forward(frames:Int):Bool {
		return seek(at - frames);
	}

	public function seek(position:Int):Bool {
		if (position < 0 || position >= depth) return false;
		if (position == at) return true;

		Savestate.into(machine, ring[index(position)]);
		at = position;
		return true;
	}

	public function behind():Int {
		return depth - 1 - at;
	}

	function record():Void {
		if (depth < capacity) {
			ring[(head + depth) % capacity] = Savestate.of(machine);
			depth++;
			return;
		}

		ring[head] = Savestate.of(machine);
		head = (head + 1) % capacity;
	}

	inline function index(position:Int):Int {
		return (head + depth - 1 - position) % capacity;
	}
}

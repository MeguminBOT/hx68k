package hx68k.md;

import haxe.ds.Vector;

class Sound {
	public static inline final RATE = 44100;

	static inline final ROOM = 2205;

	public final psg:Psg = new Psg();

	public var lost(default, null):Int = 0;

	final ring:Vector<Int> = new Vector<Int>(ROOM);

	var head:Int = 0;
	var tail:Int = 0;
	var held:Int = 0;

	var psgClocks:Float = 0;
	var samples:Float = 0;

	public function new() {}

	public function reset():Void {
		psg.reset();
		head = 0;
		tail = 0;
		held = 0;
		lost = 0;
		psgClocks = 0;
		samples = 0;
	}

	public function tick(master:Int):Void {
		psgClocks += master / 15.0;
		final whole = Std.int(psgClocks);
		if (whole > 0) {
			psg.run(whole);
			psgClocks -= whole;
		}

		samples += master * RATE / Vdp.MASTER_HZ;
		while (samples >= 1) {
			samples -= 1;
			put(psg.sample());
		}
	}

	public function ready():Int {
		return held;
	}

	public function take(into:Vector<Int>, count:Int):Int {
		final given = count < held ? count : held;

		for (i in 0...given) {
			into[i] = ring[tail];
			tail = (tail + 1) % ROOM;
		}

		held -= given;
		return given;
	}

	inline function put(sample:Int):Void {
		if (held == ROOM) {
			tail = (tail + 1) % ROOM;
			held--;
			lost++;
		}

		ring[head] = sample;
		head = (head + 1) % ROOM;
		held++;
	}
}

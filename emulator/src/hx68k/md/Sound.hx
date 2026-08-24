package hx68k.md;

import haxe.ds.Vector;

class Sound {
	public static inline final RATE = 44100;

	static inline final ROOM = 11025;

	static inline final WANTED = 384;

	static inline final BEND = 0.004;

	static inline final COUPLING = 0.9975;

	public final psg:Psg = new Psg();
	public final ym:Ym2612 = new Ym2612();

	public var lost(default, null):Int = 0;

	public var bend(default, null):Float = 1;

	final ring:Vector<Int> = new Vector<Int>(ROOM * 2);

	var head:Int = 0;
	var tail:Int = 0;
	var held:Int = 0;

	var psgClocks:Float = 0;
	var ymClocks:Float = 0;
	var ymSpare:Int = 0;
	var samples:Float = 0;

	var fmLeft:Int = 0;
	var fmRight:Int = 0;
	var olderLeft:Int = 0;
	var olderRight:Int = 0;

	var wentLeft:Int = 0;
	var wentRight:Int = 0;
	var heldLeft:Float = 0;
	var heldRight:Float = 0;

	public function new() {}

	public function reset():Void {
		psg.reset();
		ym.reset();
		ymClocks = 0;
		ymSpare = 0;
		fmLeft = 0;
		fmRight = 0;
		olderLeft = 0;
		olderRight = 0;
		head = 0;
		tail = 0;
		held = 0;
		lost = 0;
		psgClocks = 0;
		samples = 0;
		bend = 1;
		wentLeft = 0;
		wentRight = 0;
		heldLeft = 0;
		heldRight = 0;
	}

	public function tick(master:Int):Void {
		psgClocks += master / 15.0;
		final whole = Std.int(psgClocks);
		if (whole > 0) {
			psg.run(whole);
			psgClocks -= whole;
		}

		ymClocks += master / 7.0;
		final ymWhole = Std.int(ymClocks);
		if (ymWhole > 0) {
			ymClocks -= ymWhole;

			ymSpare += ymWhole;
			while (ymSpare >= Ym2612.PER_SAMPLE) {
				ymSpare -= Ym2612.PER_SAMPLE;
				ym.sample();
				olderLeft = fmLeft;
				olderRight = fmRight;
				fmLeft = ym.left;
				fmRight = ym.right;
			}
		}

		samples += master * RATE * bend / Vdp.MASTER_HZ;
		if (samples < 1) return;

		final at = ymSpare;
		final left = olderLeft + Std.int(((fmLeft - olderLeft) * at) / Ym2612.PER_SAMPLE);
		final right = olderRight + Std.int(((fmRight - olderRight) * at) / Ym2612.PER_SAMPLE);

		final other = psg.taken();

		final mixedLeft = left + other;
		final mixedRight = right + other;

		heldLeft = (mixedLeft - wentLeft) + COUPLING * heldLeft;
		heldRight = (mixedRight - wentRight) + COUPLING * heldRight;
		wentLeft = mixedLeft;
		wentRight = mixedRight;

		final outLeft = Std.int(heldLeft);
		final outRight = Std.int(heldRight);

		while (samples >= 1) {
			samples -= 1;
			put(outLeft, outRight);
		}

		aim();
	}

	inline function aim():Void {
		final off = (WANTED - held) / (ROOM * 0.5);
		bend = 1 + (off > BEND ? BEND : (off < -BEND ? -BEND : off));
	}

	public function ready():Int {
		return held;
	}

	public function take(into:Vector<Int>, count:Int):Int {
		final given = count < held ? count : held;

		for (i in 0...given) {
			into[i * 2] = ring[tail * 2];
			into[i * 2 + 1] = ring[tail * 2 + 1];
			tail = (tail + 1) % ROOM;
		}

		held -= given;
		return given;
	}

	inline function put(left:Int, right:Int):Void {
		if (held == ROOM) {
			tail = (tail + 1) % ROOM;
			held--;
			lost++;
		}

		ring[head * 2] = left;
		ring[head * 2 + 1] = right;
		head = (head + 1) % ROOM;
		held++;
	}
}

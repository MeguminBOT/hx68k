package hx68k.md;

import haxe.ds.Vector;

@:allow(hx68k.md.Savestate)
@:allow(hx68k.md.Machine)
final class Sound {
	public static inline final RATE = 44100;

	static inline final ROOM = 4410;

	static inline final PER_FM = 1008;

	public static inline final WANTED = 3072;

	static inline final BEND = 0.005;

	static inline final COUPLING = 0.9975;

	public final psg:Psg = new Psg();
	public final ym:Ym2612 = new Ym2612();

	public var lost(default, null):Int = 0;

	public var made(default, null):Int = 0;

	public var bend(default, null):Float = 1;

	var waiting:Int = 0;

	final ring:Vector<Int> = new Vector<Int>(ROOM * 2);

	var head:Int = 0;
	var tail:Int = 0;
	var held:Int = 0;

	var psgClocks:Int = 0;
	var ymClocks:Int = 0;
	var samples:Float = 0;

	public var masterHz(default, null):Int = Vdp.MASTER_HZ;

	var perMaster:Float = RATE / Vdp.MASTER_HZ;

	var fmLeft:Int = 0;
	var fmRight:Int = 0;
	var olderLeft:Int = 0;
	var olderRight:Int = 0;

	var wentLeft:Int = 0;
	var wentRight:Int = 0;
	var heldLeft:Float = 0;
	var heldRight:Float = 0;

	public var onYm:Null<(Int, Int) -> Void> = null;

	public var onPsg:Null<Int -> Void> = null;

	public function new() {}

	public function writeYm(port:Int, value:Int):Void {
		if (onYm != null) onYm(port, value);
		ym.write(port, value);
	}

	public function reset():Void {
		psg.reset();
		ym.reset();
		ymClocks = 0;
		fmLeft = 0;
		fmRight = 0;
		olderLeft = 0;
		olderRight = 0;
		head = 0;
		tail = 0;
		held = 0;
		lost = 0;
		made = 0;
		psgClocks = 0;
		samples = 0;
		bend = 1;
		perMaster = RATE / masterHz;
		waiting = 0;
		wentLeft = 0;
		wentRight = 0;
		heldLeft = 0;
		heldRight = 0;
	}

	public function standard(hz:Int):Void {
		masterHz = hz;
		perMaster = RATE * bend / masterHz;
	}

	public inline function tick(master:Int):Void {
		psgClocks += master;

		ymClocks += master;
		samples += master * perMaster;

		if (ymClocks >= PER_FM || samples >= 1) work();
	}

	function work():Void {
		while (ymClocks >= PER_FM) {
			ymClocks -= PER_FM;
			ym.sample();
			olderLeft = fmLeft;
			olderRight = fmRight;
			fmLeft = ym.left;
			fmRight = ym.right;
		}

		if (samples < 1) return;

		final at = Std.int(ymClocks / 7);
		final left = olderLeft + Std.int(((fmLeft - olderLeft) * at) / Ym2612.PER_SAMPLE);
		final right = olderRight + Std.int(((fmRight - olderRight) * at) / Ym2612.PER_SAMPLE);

		catchUp();
		final other = psg.taken();

		final mixedLeft = left + other;
		final mixedRight = right + other;

		while (samples >= 1) {
			samples -= 1;

			heldLeft = (mixedLeft - wentLeft) + COUPLING * heldLeft;
			heldRight = (mixedRight - wentRight) + COUPLING * heldRight;
			wentLeft = mixedLeft;
			wentRight = mixedRight;

			put(Std.int(heldLeft), Std.int(heldRight));
		}

		aim();
	}

	inline function aim():Void {
		final off = (WANTED - (waiting > held ? waiting : held)) * BEND / WANTED;
		bend = 1 + (off > BEND ? BEND : (off < -BEND ? -BEND : off));
		perMaster = RATE * bend / masterHz;
	}

	inline function catchUp():Void {
		if (psgClocks < 15) return;

		final whole = Std.int(psgClocks / 15);
		psgClocks -= whole * 15;
		psg.run(whole);
	}

	public function writePsg(value:Int):Void {
		if (onPsg != null) onPsg(value);

		catchUp();
		psg.write(value);
	}

	public function steerBy(much:Float):Void {
		bend = much;
		perMaster = RATE * bend / masterHz;
	}

	public function steer(downstream:Int):Void {
		waiting = downstream + held;
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

		made++;
		ring[head * 2] = left;
		ring[head * 2 + 1] = right;
		head = (head + 1) % ROOM;
		held++;
	}
}

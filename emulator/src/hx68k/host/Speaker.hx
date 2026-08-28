package hx68k.host;

import haxe.ds.Vector;
import hx68k.md.Sound;

class Speaker {
	static inline final CHUNK = 256;

	public var gain:Int = 21;

	public var playing(default, null):Bool = false;

	final taken:Vector<Int> = new Vector<Int>(CHUNK * 2);
	final shaped:Array<cpp.Int16> = new Array<cpp.Int16>();

	public function new() {
		for (i in 0...CHUNK * 2) shaped[i] = 0;
		playing = Audio.start(Sound.RATE) != 0;
	}

	public var starved(get, never):Int;

	inline function get_starved():Int {
		return Audio.starved();
	}

	public function feed(sound:Sound):Void {
		if (!playing) return;

		while (sound.ready() >= CHUNK) {
			final got = sound.take(taken, CHUNK);
			if (got < CHUNK) break;

			for (i in 0...CHUNK * 2) shaped[i] = clamp(taken[i], gain);

			var pushed = 0;
			while (pushed < CHUNK) {
				final at = cpp.Pointer.ofArray(shaped).add(pushed * 2).raw;
				final took = Audio.push(at, CHUNK - pushed);
				if (took == 0) break;
				pushed += took;
			}
		}

		sound.steer(Audio.queued());
	}

	public function silence():Void {
		Audio.clear();
	}

	public function stop():Void {
		Audio.stop();
		playing = false;
	}

	public function queued():Int {
		return Audio.queued();
	}

	public function delay():Int {
		return Std.int(1000 * queued() / Sound.RATE);
	}

	static inline function clamp(sample:Int, gain:Int):Int {
		final scaled = sample * gain;
		if (scaled > 32767) return 32767;
		if (scaled < -32768) return -32768;
		return scaled;
	}
}

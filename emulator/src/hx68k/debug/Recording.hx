package hx68k.debug;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.ds.Vector;
import hx68k.md.Sound;

class Recording {
	static inline final GAIN = 21;

	public static function save(samples:Array<Int>, path:String):Void {
		final frames = samples.length >> 1;
		final data = frames * 4;

		final out = new BytesOutput();
		out.bigEndian = false;

		out.writeString("RIFF");
		out.writeInt32(36 + data);
		out.writeString("WAVE");

		out.writeString("fmt ");
		out.writeInt32(16);
		out.writeUInt16(1);
		out.writeUInt16(2);
		out.writeInt32(Sound.RATE);
		out.writeInt32(Sound.RATE * 4);
		out.writeUInt16(4);
		out.writeUInt16(16);

		out.writeString("data");
		out.writeInt32(data);

		for (i in 0...frames * 2) out.writeInt16(clamp(samples[i]));

		sys.io.File.saveBytes(path, out.getBytes());
	}

	public static function drain(sound:Sound, taken:Vector<Int>, into:Array<Int>):Void {
		while (sound.ready() > 0) {
			final got = sound.take(taken, taken.length >> 1);
			if (got == 0) break;
			for (i in 0...got * 2) into.push(taken[i]);
		}
	}

	static inline function clamp(sample:Int):Int {
		final scaled = sample * GAIN;
		if (scaled > 32767) return 32767;
		if (scaled < -32768) return -32768;
		return scaled;
	}
}

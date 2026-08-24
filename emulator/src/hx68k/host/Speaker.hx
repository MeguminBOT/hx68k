package hx68k.host;

import haxe.ds.Vector;
import hx68k.md.Sound;
import lime.media.openal.AL;
import lime.media.openal.ALBuffer;
import lime.media.openal.ALSource;
import lime.utils.Int16Array;

class Speaker {
	static inline final CHUNK = 256;

	static inline final BUFFERS = 12;

	static inline final AHEAD = 4;

	static inline final GAIN = 21;

	public var playing(default, null):Bool = false;

	public var starved(default, null):Int = 0;

	final source:ALSource;
	final spare:Array<ALBuffer> = [];
	final taken:Vector<Int> = new Vector<Int>(CHUNK * 2);
	final shaped:Int16Array = new Int16Array(CHUNK * 2);

	public function new() {
		source = AL.createSource();
		for (buffer in AL.genBuffers(BUFFERS)) spare.push(buffer);
	}

	public function feed(sound:Sound):Void {
		recover();

		var queued:Int = AL.getSourcei(source, AL.BUFFERS_QUEUED);

		while (spare.length > 0 && queued < AHEAD && sound.ready() >= CHUNK) {
			final got = sound.take(taken, CHUNK);
			if (got < CHUNK) break;

			for (i in 0...CHUNK * 2) shaped[i] = clamp(taken[i]);

			final buffer = spare.pop();
			AL.bufferData(buffer, AL.FORMAT_STEREO16, shaped, CHUNK * 4, Sound.RATE);
			AL.sourceQueueBuffer(source, buffer);
			queued++;
		}

		final state:Int = AL.getSourcei(source, AL.SOURCE_STATE);

		if (queued > 0 && state != AL.PLAYING) {
			if (playing) starved++;
			AL.sourcePlay(source);
			playing = true;
		}
	}

	function recover():Void {
		final done:Int = AL.getSourcei(source, AL.BUFFERS_PROCESSED);
		if (done <= 0) return;

		for (buffer in AL.sourceUnqueueBuffers(source, done)) spare.push(buffer);
	}

	public function silence():Void {
		AL.sourceStop(source);
		playing = false;
	}

	static inline function clamp(sample:Int):Int {
		final scaled = sample * GAIN;
		if (scaled > 32767) return 32767;
		if (scaled < -32768) return -32768;
		return scaled;
	}
}

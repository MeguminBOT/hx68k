package hx68k.test;

import hx68k.host.Native;
import hx68k.host.Audio;
import hx68k.md.Sound;

class AudioCheck {
	static function main():Void {
		Native.init();

		Sys.println("starting the device at " + Sound.RATE + " Hz");
		if (Audio.start(Sound.RATE) == 0) {
			Sys.println("device failed to start");
			Sys.exit(1);
		}

		tone();
		machine();

		Audio.stop();
		Sys.println("done");
	}

	static function tone():Void {
		Sys.println("");
		Sys.println("a 440 Hz tone for one second");

		final buf = new Array<cpp.Int16>();
		final frames = Sound.RATE;
		for (i in 0...frames) {
			final sample = Std.int(8000 * Math.sin(2 * Math.PI * 440 * i / Sound.RATE));
			buf[i * 2] = sample;
			buf[i * 2 + 1] = sample;
		}

		final ptr = cpp.Pointer.ofArray(buf).raw;
		final pushed = Audio.push(ptr, frames);
		Sys.println("pushed " + pushed + " of " + frames + " frames, queued now " + Audio.queued());

		final began = haxe.Timer.stamp();
		while (haxe.Timer.stamp() - began < 1.2) {}
		Sys.println("after playing: queued " + Audio.queued());
	}

	static function machine():Void {
		Sys.println("");
		Sys.println("the machine's own PSG for half a second: a beep written straight to the chip");

		final sound = new Sound();
		sound.writePsg(0x9F);
		sound.writePsg(0x86);
		sound.writePsg(0x00);
		sound.writePsg(0x90);

		final buf = new Array<cpp.Int16>();
		final chunk = 1024;

		final began = haxe.Timer.stamp();
		var made = 0;
		while (haxe.Timer.stamp() - began < 0.5) {
			sound.tick(Std.int(hx68k.md.Vdp.MASTER_HZ * (chunk / Sound.RATE)));

			while (sound.ready() >= chunk) {
				final taken = new haxe.ds.Vector<Int>(chunk * 2);
				final got = sound.take(taken, chunk);
				for (i in 0...got * 2) buf[i] = taken[i] > 1500 ? 1500 : (taken[i] < -1500 ? -1500 : taken[i]);

				final ptr = cpp.Pointer.ofArray(buf).raw;
				var offset = 0;
				while (offset < got) {
					final left = got - offset;
					final ahead = cpp.Pointer.ofArray(buf).add(offset * 2).raw;
					final pushed = Audio.push(ahead, left);
					if (pushed == 0) break;
					offset += pushed;
				}
				made += got;
			}
		}

		Sys.println("made " + made + " samples, queued now " + Audio.queued());

		final settle = haxe.Timer.stamp();
		while (haxe.Timer.stamp() - settle < 0.8) {}
		Sys.println("after settling: queued " + Audio.queued());
	}
}

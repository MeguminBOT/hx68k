package hxres.music;

#if (macro || md_runtime)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

typedef Tune = {
	final name:String;
	final data:Bytes;
}

class Corpus {
	final body:BytesBuffer;
	final rate:Int;
	var loopAt:Int;
	var loopLen:Int;

	function new(rate:Int) {
		body = new BytesBuffer();
		this.rate = rate;
		loopAt = -1;
		loopLen = 0;
	}

	inline function at():Int {
		return body.length;
	}

	function byte(value:Int):Corpus {
		body.addByte(value & 0xFF);
		return this;
	}

	function psg(value:Int):Corpus {
		return byte(0x50).byte(value);
	}

	function ym(port:Int, register:Int, value:Int):Corpus {
		return byte(port == 0 ? 0x52 : 0x53).byte(register).byte(value);
	}

	function waitFrame():Corpus {
		return byte(rate == 60 ? 0x62 : 0x63);
	}

	function waitSamples(count:Int):Corpus {
		return byte(0x61).byte(count & 0xFF).byte((count >> 8) & 0xFF);
	}

	function waitShort(count:Int):Corpus {
		return byte(0x70 | ((count - 1) & 0x0F));
	}

	function ymSpread(port:Int, count:Int, seed:Int):Corpus {
		var register:Int = 0x30;
		var made:Int = 0;
		while (made < count && register < 0xB8) {
			if ((register & 3) != 3) {
				ym(port, register, (seed + (made * 37)) & 0xFF);
				made++;
			}
			register++;
		}
		return this;
	}

	function keySpread(count:Int):Corpus {
		for (step in 0...count) {
			final channel:Int = [0, 1, 2, 4, 5, 6][step % 6];
			ym(0, 0x28, ((step % 2) == 0 ? 0xF0 : 0x00) | channel);
			waitSamples(20);
		}
		return this;
	}

	function ymRelease(port:Int, seed:Int):Corpus {
		var register:Int = 0x80;
		var made:Int = 0;
		while (register < 0x90) {
			if ((register & 3) != 3) {
				ym(port, register, (seed + (made * 23)) & 0xFF);
				made++;
			}
			register++;
		}
		return this;
	}

	function mark():Corpus {
		loopAt = at();
		return this;
	}

	function looping(samples:Int):Corpus {
		loopLen = samples;
		return this;
	}

	function done():Bytes {
		byte(0x66);

		final stream = body.getBytes();
		final out = Bytes.alloc(0x40 + stream.length);
		out.blit(0, Bytes.ofString("Vgm "), 0, 4);
		LittleEndian.setInt32(out, 0x04, out.length - 4);
		out.set(0x08, 0x50);
		out.set(0x09, 0x01);
		LittleEndian.setInt32(out, 0x0C, 0x00369E99);
		LittleEndian.setInt32(out, 0x18, 0);
		if (loopAt >= 0) {
			LittleEndian.setInt32(out, 0x1C, (0x40 + loopAt) - 0x1C);
			LittleEndian.setInt32(out, 0x20, loopLen);
		}
		LittleEndian.setInt32(out, 0x24, rate);
		out.set(0x28, 0x09);
		out.set(0x2A, 0x10);
		LittleEndian.setInt32(out, 0x2C, 0x00750AB5);
		LittleEndian.setInt32(out, 0x34, 0x0C);
		out.blit(0x40, stream, 0, stream.length);
		return out;
	}

	public static function all():Array<Tune> {
		final out = new Array<Tune>();

		out.push({name: "silence", data: new Corpus(60).waitFrame().waitFrame().done()});

		out.push({
			name: "psg tone",
			data: new Corpus(60).psg(0x80).psg(0x1F).waitFrame().psg(0x90).waitFrame()
				.psg(0x85).psg(0x0C).waitFrame().done()
		});

		out.push({
			name: "psg every channel",
			data: new Corpus(60).psg(0x80).psg(0x1F).psg(0x90).psg(0xA0).psg(0x2E).psg(0xB0)
				.psg(0xC5).psg(0x33).psg(0xD2).psg(0xE4).psg(0xF7).waitFrame().waitFrame().done()
		});

		out.push({
			name: "psg written twice with the same value",
			data: new Corpus(60).psg(0x80).psg(0x1F).psg(0x80).psg(0x1F).waitFrame()
				.psg(0x80).psg(0x1F).waitFrame().done()
		});

		out.push({
			name: "ym port 0",
			data: new Corpus(60).ym(0, 0x30, 0x71).ym(0, 0x34, 0x0D).ym(0, 0xB0, 0x3A)
				.waitFrame().ym(0, 0x40, 0x1B).waitFrame().done()
		});

		out.push({
			name: "ym both ports",
			data: new Corpus(60).ym(0, 0x30, 0x71).ym(1, 0x30, 0x22).ym(0, 0xA4, 0x1A)
				.ym(0, 0xA0, 0x69).ym(1, 0xA4, 0x18).ym(1, 0xA0, 0x2B).waitFrame().waitFrame()
				.done()
		});

		out.push({
			name: "ym key on and off",
			data: new Corpus(60).ym(0, 0x28, 0xF0).waitFrame().ym(0, 0x28, 0x00)
				.ym(0, 0x28, 0xF1).waitFrame().ym(0, 0x28, 0x01).waitFrame().done()
		});

		out.push({
			name: "ym key on and off in one frame",
			data: new Corpus(60).ym(0, 0x28, 0xF0).waitSamples(400).ym(0, 0x28, 0x00)
				.waitFrame().waitFrame().done()
		});

		out.push({
			name: "ym timers and dac enable",
			data: new Corpus(60).ym(0, 0x27, 0x00).ym(0, 0x2B, 0x80).waitFrame()
				.ym(0, 0x2B, 0x00).ym(0, 0x27, 0x40).waitFrame().done()
		});

		out.push({
			name: "the three wait forms",
			data: new Corpus(60).psg(0x80).waitSamples(735).psg(0x81).waitShort(16).psg(0x82)
				.waitShort(1).psg(0x83).waitFrame().done()
		});

		out.push({
			name: "waits that do not divide into frames",
			data: new Corpus(60).psg(0x80).waitSamples(100).psg(0x81).waitSamples(100)
				.psg(0x82).waitSamples(2000).psg(0x83).waitSamples(50).done()
		});

		out.push({
			name: "a loop",
			data: new Corpus(60).psg(0x80).waitFrame().mark().psg(0x90).waitFrame().psg(0x9F)
				.waitFrame().looping(1470).done()
		});

		out.push({
			name: "pal timing",
			data: new Corpus(50).psg(0x80).psg(0x1F).waitFrame().ym(0, 0x30, 0x71).waitFrame()
				.waitFrame().done()
		});

		out.push({
			name: "pal waits in samples",
			data: new Corpus(50).psg(0x80).waitSamples(882).psg(0x90).waitSamples(441)
				.psg(0x9F).waitSamples(882).done()
		});

		out.push({
			name: "a frame with nothing but a wait",
			data: new Corpus(60).waitFrame().psg(0x80).waitFrame().waitFrame().waitFrame()
				.psg(0x90).waitFrame().done()
		});

		out.push({
			name: "ym writes that never change the state",
			data: new Corpus(60).ym(0, 0x30, 0x71).waitFrame().ym(0, 0x30, 0x71).waitFrame()
				.ym(0, 0x30, 0x71).waitFrame().done()
		});

		out.push({
			name: "waits either side of the frame margin",
			data: new Corpus(60).psg(0x80).waitSamples(628).psg(0x81).waitSamples(628)
				.psg(0x82).waitSamples(628).psg(0x83).waitSamples(628).psg(0x84)
				.waitSamples(628).psg(0x85).waitSamples(628).done()
		});

		out.push({
			name: "waits either side of the pal frame margin",
			data: new Corpus(50).psg(0x80).waitSamples(754).psg(0x81).waitSamples(754)
				.psg(0x82).waitSamples(754).psg(0x83).waitSamples(754).psg(0x84)
				.waitSamples(754).psg(0x85).waitSamples(754).done()
		});

		out.push({
			name: "a wait longer than several frames",
			data: new Corpus(60).psg(0x80).waitSamples(5000).psg(0x90).waitSamples(63000)
				.psg(0x9F).waitFrame().done()
		});

		out.push({
			name: "ym timers with every bit the mask decides on",
			data: new Corpus(60).ym(0, 0x27, 0x2A).waitFrame().ym(0, 0x27, 0xAA).waitFrame()
				.ym(0, 0x27, 0x1F).waitFrame().ym(0, 0x27, 0x80).waitFrame().done()
		});

		out.push({
			name: "ym key writes naming every channel",
			data: new Corpus(60).ym(0, 0x28, 0xF0).ym(0, 0x28, 0xF1).ym(0, 0x28, 0xF2)
				.waitFrame().ym(0, 0x28, 0xF4).ym(0, 0x28, 0xF5).ym(0, 0x28, 0xF6)
				.waitFrame().ym(0, 0x28, 0x03).ym(0, 0x28, 0x07).waitFrame().done()
		});

		out.push({
			name: "psg tone changing only its low bits",
			data: new Corpus(60).psg(0x80).psg(0x1F).waitFrame().psg(0x85).waitFrame()
				.psg(0x8A).waitFrame().done()
		});

		out.push({
			name: "psg tone changing only its high bits",
			data: new Corpus(60).psg(0x80).psg(0x1F).waitFrame().psg(0x2A).waitFrame()
				.psg(0x05).waitFrame().done()
		});

		out.push({
			name: "psg noise and its volume",
			data: new Corpus(60).psg(0xE7).psg(0xF0).waitFrame().psg(0xE4).waitFrame()
				.psg(0xFF).waitFrame().done()
		});

		out.push({
			name: "more ym port 0 writes than one command holds",
			data: new Corpus(60).ymSpread(0, 40, 0x11).waitFrame().ymSpread(0, 40, 0x55)
				.waitFrame().done()
		});

		out.push({
			name: "more ym port 1 writes than one command holds",
			data: new Corpus(60).ymSpread(1, 40, 0x22).waitFrame().ymSpread(1, 40, 0x66)
				.waitFrame().done()
		});

		out.push({
			name: "exactly sixteen ym port 0 writes",
			data: new Corpus(60).ymSpread(0, 16, 0x33).waitFrame().ymSpread(0, 17, 0x77)
				.waitFrame().done()
		});

		out.push({
			name: "more key writes than one command holds",
			data: new Corpus(60).keySpread(20).waitFrame().done()
		});

		out.push({
			name: "both ports and the psg in one frame",
			data: new Corpus(60).ymSpread(0, 20, 0x44).ymSpread(1, 20, 0x88).psg(0x80)
				.psg(0x1F).psg(0x90).ym(0, 0x28, 0xF0).psg(0xA5).waitFrame().waitFrame().done()
		});

		out.push({
			name: "the release registers changing every frame",
			data: new Corpus(60).ymRelease(0, 0x10).waitFrame().ymRelease(0, 0x40).waitFrame()
				.ymRelease(0, 0x80).waitFrame().waitFrame().done()
		});

		out.push({
			name: "the release registers on both ports",
			data: new Corpus(60).ymRelease(0, 0x11).ymRelease(1, 0x22).waitFrame()
				.ymRelease(1, 0x66).waitFrame().ym(0, 0x82, 0x99).waitFrame().done()
		});

		out.push({
			name: "one release register and the dac together",
			data: new Corpus(60).ym(0, 0x80, 0x1F).ym(0, 0x2B, 0x80).waitFrame()
				.ym(0, 0x80, 0x2F).waitFrame().ym(0, 0x2B, 0x00).waitFrame().done()
		});

		out.push({
			name: "psg volume falling to silence",
			data: new Corpus(60).psg(0x80).psg(0x1F).psg(0x9F).waitFrame().psg(0x98)
				.waitFrame().psg(0x90).waitFrame().psg(0xBF).psg(0xB0).waitFrame().done()
		});

		return out;
	}
}
#end

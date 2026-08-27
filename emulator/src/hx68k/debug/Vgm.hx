package hx68k.debug;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import hx68k.md.Sound;

class Vgm {
	public static inline final SAMPLES_PER_FRAME = 735;

	public static inline final PSG_HZ = 3579545;

	public static inline final YM_HZ = 7670453;

	public var writes(default, null):Int = 0;

	public var frames(default, null):Int = 0;

	final commands = new BytesBuffer();
	final chosen = [0, 0];

	public function new(sound:Sound) {
		sound.onYm = (port, value) -> ym(port, value);
		sound.onPsg = value -> psg(value);
	}

	function ym(port:Int, value:Int):Void {
		final part:Int = port >> 1;

		if ((port & 1) == 0) {
			chosen[part] = value;
			return;
		}

		commands.addByte(part == 0 ? 0x52 : 0x53);
		commands.addByte(chosen[part]);
		commands.addByte(value);
		writes++;
	}

	function psg(value:Int):Void {
		commands.addByte(0x50);
		commands.addByte(value & 0xFF);
		writes++;
	}

	public function frame():Void {
		commands.addByte(0x62);
		frames++;
	}

	public function save(path:String):Void {
		commands.addByte(0x66);

		final body = commands.getBytes();
		final out = Bytes.alloc(0x40 + body.length);

		out.set(0, 0x56);
		out.set(1, 0x67);
		out.set(2, 0x6D);
		out.set(3, 0x20);

		put(out, 0x04, out.length - 4);
		put(out, 0x08, 0x00000150);
		put(out, 0x0C, PSG_HZ);
		put(out, 0x18, frames * SAMPLES_PER_FRAME);
		put(out, 0x24, 60);
		put(out, 0x28, 0x00100009);
		put(out, 0x2C, YM_HZ);
		put(out, 0x34, 0x0C);

		out.blit(0x40, body, 0, body.length);

		sys.io.File.saveBytes(path, out);
	}

	static function put(into:Bytes, at:Int, value:Int):Void {
		into.set(at, value & 0xFF);
		into.set(at + 1, (value >> 8) & 0xFF);
		into.set(at + 2, (value >> 16) & 0xFF);
		into.set(at + 3, (value >> 24) & 0xFF);
	}
}

package hx68k.debug;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import hx68k.md.Renderer;

class Screenshot {
	public static function save(renderer:Renderer, path:String):Void {
		final width = renderer.width;
		final height = renderer.height;

		final raw = Bytes.alloc(height * (width * 3 + 1));
		var at = 0;

		for (y in 0...height) {
			raw.set(at++, 0);
			for (x in 0...width) {
				final pixel = renderer.pixels[y * Renderer.MAX_WIDTH + x];
				raw.set(at++, (pixel >> 16) & 0xFF);
				raw.set(at++, (pixel >> 8) & 0xFF);
				raw.set(at++, pixel & 0xFF);
			}
		}

		final out = new BytesBuffer();
		out.add(Bytes.ofHex("89504E470D0A1A0A"));

		final header = new BytesBuffer();
		header.addInt32(swap(width));
		header.addInt32(swap(height));
		header.addByte(8);
		header.addByte(2);
		header.addByte(0);
		header.addByte(0);
		header.addByte(0);
		chunk(out, "IHDR", header.getBytes());

		chunk(out, "IDAT", haxe.zip.Compress.run(raw, 6));
		chunk(out, "IEND", Bytes.alloc(0));

		sys.io.File.saveBytes(path, out.getBytes());
	}

	static function chunk(out:BytesBuffer, kind:String, payload:Bytes):Void {
		final body = new BytesBuffer();
		body.add(Bytes.ofString(kind));
		body.add(payload);
		final bytes = body.getBytes();

		out.addInt32(swap(payload.length));
		out.add(bytes);
		out.addInt32(swap(haxe.crypto.Crc32.make(bytes)));
	}

	static inline function swap(value:Int):Int {
		return ((value >> 24) & 0xFF) | ((value >> 8) & 0xFF00) | ((value << 8) & 0xFF0000)
			| ((value << 24) & 0xFF000000);
	}
}

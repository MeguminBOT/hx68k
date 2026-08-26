package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesInput;
import haxe.zip.InflateImpl;

class Png {
	static final SIGNATURE = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

	static final EXPANDS_BY_REPEAT = [2, 4, 16];

	public static function read(path:String):Picture {
		if (!sys.FileSystem.exists(path)) throw new haxe.Exception("No such image: " + path);
		return decode(sys.io.File.getBytes(path), path);
	}

	public static function decode(source:Bytes, name:String):Picture {
		if (source.length < 8) throw new haxe.Exception(name + " is too short to be a PNG.");
		for (i in 0...8)
			if (source.get(i) != SIGNATURE[i]) throw new haxe.Exception(name + " is not a PNG.");

		var width = 0;
		var height = 0;
		var depth = 0;
		var kind = -1;
		var interlace = 0;
		var plte:Null<Bytes> = null;
		final data = new BytesBuffer();

		var at = 8;
		while (at + 8 <= source.length) {
			final length = readInt(source, at);
			final tag = source.getString(at + 4, 4);
			final body = at + 8;
			if (body + length > source.length) throw new haxe.Exception(name + " ends inside a " + tag + " chunk.");

			switch (tag) {
				case "IHDR":
					width = readInt(source, body);
					height = readInt(source, body + 4);
					depth = source.get(body + 8);
					kind = source.get(body + 9);
					if (source.get(body + 10) != 0)
						throw new haxe.Exception(name + " uses an unknown compression method.");
					if (source.get(body + 11) != 0)
						throw new haxe.Exception(name + " uses an unknown filter method.");
					interlace = source.get(body + 12);
				case "PLTE":
					plte = source.sub(body, length);
				case "IDAT":
					data.addBytes(source, body, length);
				case "IEND":
					at = source.length;
				case _:
			}

			at = body + length + 4;
		}

		if (kind < 0) throw new haxe.Exception(name + " has no IHDR chunk.");
		if (width <= 0 || height <= 0) throw new haxe.Exception(name + " declares an empty image.");
		if (interlace != 0)
			throw new haxe.Exception(name + " is saved with Adam7 interlacing, which is not read here. "
				+ "Save it again without interlacing.");
		if (depth == 16)
			throw new haxe.Exception(name + " is 16 bits per sample. Save it at 8 bits or fewer.");

		final samples = switch (kind) {
			case 0: 1;
			case 2: 3;
			case 3: 1;
			case 4: 2;
			case 6: 4;
			case _: throw new haxe.Exception(name + " uses PNG colour type " + kind + ", which is not read here.");
		}

		if (kind == 3 && plte == null) throw new haxe.Exception(name + " is indexed and has no PLTE chunk.");
		if (kind == 3 && depth > 8) throw new haxe.Exception(name + " is indexed at more than 8 bits.");
		if (kind != 3 && kind != 0 && depth != 8)
			throw new haxe.Exception(name + " is " + depth + " bits per sample in colour, which is not read here.");

		final raw = InflateImpl.run(new BytesInput(data.getBytes()));
		final rows = unfilter(raw, width, height, depth, samples, name);

		return switch (kind) {
			case 3: indexed(rows, width, height, depth, plte);
			case 0 if (depth == 8): grey(rows, width, height);
			case 0: indexed(rows, width, height, depth, greyRamp(depth));
			case _: colour(rows, width, height, samples);
		}
	}

	static function readInt(from:Bytes, at:Int):Int {
		return (from.get(at) << 24) | (from.get(at + 1) << 16) | (from.get(at + 2) << 8) | from.get(at + 3);
	}

	static function unfilter(raw:Bytes, width:Int, height:Int, depth:Int, samples:Int, name:String):Bytes {
		final wide = depth * samples;
		final unit = wide >= 8 ? Std.int(wide / 8) : 1;
		final stride = Std.int(((width * depth * samples) + 7) / 8);
		final needed = (stride + 1) * height;

		if (raw.length < needed)
			throw new haxe.Exception(name + " holds " + raw.length + " bytes of pixel data where " + needed
				+ " were expected.");

		final out = Bytes.alloc(stride * height);
		var from = 0;
		var to = 0;
		var previous = -stride;

		for (y in 0...height) {
			final filter = raw.get(from++);
			out.blit(to, raw, from, stride);
			from += stride;

			switch (filter) {
				case 0:
				case 1:
					for (x in unit...stride) out.set(to + x, (out.get(to + x) + out.get(to + x - unit)) & 0xFF);
				case 2:
					if (y > 0) for (x in 0...stride) out.set(to + x, (out.get(to + x) + out.get(previous + x)) & 0xFF);
				case 3:
					for (x in 0...stride) {
						final left = x >= unit ? out.get(to + x - unit) : 0;
						final up = y > 0 ? out.get(previous + x) : 0;
						out.set(to + x, (out.get(to + x) + ((left + up) >> 1)) & 0xFF);
					}
				case 4:
					for (x in 0...stride) {
						final left = x >= unit ? out.get(to + x - unit) : 0;
						final up = y > 0 ? out.get(previous + x) : 0;
						final corner = (y > 0 && x >= unit) ? out.get(previous + x - unit) : 0;
						out.set(to + x, (out.get(to + x) + paeth(left, up, corner)) & 0xFF);
					}
				case _:
					throw new haxe.Exception(name + " row " + y + " uses filter " + filter + ", which is not a PNG filter.");
			}

			previous = to;
			to += stride;
		}

		return out;
	}

	static inline function paeth(left:Int, up:Int, corner:Int):Int {
		final estimate = left + up - corner;
		final toLeft = estimate > left ? estimate - left : left - estimate;
		final toUp = estimate > up ? estimate - up : up - estimate;
		final toCorner = estimate > corner ? estimate - corner : corner - estimate;
		if (toLeft <= toUp && toLeft <= toCorner) return left;
		return toUp <= toCorner ? up : corner;
	}

	static function greyRamp(depth:Int):Bytes {
		final count = 1 << depth;
		final out = Bytes.alloc(count * 3);
		final step = Std.int(255 / (count - 1));
		for (i in 0...count) {
			out.set(i * 3, i * step);
			out.set(i * 3 + 1, i * step);
			out.set(i * 3 + 2, i * step);
		}
		return out;
	}

	static function indexed(rows:Bytes, width:Int, height:Int, depth:Int, plte:Bytes):Picture {
		final indexes = expand(rows, width, height, depth);
		final declared = Std.int(plte.length / 3);
		final palette = spread(plte, declared, 1 << depth);
		return new Picture(width, height, depth, indexes, null, palette, declared);
	}

	static function grey(rows:Bytes, width:Int, height:Int):Picture {
		final palette = new Array<Int>();
		for (i in 0...256) palette.push(0xFF000000 | (i << 16) | (i << 8) | i);
		return new Picture(width, height, 8, rows, null, palette, 256);
	}

	static function colour(rows:Bytes, width:Int, height:Int, samples:Int):Picture {
		final out = new Array<Int>();
		var at = 0;
		for (i in 0...width * height) {
			final r = rows.get(at);
			final g = rows.get(at + 1);
			final b = rows.get(at + 2);
			final a = samples == 4 ? rows.get(at + 3) : 0xFF;
			at += samples;
			out.push((a << 24) | (r << 16) | (g << 8) | b);
		}
		return new Picture(width, height, samples * 8, null, out, null, 0);
	}

	static function expand(rows:Bytes, width:Int, height:Int, depth:Int):Bytes {
		if (depth == 8) return rows;

		final stride = Std.int(((width * depth) + 7) / 8);
		final mask = (1 << depth) - 1;
		final out = Bytes.alloc(width * height);
		var to = 0;

		for (y in 0...height) {
			final base = y * stride;
			for (x in 0...width) {
				final bit = x * depth;
				final shift = 8 - depth - (bit & 7);
				out.set(to++, (rows.get(base + (bit >> 3)) >> shift) & mask);
			}
		}

		return out;
	}

	static function spread(plte:Bytes, declared:Int, into:Int):Array<Int> {
		final out = new Array<Int>();
		final repeats = declared < into && EXPANDS_BY_REPEAT.indexOf(declared) >= 0;
		var last = 0xFF000000;

		for (i in 0...into) {
			if (i < declared) {
				final r = plte.get(i * 3);
				final g = plte.get(i * 3 + 1);
				final b = plte.get(i * 3 + 2);
				last = 0xFF000000 | (b << 16) | (g << 8) | r;
				out.push(last);
			} else {
				out.push(repeats ? last : 0);
			}
		}

		return out;
	}
}
#end

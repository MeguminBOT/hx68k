package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;

class Wave {
	public var rate:Int;
	public var bits:Int;
	public var channels:Int;
	public var frames:Array<Float>;

	public function new(source:Bytes) {
		if (source.length < 12 || source.getString(0, 4) != "RIFF"
			|| source.getString(8, 4) != "WAVE")
			throw new haxe.Exception("Not a WAV file: no RIFF and WAVE marker.");

		var format:Int = -1;
		var data:Int = -1;
		var length:Int = 0;
		var at:Int = 12;

		while (at + 8 <= source.length) {
			final name = source.getString(at, 4);
			final size = readInt32(source, at + 4);

			if (name == "fmt ") format = at + 8;
			else if (name == "data") {
				data = at + 8;
				length = size;
			}

			at += 8 + size + (size & 1);
		}

		if (format < 0) throw new haxe.Exception("This WAV carries no fmt chunk.");
		if (data < 0) throw new haxe.Exception("This WAV carries no data chunk.");

		final encoding:Int = readInt16(source, format);
		if (encoding != 1)
			throw new haxe.Exception("This WAV is encoded as " + encoding
				+ " rather than plain PCM, which hxres does not decode. Save it as PCM.");

		channels = readInt16(source, format + 2);
		rate = readInt32(source, format + 4);
		bits = readInt16(source, format + 14);

		if (bits != 8 && bits != 16)
			throw new haxe.Exception("This WAV is " + bits
				+ " bits per sample. hxres reads 8 and 16.");
		if (channels < 1)
			throw new haxe.Exception("This WAV declares " + channels + " channels.");

		if (data + length > source.length) length = source.length - data;

		final width:Int = Std.int(bits / 8);
		final block:Int = width * channels;
		final count:Int = Std.int(length / block);

		frames = [];
		for (index in 0...count) {
			var sum:Float = 0;
			for (channel in 0...channels)
				sum += level(source, data + (index * block) + (channel * width));
			frames.push(sum / channels);
		}
	}

	function level(source:Bytes, at:Int):Float {
		if (bits == 8) {
			final held:Int = (source.get(at) & 0xFF) ^ 0x80;
			final value:Int = held > 127 ? held - 256 : held;
			return value < 0 ? value / 128.0 : value / 127.0;
		}

		final held:Int = readInt16(source, at);
		final value:Int = held > 32767 ? held - 65536 : held;
		return value < 0 ? value / 32768.0 : value / 32767.0;
	}

	public static inline function byteOf(level:Float):Int {
		final scaled:Float = level < 0 ? level * 128.0 : level * 127.0;
		var held:Int = Std.int(scaled);
		if (held > 127) held = 127;
		if (held < -128) held = -128;
		return held & 0xFF;
	}

	public function resampled(wanted:Int):Array<Float> {
		if (wanted <= 0 || wanted == rate) return frames;
		if (frames.length == 0) return frames;

		final step:Float = rate / wanted;
		final count:Int = Std.int(frames.length / step);
		final out = new Array<Float>();

		if (wanted > rate) {
			for (index in 0...count) {
				final place:Float = index * step;
				final first:Int = Std.int(place);
				final part:Float = place - first;
				final near:Float = frames[first];
				final next:Float = first + 1 < frames.length ? frames[first + 1] : near;
				out.push(near + ((next - near) * part));
			}
			return out;
		}

		for (index in 0...count) {
			final from:Float = index * step;
			final to:Float = from + step;
			var sum:Float = 0;
			var weight:Float = 0;
			var at:Int = Std.int(from);

			while (at < frames.length && at < to) {
				final low:Float = at > from ? at : from;
				final high:Float = (at + 1) < to ? (at + 1) : to;
				final part:Float = high - low;
				sum += frames[at] * part;
				weight += part;
				at++;
			}

			out.push(weight > 0 ? sum / weight : 0);
		}

		return out;
	}

	public function pcm(wanted:Int):Bytes {
		final levels = resampled(wanted);
		final out = Bytes.alloc(levels.length);
		for (index in 0...levels.length) out.set(index, byteOf(levels[index]));
		return out;
	}

	static inline function readInt16(source:Bytes, at:Int):Int {
		return (source.get(at) & 0xFF) | ((source.get(at + 1) & 0xFF) << 8);
	}

	static inline function readInt32(source:Bytes, at:Int):Int {
		return readInt16(source, at) | (readInt16(source, at + 2) << 16);
	}
}
#end

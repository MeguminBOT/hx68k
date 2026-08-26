package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;

class Pixels {
	public static function opaque(image:Bytes, width:Int, height:Int, region:Rect):Int {
		final adjusted = region.intersection(new Rect(0, 0, width, height));
		if (adjusted.empty()) return 0;

		var count = 0;
		var offset = (adjusted.y * width) + adjusted.x;

		for (_ in 0...adjusted.height) {
			for (_ in 0...adjusted.width) if (image.get(offset++) != 0) count++;
			offset += width - adjusted.width;
		}

		return count;
	}

	public static function clear(image:Bytes, width:Int, height:Int, region:Rect):Bool {
		return opaque(image, width, height, region) == 0;
	}

	public static function onEdge(image:Bytes, width:Int, height:Int, region:Rect, left:Bool, top:Bool,
			right:Bool, bottom:Bool):Bool {
		final adjusted = region.intersection(new Rect(0, 0, width, height));
		if (adjusted.empty()) return false;

		if (left) {
			var offset = (adjusted.y * width) + adjusted.x;
			for (_ in 0...adjusted.height) {
				if (image.get(offset) != 0) return true;
				offset += width;
			}
		}

		if (top) {
			var offset = (adjusted.y * width) + adjusted.x;
			for (_ in 0...adjusted.width) {
				if (image.get(offset) != 0) return true;
				offset++;
			}
		}

		if (right) {
			var offset = (adjusted.y * width) + adjusted.x + (adjusted.width - 1);
			for (_ in 0...adjusted.height) {
				if (image.get(offset) != 0) return true;
				offset += width;
			}
		}

		if (bottom) {
			var offset = ((adjusted.y + (adjusted.height - 1)) * width) + adjusted.x;
			for (_ in 0...adjusted.width) {
				if (image.get(offset) != 0) return true;
				offset++;
			}
		}

		return false;
	}

	public static function opaqueBounds(image:Bytes, width:Int, height:Int, region:Rect):Rect {
		final adjusted = region.intersection(new Rect(0, 0, width, height));
		final out = new Rect(0, 0, -1, -1);
		if (adjusted.empty()) return out;

		for (j in adjusted.y...adjusted.y + adjusted.height) {
			final row = j * width;
			for (i in adjusted.x...adjusted.x + adjusted.width)
				if (image.get(row + i) != 0) out.cover(i, j);
		}

		return out;
	}

	public static function within(image:Bytes, width:Int, region:Rect):Bytes {
		final out = Bytes.alloc(region.width * region.height);
		var from = (region.y * width) + region.x;
		var to = 0;

		for (_ in 0...region.height) {
			for (_ in 0...region.width) out.set(to++, image.get(from++));
			from += width - region.width;
		}

		return out;
	}

	public static function line(image:Bytes, width:Int, height:Int):Int {
		var line = -1;

		for (i in 0...width * height) {
			final pixel = image.get(i);
			if ((pixel & 0xF) == 0) continue;

			final own = (pixel >> 4) & 0xF;
			if (line == -1) line = own
			else if (line != own)
				throw new haxe.Exception("The pixel at " + (i % width) + "," + Std.int(i / width)
					+ " names palette line " + own + " where the rest of the frame names " + line + ".");
		}

		return line == -1 ? 0 : line;
	}
}
#end

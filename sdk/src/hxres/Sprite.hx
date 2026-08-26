package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;

enum Aim {
	Balanced;
	FewestSprites;
	FewestPatterns;
	Whole;
}

class Sprite {
	public final rect:Rect;
	public final aim:Aim;
	public final patterns:Int;
	public var covered:Int;

	public function new(rect:Rect, aim:Aim) {
		this.rect = rect;
		this.aim = aim;
		this.patterns = Std.int((rect.width * rect.height) / 64);
		this.covered = -1;
	}

	public inline function single():Bool {
		return rect.width == 8 && rect.height == 8;
	}

	public function score():Float {
		return switch (aim) {
			case FewestSprites: 12.0 + patterns + (rect.width / 32.0);
			case FewestPatterns: 6.0 + (patterns * 4.0) + (rect.width / 32.0);
			case _: 8.0 + (patterns * 2.5) + (rect.width / 32.0);
		}
	}

	public function overdraw(other:Sprite):Int {
		final shared = rect.intersection(other.rect);
		return shared.height * shared.width;
	}

	public function copy():Sprite {
		return new Sprite(rect.copy(), aim);
	}

	public static function sized(x:Int, y:Int, width:Int, height:Int, aim:Aim):Sprite {
		return new Sprite(new Rect(x, y, width, height), aim);
	}

	public static function placed(image:Bytes, width:Int, height:Int, from:Sprite):Sprite {
		final region = from.rect.copy();
		final bounds = new Rect(0, 0, width, height);

		while (!Pixels.onEdge(image, width, height, region, false, false, true, false) && region.intersects(bounds))
			region.x--;
		while (!Pixels.onEdge(image, width, height, region, false, false, false, true) && region.intersects(bounds))
			region.y--;
		while (!Pixels.onEdge(image, width, height, region, true, false, false, false) && region.intersects(bounds))
			region.x++;
		while (!Pixels.onEdge(image, width, height, region, false, true, false, false) && region.intersects(bounds))
			region.y++;

		return new Sprite(region, from.aim);
	}

	public static function trimmed(image:Bytes, width:Int, height:Int, from:Sprite):Null<Sprite> {
		final region = from.rect.copy();
		final wanted = Pixels.opaque(image, width, height, region);
		if (wanted == 0) return null;

		do {
			region.x += 8;
			region.width -= 8;
		} while (region.width > 0 && Pixels.opaque(image, width, height, region) == wanted);
		region.x -= 8;
		region.width += 8;

		do {
			region.y += 8;
			region.height -= 8;
		} while (region.height > 0 && Pixels.opaque(image, width, height, region) == wanted);
		region.y -= 8;
		region.height += 8;

		do {
			region.width -= 8;
		} while (region.width > 0 && Pixels.opaque(image, width, height, region) == wanted);
		region.width += 8;

		do {
			region.height -= 8;
		} while (region.height > 0 && Pixels.opaque(image, width, height, region) == wanted);
		region.height += 8;

		return new Sprite(region, from.aim);
	}

	public static function inside(width:Int, height:Int, from:Sprite):Sprite {
		final region = from.rect.copy();

		if (region.x + region.width > width) region.x -= (region.x + region.width) - width;
		if (region.y + region.height > height) region.y -= (region.y + region.height) - height;
		if (region.x < 0) region.x = 0;
		if (region.y < 0) region.y = 0;

		return new Sprite(region, from.aim);
	}

	public function settle(image:Bytes, width:Int, height:Int, others:Array<Sprite>):Bool {
		final region = new Region();
		for (other in others) if (other != this) region.add(other.rect);
		region.keep(rect);
		if (region.empty()) return false;

		final wasX = rect.x;
		final wasY = rect.y;
		final wide = rect.width;
		final tall = rect.height;

		while (swap(image, width, height, region,
				new Rect(rect.x + (wide - 1), rect.y, 1, tall), new Rect(rect.x - 1, rect.y, 1, tall))) {
			rect.x--;
			if (rect.x < 0) {
				rect.x++;
				break;
			}
		}

		while (swap(image, width, height, region,
				new Rect(rect.x, rect.y, 1, tall), new Rect(rect.x + wide, rect.y, 1, tall))) {
			rect.x++;
			if (rect.x + wide > width) {
				rect.x--;
				break;
			}
		}

		while (swap(image, width, height, region,
				new Rect(rect.x, rect.y + (tall - 1), wide, 1), new Rect(rect.x, rect.y - 1, wide, 1))) {
			rect.y--;
			if (rect.y < 0) {
				rect.y++;
				break;
			}
		}

		while (swap(image, width, height, region,
				new Rect(rect.x, rect.y, wide, 1), new Rect(rect.x, rect.y + tall, wide, 1))) {
			rect.y++;
			if (rect.y + tall > height) {
				rect.y--;
				break;
			}
		}

		return rect.x != wasX || rect.y != wasY;
	}

	static function swap(image:Bytes, width:Int, height:Int, region:Region, given:Rect, taken:Rect):Bool {
		if (!region.touches(given)) return false;

		final opaque = Pixels.opaqueBounds(image, width, height, given);
		if (!opaque.empty() && !region.holds(opaque)) return false;

		return !region.touches(taken);
	}
}
#end

package hxres;

#if (macro || md_runtime)
import hxres.Sprite.Aim;
import haxe.io.Bytes;

class Piece {
	public final offsetX:Int;
	public final offsetY:Int;
	public final across:Int;
	public final down:Int;
	public final flippedX:Int;
	public final flippedY:Int;

	public function new(sprite:Sprite, frameAcross:Int, frameDown:Int) {
		offsetX = sprite.rect.x;
		offsetY = sprite.rect.y;
		across = Std.int(sprite.rect.width / 8);
		down = Std.int(sprite.rect.height / 8);
		flippedX = (frameAcross * 8) - (offsetX + (across * 8));
		flippedY = (frameDown * 8) - (offsetY + (down * 8));

		if (offsetX < 0 || offsetX > 255 || offsetY < 0 || offsetY > 255)
			throw new haxe.Exception("A hardware sprite sits at " + offsetX + "," + offsetY
				+ ", outside the 0 to 255 a frame offset can hold.");
		if (flippedX < 0 || flippedX > 255 || flippedY < 0 || flippedY > 255)
			throw new haxe.Exception("A hardware sprite flips to " + flippedX + "," + flippedY
				+ ", outside the 0 to 255 a frame offset can hold.");
	}

	public inline function size():Int {
		return ((across - 1) << 2) | (down - 1);
	}

	public function bytes():Array<Int> {
		return [offsetY, flippedY, size(), offsetX, flippedX, down * across];
	}
}

class Frame {
	public final pieces:Array<Piece> = [];
	public final patterns:Patterns;
	public final timer:Int;

	final across:Int;
	final down:Int;

	public function new(image:Bytes, across:Int, down:Int, timer:Int, sprites:Array<Sprite>) {
		this.across = across;
		this.down = down;
		this.timer = timer;
		this.patterns = Patterns.covering(image, across * 8, down * 8, sprites);
		for (sprite in sprites) pieces.push(new Piece(sprite, across, down));
	}

	public inline function empty():Bool {
		return patterns.count() == 0;
	}

	public inline function count():Int {
		return empty() ? 0 : pieces.length;
	}

	public function whole():Bool {
		if (pieces.length != 1) return false;
		final one = pieces[0];
		return one.across * 8 == across * 8 && one.down * 8 == down * 8 && one.offsetX == 0 && one.offsetY == 0;
	}

	public function leading():Int {
		return whole() ? -127 : count();
	}
}

class Animation {
	public final frames:Array<Frame> = [];
	public final loop:Int = 0;

	public function new() {}

	public inline function empty():Bool {
		return frames.length == 0;
	}

	public function head():Int {
		return (frames.length << 8) | (loop & 0xFF);
	}

	public function mostPatterns():Int {
		var most = 0;
		for (frame in frames) if (frame.patterns.count() > most) most = frame.patterns.count();
		return most;
	}

	public function mostPieces():Int {
		var most = 0;
		for (frame in frames) if (frame.count() > most) most = frame.count();
		return most;
	}
}

class Cut {
	public final mask:Bytes;
	public final width:Int;
	public final height:Int;
	public final sprites:Array<Sprite>;

	public function new(mask:Bytes, width:Int, height:Int, sprites:Array<Sprite>) {
		this.mask = mask;
		this.width = width;
		this.height = height;
		this.sprites = sprites;
	}

	public function matches(other:Bytes, otherWidth:Int, otherHeight:Int):Bool {
		if (width != otherWidth || height != otherHeight) return false;
		if (mask.length != other.length) return false;
		for (i in 0...mask.length) if ((mask.get(i) != 0) != (other.get(i) != 0)) return false;
		return true;
	}

	public function reused():Array<Sprite> {
		return sprites.map(sprite -> new Sprite(sprite.rect.copy(), Aim.Balanced));
	}
}

class Frames {
	public final animations:Array<Animation> = [];
	public final across:Int;
	public final down:Int;
	public final palette:Array<Int>;

	public function new(picture:Picture, across:Int, down:Int, timer:Int, aim:Aim, seen:Array<Cut>) {
		this.across = across;
		this.down = down;

		if (across >= 32 || down >= 32)
			throw new haxe.Exception("A sprite frame of " + across + " by " + down
				+ " tiles is too large; both have to be under 32.");

		final image = picture.indexes;
		final width = picture.width;
		final height = picture.height;
		final wide = Std.int(width / 8);
		final tall = Std.int(height / 8);

		var highest = 0;
		for (i in 0...image.length) if (image.get(i) > highest) highest = image.get(i);
		if (highest >= 64)
			throw new haxe.Exception("A sprite names colour index " + highest
				+ "; a sprite may use at most 64 colours. Save it as a sixteen colour indexed PNG.");

		Pixels.line(image, width, height);

		if (wide % across != 0)
			throw new haxe.Exception("The image is " + width + " wide, which is not a multiple of the "
				+ (across * 8) + " a frame is.");
		if (tall % down != 0)
			throw new haxe.Exception("The image is " + height + " tall, which is not a multiple of the "
				+ (down * 8) + " a frame is.");

		final all = picture.entries(0x0EEE);
		palette = all.length > 16 ? all.slice(0, 16) : all;

		for (index in 0...Std.int(tall / down)) {
			final animation = new Animation();
			final most = Std.int(wide / across);

			var last = most - 1;
			while (last >= 0) {
				final bounds = new Rect((last * across) * 8, (index * down) * 8, across * 8, down * 8);
				if (!Pixels.clear(image, width, height, bounds)) break;
				last--;
			}

			for (at in 0...last + 1) {
				final bounds = new Rect((at * across) * 8, (index * down) * 8, across * 8, down * 8);
				final frame = Pixels.within(image, width, bounds);

				var sprites:Null<Array<Sprite>> = null;
				for (cut in seen) if (cut.matches(frame, across * 8, down * 8)) {
					sprites = cut.reused();
					break;
				}

				if (sprites == null) {
					sprites = Cutter.cut(frame, across * 8, down * 8, aim);
					seen.push(new Cut(frame, across * 8, down * 8, sprites));
				}

				animation.frames.push(new Frame(frame, across, down, timer, sprites));
			}

			if (!animation.empty()) animations.push(animation);
		}
	}

	public function mostPatterns():Int {
		var most = 0;
		for (animation in animations) if (animation.mostPatterns() > most) most = animation.mostPatterns();
		return most;
	}

	public function mostPieces():Int {
		var most = 0;
		for (animation in animations) if (animation.mostPieces() > most) most = animation.mostPieces();
		return most;
	}
}
#end

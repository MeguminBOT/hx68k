package hxres;

#if (macro || md_runtime)
import hxres.Sprite.Aim;
import haxe.ds.ArraySort;
import haxe.io.Bytes;

class Cover {
	public static inline final MOST = 16;

	static inline final UNREACHABLE = 1.7976931348623157e308;

	public final sprites:Array<Sprite> = [];

	final image:Bytes;
	final width:Int;
	final height:Int;
	final opaque:Int;

	var coverage:Bytes;
	var remaining:Int;
	var patterns:Int;
	var cached:Float;

	public function new(image:Bytes, width:Int, height:Int, opaque:Int) {
		this.image = image;
		this.width = width;
		this.height = height;
		this.opaque = opaque;
		this.coverage = Bytes.alloc(image.length);
		reset();
	}

	public function reset():Void {
		coverage.blit(0, image, 0, image.length);
		sprites.splice(0, sprites.length);
		remaining = opaque;
		patterns = 0;
		cached = -1.0;
	}

	public function add(sprite:Sprite):Bool {
		final adjusted = sprite.rect.intersection(new Rect(0, 0, width, height));
		var found = 0;

		if (!adjusted.empty()) {
			var offset = (adjusted.y * width) + adjusted.x;
			for (_ in 0...adjusted.height) {
				for (_ in 0...adjusted.width) {
					if (coverage.get(offset) != 0) {
						found++;
						coverage.set(offset, 0);
					}
					offset++;
				}
				offset += width - adjusted.width;
			}
		}

		if (found == 0 && sprite.aim != Aim.Whole) return false;

		remaining -= found;
		sprite.covered = found;
		patterns += sprite.patterns;
		sprites.push(sprite);
		cached = -1.0;
		return true;
	}

	public inline function complete():Bool {
		return remaining <= 0;
	}

	public function overdraw():Int {
		var total = 0;
		for (one in sprites) for (other in sprites) if (one != other) total += one.overdraw(other);
		return total;
	}

	public function score():Float {
		if (!complete()) return UNREACHABLE;

		if (cached == -1.0) {
			var total = 0.0;
			for (sprite in sprites) total += sprite.score();
			total += overdraw() / 3000.0;
			if (sprites.length > MOST) total *= 2.0;
			cached = Math.ffloor((total * 100000.0) + 0.5) / 100000.0;
		}

		return cached;
	}

	public function rebuild(from:Array<Sprite>):Bool {
		reset();
		for (sprite in from) add(sprite);
		return complete();
	}

	public function copy():Cover {
		final out = new Cover(image, width, height, opaque);
		for (sprite in sprites) out.add(sprite.copy());
		return out;
	}

	public function fast():Void {
		inside();

		var least = score();
		final best = copy();
		var settled = 0;

		while (true) {
			once(false);
			if (score() < least) {
				least = score();
				best.rebuild(sprites);
				settled = 0;
			}
			if (settled++ >= 3) break;

			once(true);
			if (score() < least) {
				least = score();
				best.rebuild(sprites);
				settled = 0;
			}
			if (settled++ >= 3) break;
		}

		rebuild(best.sprites);
	}

	function once(fromOriginal:Bool):Void {
		merge();
		place();
		trim(fromOriginal);
		spread();
		inside();
	}

	function inside():Void {
		final was = sprites.copy();
		reset();
		for (sprite in was) add(Sprite.inside(width, height, sprite));
	}

	function biggestFirst():Void {
		ArraySort.sort(sprites, (a, b) -> b.patterns - a.patterns);
	}

	function merge():Void {
		biggestFirst();
		for (sprite in sprites.copy()) mergeAround(sprite);
	}

	function mergeAround(sprite:Sprite):Void {
		var bestGain = 0.0;
		var bestSprite:Null<Sprite> = null;
		var bestCovered:Null<Array<Sprite>> = null;

		final startWide = Std.int(sprite.rect.width / 8);
		final startTall = Std.int(sprite.rect.height / 8);

		var tall = startTall;
		var wide = startWide;
		while (tall < 4) {
			while (wide < 4) {
				final tried = Sprite.sized(sprite.rect.x, sprite.rect.y, wide * 8, tall * 8, sprite.aim);
				final covered = within(tried);
				final worth = worthOf(covered);

				if (worth > 0.0) {
					final gain = worth - tried.score();
					if (gain > bestGain) {
						bestGain = gain;
						bestSprite = tried;
						bestCovered = covered;
					}
				}

				wide++;
			}
			wide = 1;
			tall++;
		}

		final cornerX = sprite.rect.x + (startWide * 8);
		final cornerY = sprite.rect.y + (startTall * 8);

		tall = startTall;
		wide = startWide;
		while (tall < 4) {
			while (wide < 4) {
				final tried = Sprite.sized(cornerX - (wide * 8), cornerY - (tall * 8), wide * 8, tall * 8, sprite.aim);
				final covered = within(tried);
				final worth = worthOf(covered);

				if (worth > 0.0) {
					final gain = worth - tried.score();
					if (gain > bestGain) {
						bestGain = gain;
						bestSprite = tried;
						bestCovered = covered;
					}
				}

				wide++;
			}
			wide = 1;
			tall++;
		}

		if (bestSprite == null) return;

		sprites.push(bestSprite);

		final kept = new Array<Sprite>();
		for (sprite in sprites) {
			var covered = false;
			for (gone in bestCovered) if (sprite.rect.same(gone.rect)) {
				covered = true;
				break;
			}
			if (!covered) kept.push(sprite);
		}

		sprites.splice(0, sprites.length);
		for (sprite in kept) sprites.push(sprite);
	}

	function within(sprite:Sprite):Array<Sprite> {
		final out = new Array<Sprite>();
		for (other in sprites) if (sprite.rect.contains(other.rect)) out.push(other);
		return out;
	}

	static function worthOf(sprites:Array<Sprite>):Float {
		var total = 0.0;
		for (sprite in sprites) total += sprite.score();
		return total;
	}

	function place():Void {
		biggestFirst();
		final was = sprites.copy();
		reset();
		for (sprite in was) add(Sprite.placed(image, width, height, sprite));
	}

	function spread():Void {
		biggestFirst();
		final was = sprites.copy();
		reset();
		for (sprite in was) {
			sprite.settle(image, width, height, was);
			add(sprite);
		}
	}

	function trim(fromOriginal:Bool):Void {
		var last = score();
		var converged = 1.0;

		do {
			final before = last;
			biggestFirst();

			var i = sprites.length - 1;
			while (i >= 0) {
				trimOne(sprites[i], fromOriginal);
				i--;
			}

			last = score();
			converged /= 2;
			converged += before - last;

			if (last == before) break;
		} while (Math.abs(converged) > 0.0005);
	}

	function trimOne(sprite:Sprite, fromOriginal:Bool):Void {
		final without = sprites.copy();
		without.remove(sprite);
		rebuild(without);

		final trimmed = Sprite.trimmed(fromOriginal ? image : coverage, width, height, sprite);
		if (trimmed != null) add(trimmed);
	}
}
#end

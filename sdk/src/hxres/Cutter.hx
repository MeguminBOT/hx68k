package hxres;

#if (macro || md_runtime)
import hxres.Sprite.Aim;
import haxe.ds.ArraySort;
import haxe.io.Bytes;

class Cutter {
	public static function cut(image:Bytes, width:Int, height:Int, aim:Aim):Array<Sprite> {
		var sprites = covering(image, width, height, aim);

		if (sprites.length > Cover.MOST && aim != Aim.FewestSprites)
			sprites = covering(image, width, height, Aim.FewestSprites);

		if (sprites.length > Cover.MOST)
			throw new haxe.Exception("A sprite frame needs " + sprites.length + " hardware sprites, and "
				+ Cover.MOST + " is the limit. Make the frame smaller or split it.");

		return sprites;
	}

	static function covering(image:Bytes, width:Int, height:Int, aim:Aim):Array<Sprite> {
		final opaque = Pixels.opaque(image, width, height, new Rect(0, 0, width, height));
		final covers = new Array<Cover>();

		if (aim == Aim.Whole) {
			covers.push(whole(image, width, height, opaque));
		} else {
			var size = 8;
			while (size <= 32) {
				final grid = best(image, width, height, size, aim);
				if (size == 8) grid.merge(aim);

				final cover = new Cover(image, width, height, opaque);
				for (sprite in grid.sprites()) cover.add(sprite);
				cover.fast();

				if (cover.sprites.length > 0) covers.push(cover);
				size += 24;
			}
		}

		if (covers.length == 0) return [];

		ArraySort.sort(covers, (a, b) -> {
			final left = a.score();
			final right = b.score();
			return left < right ? -1 : (left > right ? 1 : 0);
		});

		var fewest:Null<Array<Sprite>> = null;
		for (cover in covers) {
			if (cover.sprites.length <= Cover.MOST) return cover.sprites;
			if (fewest == null || cover.sprites.length < fewest.length) fewest = cover.sprites;
		}

		return fewest;
	}

	static function whole(image:Bytes, width:Int, height:Int, opaque:Int):Cover {
		final acrossCells = Std.int(width / 8);
		final downCells = Std.int(height / 8);
		final across = Std.int((acrossCells + 3) / 4);
		final down = Std.int((downCells + 3) / 4);

		var lastAcross = acrossCells & 3;
		var lastDown = downCells & 3;
		if (lastAcross == 0) lastAcross = 4;
		if (lastDown == 0) lastDown = 4;

		final cover = new Cover(image, width, height, opaque);

		for (x in 0...across) {
			for (y in 0...down) {
				cover.add(Sprite.sized(x * 32, y * 32,
					x == across - 1 ? lastAcross * 8 : 32,
					y == down - 1 ? lastDown * 8 : 32, Aim.Whole));
			}
		}

		return cover;
	}

	static function best(image:Bytes, width:Int, height:Int, size:Int, aim:Aim):Grid {
		final bounds = new Rect(0, 0, width, height);
		final mask = size - 1;

		var fewest = 0x7FFFFFFF;
		var chosen:Null<Grid> = null;

		var offsetX = -mask;
		while (offsetX <= 0) {
			var offsetY = -mask;
			while (offsetY <= 0) {
				final grid = new Grid(offsetX, offsetY, Std.int((width + (size * 2)) / size),
					Std.int((height + (size * 2)) / size));

				var x = offsetX;
				var across = 0;
				while (x < width + size) {
					var y = offsetY;
					var down = 0;
					while (y < height + size) {
						final tile = Sprite.sized(x, y, size, size, aim);
						if (!Pixels.clear(image, width, height, tile.rect.intersection(bounds)))
							grid.set(across, down, tile);
						y += size;
						down++;
					}
					x += size;
					across++;
				}

				final used = grid.occupied();
				if (used < fewest) {
					fewest = used;
					chosen = grid;
				}

				offsetY++;
			}
			offsetX++;
		}

		return chosen;
	}
}
#end

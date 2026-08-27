package hxres;

#if (macro || md_runtime)
import hxres.Pattern.Equality;

enum Optimization {
	Every;
	Duplicates;
	Nothing;
}

enum Ordering {
	Row;
	Column;
}

class Patterns {
	public final all:Array<Pattern> = [];

	final buckets:Map<Int, Array<Int>> = new Map<Int, Array<Int>>();

	public function new() {}

	public static function of(picture:Picture, optimize:Optimization, ordering:Ordering, blank:Bool):Patterns {
		return within(picture, 0, 0, Std.int(picture.width / Pattern.SIDE),
			Std.int(picture.height / Pattern.SIDE), optimize, ordering, blank);
	}

	public static function within(picture:Picture, fromX:Int, fromY:Int, across:Int, down:Int,
			optimize:Optimization, ordering:Ordering, blank:Bool):Patterns {
		final out = new Patterns();
		var sawBlank = false;

		final outer = ordering == Row ? down : across;
		final inner = ordering == Row ? across : down;

		for (a in 0...outer) {
			for (b in 0...inner) {
				final i = ordering == Row ? b : a;
				final j = ordering == Row ? a : b;
				final pattern = Pattern.at(picture.indexes, picture.width, picture.height,
					(i + fromX) * Pattern.SIDE, (j + fromY) * Pattern.SIDE);

				if (pattern.blank) sawBlank = true;
				if (out.indexOf(pattern, optimize) == -1) out.add(pattern);
			}
		}

		if (!sawBlank && blank) out.add(new Pattern([0, 0, 0, 0, 0, 0, 0, 0], 0, false, 0));

		return out;
	}

	public static function covering(image:haxe.io.Bytes, width:Int, height:Int, sprites:Array<Sprite>):Patterns {
		final out = new Patterns();

		for (sprite in sprites) {
			final across = Std.int(sprite.rect.width / 8);
			final down = Std.int(sprite.rect.height / 8);

			for (i in 0...across)
				for (j in 0...down)
					out.add(Pattern.at(image, width, height, sprite.rect.x + (i * 8), sprite.rect.y + (j * 8)));
		}

		return out;
	}

	public function add(pattern:Pattern):Int {
		final index = all.length;
		all.push(pattern);

		var bucket = buckets.get(pattern.hash);
		if (bucket == null) {
			bucket = [];
			buckets.set(pattern.hash, bucket);
		}
		bucket.push(index);

		return index;
	}

	public function indexOf(pattern:Pattern, optimize:Optimization):Int {
		if (optimize == Nothing) return -1;

		final bucket = buckets.get(pattern.hash);
		if (bucket == null) return -1;

		for (index in bucket) if (all[index].same(pattern)) return index;
		if (optimize != Every) return -1;

		for (index in bucket) if (all[index].flipEquality(pattern) != Equality.Apart) return index;
		return -1;
	}

	public inline function get(index:Int):Pattern {
		return all[index];
	}

	public inline function count():Int {
		return all.length;
	}

	public function data():Array<Int> {
		final out = new Array<Int>();
		for (pattern in all) for (row in pattern.rows) out.push(row);
		return out;
	}
}
#end

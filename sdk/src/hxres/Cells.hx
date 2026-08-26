package hxres;

#if (macro || md_runtime)
import hxres.Pattern.Equality;
import hxres.Patterns.Optimisation;
import hxres.Patterns.Ordering;

class Cells {
	public static inline final INDEX_MASK = 0x7FF;

	public static inline final HORIZONTAL_SHIFT = 11;

	public static inline final VERTICAL_SHIFT = 12;

	public static inline final LINE_SHIFT = 13;

	public static inline final PRIORITY_SHIFT = 15;

	public final across:Int;
	public final down:Int;
	public final entries:Array<Int>;

	public function new(across:Int, down:Int, entries:Array<Int>) {
		this.across = across;
		this.down = down;
		this.entries = entries;
	}

	public static function of(picture:Picture, patterns:Patterns, base:Int, optimise:Optimisation,
			ordering:Ordering):Cells {
		return within(picture, patterns, base, 0, 0, Std.int(picture.width / Pattern.SIDE),
			Std.int(picture.height / Pattern.SIDE), optimise, ordering);
	}

	public static function within(picture:Picture, patterns:Patterns, base:Int, fromX:Int, fromY:Int,
			across:Int, down:Int, optimise:Optimisation, ordering:Ordering):Cells {
		final basePriority = (base & (1 << PRIORITY_SHIFT)) != 0;
		final baseLine = (base >> LINE_SHIFT) & 3;
		final baseIndex = base & INDEX_MASK;
		final plainAllowed = baseIndex != 0;

		final entries = new Array<Int>();

		for (j in 0...down) {
			for (i in 0...across) {
				final pattern = Pattern.at(picture.indexes, picture.width, picture.height,
					(i + fromX) * Pattern.SIDE, (j + fromY) * Pattern.SIDE);

				var index = 0;
				var equality = Equality.Apart;

				if (optimise == Optimisation.Nothing) {
					index = (ordering == Ordering.Row ? (j * across) + i : (i * down) + j) + baseIndex;
				} else if (plainAllowed && pattern.isPlain()) {
					index = pattern.plain;
				} else {
					index = patterns.indexOf(pattern, optimise);
					if (index == -1)
						throw new haxe.Exception("The pattern at " + (i + fromX) + "," + (j + fromY)
							+ " is not in the set built from the same image.");
					equality = pattern.equality(patterns.get(index));
					index += baseIndex;
				}

				entries.push(entry(baseLine + pattern.line, basePriority || pattern.priority, equality, index));
			}
		}

		return new Cells(across, down, entries);
	}

	public static function entry(line:Int, priority:Bool, equality:Equality, index:Int):Int {
		final horizontal = equality == Equality.Horizontal || equality == Equality.Both;
		final vertical = equality == Equality.Vertical || equality == Equality.Both;
		return (horizontal ? 1 << HORIZONTAL_SHIFT : 0)
			+ (vertical ? 1 << VERTICAL_SHIFT : 0)
			+ (line << LINE_SHIFT)
			+ (priority ? 1 << PRIORITY_SHIFT : 0)
			+ index;
	}
}
#end

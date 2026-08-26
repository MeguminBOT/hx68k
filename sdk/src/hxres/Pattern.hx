package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;

enum Equality {
	Apart;
	Same;
	Vertical;
	Horizontal;
	Both;
}

class Pattern {
	public static inline final SIDE = 8;

	public static inline final ROWS = 8;

	public final rows:Array<Int>;
	public final line:Int;
	public final priority:Bool;
	public final plain:Int;
	public final blank:Bool;
	public final hash:Int;

	final acrossRows:Array<Int>;
	final downRows:Array<Int>;
	final aroundRows:Array<Int>;

	public function new(rows:Array<Int>, line:Int, priority:Bool, plain:Int) {
		this.rows = rows;
		this.line = line & 3;
		this.priority = priority;
		this.plain = plain;

		var empty = true;
		for (row in rows) if (row != 0) {
			empty = false;
			break;
		}
		this.blank = empty;

		acrossRows = flipped(rows, true, false);
		downRows = flipped(rows, false, true);
		aroundRows = flipped(rows, true, true);

		this.hash = sum(rows) + sum(acrossRows) + sum(downRows) + sum(aroundRows);
	}

	public static function at(pixels:Bytes, width:Int, height:Int, x:Int, y:Int):Pattern {
		final rows = new Array<Int>();

		var plainColour = -1;
		var plain = true;
		var line = -1;
		var priority = -1;
		var clearLine = -1;
		var clearPriority = -1;

		for (down in 0...SIDE) {
			var row = 0;
			for (across in 0...SIDE) {
				final at = x + across;
				final on = y + down;
				final inside = at >= 0 && at < width && on >= 0 && on < height;
				final pixel = inside ? pixels.get((on * width) + at) : 0;
				final colour = pixel & 0xF;

				if (plainColour == -1) plainColour = colour else if (plainColour != colour) plain = false;

				final ownLine = (pixel >> 4) & 3;
				final ownPriority = (pixel >> 7) & 1;

				if (colour == 0) {
					if (clearLine == -1) clearLine = ownLine
					else if (clearLine != ownLine)
						throw new haxe.Exception("A transparent pixel at " + at + "," + on + " names palette line "
							+ ownLine + " where the rest of its pattern names " + clearLine + ".");

					if (clearPriority == -1) clearPriority = ownPriority
					else if (clearPriority != ownPriority)
						throw new haxe.Exception("A transparent pixel at " + at + "," + on + " names priority "
							+ ownPriority + " where the rest of its pattern names " + clearPriority + ".");
				} else {
					if (line == -1) line = ownLine
					else if (line != ownLine)
						throw new haxe.Exception("The pixel at " + at + "," + on + " names palette line " + ownLine
							+ " where the rest of its pattern names " + line + ".");

					if (priority == -1) priority = ownPriority
					else if (priority != ownPriority)
						throw new haxe.Exception("The pixel at " + at + "," + on + " names priority " + ownPriority
							+ " where the rest of its pattern names " + priority + ".");
				}

				row = (row << 4) | colour;
			}
			rows.push(row);
		}

		if (line == -1) line = clearLine;
		if (priority == -1) priority = clearPriority;

		return new Pattern(rows, line, priority != 0, plain ? plainColour : -1);
	}

	public inline function isPlain():Bool {
		return plain != -1;
	}

	public function equality(other:Pattern):Equality {
		if (matches(other.rows, rows)) return Same;
		return flipEquality(other);
	}

	public function flipEquality(other:Pattern):Equality {
		if (matches(other.rows, acrossRows)) return Horizontal;
		if (matches(other.rows, downRows)) return Vertical;
		if (matches(other.rows, aroundRows)) return Both;
		return Apart;
	}

	public function same(other:Pattern):Bool {
		return hash == other.hash && matches(other.rows, rows);
	}

	static function matches(left:Array<Int>, right:Array<Int>):Bool {
		if (left.length != right.length) return false;
		for (i in 0...left.length) if (left[i] != right[i]) return false;
		return true;
	}

	static function sum(of:Array<Int>):Int {
		var total = 0;
		for (value in of) total += value;
		return total;
	}

	static function flipped(rows:Array<Int>, across:Bool, down:Bool):Array<Int> {
		final out = new Array<Int>();
		for (i in 0...rows.length) {
			final row = rows[down ? rows.length - 1 - i : i];
			out.push(across ? reverse(row) : row);
		}
		return out;
	}

	static function reverse(row:Int):Int {
		var out = 0;
		var left = row;
		for (_ in 0...ROWS) {
			out = (out << 4) | (left & 0xF);
			left >>>= 4;
		}
		return out;
	}
}
#end

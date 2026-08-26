package hxres;

#if (macro || md_runtime)
class Rect {
	public var x:Int;
	public var y:Int;
	public var width:Int;
	public var height:Int;

	public function new(x:Int, y:Int, width:Int, height:Int) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	public inline function copy():Rect {
		return new Rect(x, y, width, height);
	}

	public inline function empty():Bool {
		return width <= 0 || height <= 0;
	}

	public function intersection(other:Rect):Rect {
		var left = x;
		var top = y;
		var right = left + width;
		var bottom = top + height;

		final otherRight = other.x + other.width;
		final otherBottom = other.y + other.height;

		if (left < other.x) left = other.x;
		if (top < other.y) top = other.y;
		if (right > otherRight) right = otherRight;
		if (bottom > otherBottom) bottom = otherBottom;

		return new Rect(left, top, right - left, bottom - top);
	}

	public function intersects(other:Rect):Bool {
		if (empty() || other.empty()) return false;
		return other.x + other.width > x && other.y + other.height > y
			&& other.x < x + width && other.y < y + height;
	}

	public function contains(other:Rect):Bool {
		if (empty() || other.empty()) return false;
		return other.x >= x && other.y >= y
			&& other.x + other.width <= x + width && other.y + other.height <= y + height;
	}

	public function same(other:Rect):Bool {
		return x == other.x && y == other.y && width == other.width && height == other.height;
	}

	public function cover(atX:Int, atY:Int):Void {
		if (empty()) {
			x = atX;
			y = atY;
			width = 1;
			height = 1;
			return;
		}

		final right = x + width > atX + 1 ? x + width : atX + 1;
		final bottom = y + height > atY + 1 ? y + height : atY + 1;
		if (atX < x) x = atX;
		if (atY < y) y = atY;
		width = right - x;
		height = bottom - y;
	}

	public function toString():String {
		return "[" + x + "," + y + "-" + width + "," + height + "]";
	}
}
#end

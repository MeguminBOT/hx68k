package hxres;

#if (macro || md_runtime)
class Region {
	final parts:Array<Rect> = [];

	public function new() {}

	public function add(rect:Rect):Void {
		if (rect.empty()) return;
		parts.push(rect.copy());
	}

	public function keep(rect:Rect):Void {
		final kept = new Array<Rect>();
		for (part in parts) {
			final shared = part.intersection(rect);
			if (!shared.empty()) kept.push(shared);
		}
		parts.splice(0, parts.length);
		for (part in kept) parts.push(part);
	}

	public function empty():Bool {
		return parts.length == 0;
	}

	public function touches(rect:Rect):Bool {
		if (rect.empty()) return false;
		for (part in parts) if (part.intersects(rect)) return true;
		return false;
	}

	public function holds(rect:Rect):Bool {
		if (rect.empty()) return false;

		for (part in parts) if (part.contains(rect)) return true;

		for (y in rect.y...rect.y + rect.height) {
			for (x in rect.x...rect.x + rect.width) {
				var inside = false;
				for (part in parts) {
					if (x >= part.x && x < part.x + part.width && y >= part.y && y < part.y + part.height) {
						inside = true;
						break;
					}
				}
				if (!inside) return false;
			}
		}

		return true;
	}
}
#end

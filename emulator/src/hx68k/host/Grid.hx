package hx68k.host;

import hx68k.host.Zone.Side;

class Split {
	public var group:Null<String> = null;

	public var down:Bool = false;
	public var ratio:Float = 0.5;
	public var first:Null<Split> = null;
	public var second:Null<Split> = null;

	public function new() {}

	public static function leaf(group:String):Split {
		final node = new Split();
		node.group = group;
		return node;
	}

	public static function of(down:Bool, ratio:Float, first:Split, second:Split):Split {
		final node = new Split();
		node.down = down;
		node.ratio = ratio;
		node.first = first;
		node.second = second;
		return node;
	}

	public inline function isLeaf():Bool {
		return group != null;
	}
}

class Grid implements Layout {
	static inline final LEAST_RATIO = 0.1;

	var root:Null<Split> = null;

	var anchored:Null<String> = null;
	var anchorLeast:Float = 0;
	var anchorFirst:Bool = true;

	public function new() {}

	public function anchor(id:String, least:Float, first:Bool = true):Void {
		anchored = id;
		anchorLeast = least;
		anchorFirst = first;
	}

	public function name():String {
		return "grid";
	}

	public function freeform():Bool {
		return false;
	}

	public function adopt(groups:Array<Group>):Void {
		root = null;
		for (group in groups) if (!group.empty()) attach(group.id);
		prune(groups);
	}

	function attach(id:String):Void {
		if (root == null) {
			root = Split.leaf(id);
			return;
		}

		if (anchored != null && id == anchored) {
			root = anchorFirst ? Split.of(false, anchorLeast, Split.leaf(id), root)
				: Split.of(false, 1 - anchorLeast, root, Split.leaf(id));
			return;
		}

		final rest = restOf();
		if (rest != null) {
			grow(rest, id);
			return;
		}

		if (root.isLeaf() && root.group == anchored) {
			root = anchorFirst ? Split.of(false, anchorLeast, root, Split.leaf(id))
				: Split.of(false, 1 - anchorLeast, Split.leaf(id), root);
			return;
		}

		grow(root, id);
	}

	function restOf():Null<Split> {
		if (anchored == null || root == null || root.isLeaf()) return null;

		final held = anchorFirst ? root.first : root.second;
		if (held == null || !held.isLeaf() || held.group != anchored) return null;

		return anchorFirst ? root.second : root.first;
	}

	function grow(subtree:Split, id:String):Void {
		final widest = deepest(subtree);
		final leaf = Split.leaf(id);
		final was = Split.leaf(widest.group);

		widest.group = null;
		widest.down = depthOf(root, widest, 0) % 2 == 0;
		widest.ratio = 0.5;
		widest.first = was;
		widest.second = leaf;
	}

	function deepest(node:Split):Split {
		if (node.isLeaf()) return node;
		return deepest(node.second);
	}

	function depthOf(node:Null<Split>, wanted:Split, depth:Int):Int {
		if (node == null) return -1;
		if (node == wanted) return depth;
		if (node.isLeaf()) return -1;

		final left = depthOf(node.first, wanted, depth + 1);
		if (left >= 0) return left;
		return depthOf(node.second, wanted, depth + 1);
	}

	public function place(groups:Array<Group>, width:Float, height:Float, metrics:Metrics):Void {
		prune(groups);
		if (root == null) return;

		final pad = metrics.margin;
		final across = width - pad * 2;

		if (restOf() != null) {
			final wanted = anchorLeast * width / Math.max(1, across - metrics.margin);
			if (anchorFirst) {
				if (root.ratio < wanted) root.ratio = wanted;
			} else if (root.ratio > 1 - wanted) root.ratio = 1 - wanted;
			root.down = false;
		}

		spread(root, pad, metrics.reserved + pad, across, height - metrics.reserved - pad * 2,
			groups, metrics);

		compress(groups, width, height, metrics);
	}

	function compress(groups:Array<Group>, width:Float, height:Float, metrics:Metrics):Void {
		var guard = groups.length;

		while (guard-- > 0) {
			final cramped = tightest(groups, metrics);
			if (cramped == null) return;

			final host = neighbour(groups, cramped);
			if (host == null) return;

			for (panel in cramped.members.copy()) {
				cramped.drop(panel);
				host.add(panel);
			}

			detach(cramped.id);
			prune(groups);

			final pad = metrics.margin;
			spread(root, pad, metrics.reserved + pad, width - pad * 2,
				height - metrics.reserved - pad * 2, groups, metrics);
		}
	}

	function tightest(groups:Array<Group>, metrics:Metrics):Null<Group> {
		var worst:Null<Group> = null;

		for (group in groups) {
			if (group.empty() || group.id == anchored) continue;
			if (group.height >= metrics.leastHigh && group.width >= metrics.leastWide) continue;
			if (worst == null || group.height < worst.height) worst = group;
		}

		return worst;
	}

	function neighbour(groups:Array<Group>, away:Group):Null<Group> {
		var best:Null<Group> = null;

		for (group in groups) {
			if (group == away || group.empty() || group.id == anchored) continue;
			if (best == null || group.height > best.height) best = group;
		}

		return best;
	}

	function spread(node:Split, x:Float, y:Float, width:Float, height:Float, groups:Array<Group>,
			metrics:Metrics):Void {
		if (node.isLeaf()) {
			final group = find(groups, node.group);
			if (group == null) return;

			group.x = x;
			group.y = y;
			group.width = width;
			group.height = height;
			return;
		}

		final gap = metrics.margin;
		final ratio = held(node.ratio);

		if (node.down) {
			final room = Math.max(0, height - gap);
			var top = Math.max(metrics.leastHigh, room * ratio);
			if (room - top < metrics.leastHigh) top = Math.max(0, room - metrics.leastHigh);

			spread(node.first, x, y, width, top, groups, metrics);
			spread(node.second, x, y + top + gap, width, room - top, groups, metrics);
		} else {
			final room = Math.max(0, width - gap);
			var left = Math.max(metrics.leastWide, room * ratio);
			if (room - left < metrics.leastWide) left = Math.max(0, room - metrics.leastWide);

			spread(node.first, x, y, left, height, groups, metrics);
			spread(node.second, x + left + gap, y, room - left, height, groups, metrics);
		}
	}

	static inline function held(ratio:Float):Float {
		return ratio < LEAST_RATIO ? LEAST_RATIO : (ratio > 1 - LEAST_RATIO ? 1 - LEAST_RATIO : ratio);
	}

	static function find(groups:Array<Group>, id:Null<String>):Null<Group> {
		if (id == null) return null;
		for (group in groups) if (group.id == id) return group;
		return null;
	}

	public function aim(groups:Array<Group>, moving:Group, pointerX:Float, pointerY:Float,
			width:Float, height:Float, metrics:Metrics, into:Zone):Void {
		into.clear();

		for (group in groups) {
			if (group == moving || group.empty()) continue;
			if (pointerX < group.x || pointerX >= group.x + group.width) continue;
			if (pointerY < group.y || pointerY >= group.y + group.height) continue;

			final acrossIn = (pointerX - group.x) / Math.max(1, group.width);
			final downIn = (pointerY - group.y) / Math.max(1, group.height);

			final band = 0.3;

			if (acrossIn < band && acrossIn <= downIn && acrossIn <= 1 - downIn) {
				into.set(Left, group.id, group.x, group.y, group.width * 0.5, group.height);
			} else if (1 - acrossIn < band && 1 - acrossIn <= downIn && 1 - acrossIn <= 1 - downIn) {
				into.set(Right, group.id, group.x + group.width * 0.5, group.y, group.width * 0.5,
					group.height);
			} else if (downIn < band) {
				into.set(Above, group.id, group.x, group.y, group.width, group.height * 0.5);
			} else if (1 - downIn < band) {
				into.set(Below, group.id, group.x, group.y + group.height * 0.5, group.width,
					group.height * 0.5);
			} else {
				into.set(Middle, group.id, group.x, group.y, group.width, group.height);
			}
			return;
		}
	}

	public function settle(groups:Array<Group>, moving:Group, zone:Zone):Void {
		if (!zone.landing() || root == null) return;

		final target = find(groups, zone.onto);
		if (target == null || target == moving) return;

		if (zone.side == Middle) {
			for (panel in moving.members.copy()) {
				moving.drop(panel);
				target.add(panel);
			}
			target.show(moving.members.length > 0 ? target.members[target.active] : target.members[0]);
			prune(groups);
			return;
		}

		detach(moving.id);

		final host = leafOf(root, target.id);
		if (host == null) {
			attach(moving.id);
			return;
		}

		final was = Split.leaf(target.id);
		final leaf = Split.leaf(moving.id);
		final first = zone.side == Left || zone.side == Above;

		host.group = null;
		host.down = zone.side == Above || zone.side == Below;
		host.ratio = 0.5;
		host.first = first ? leaf : was;
		host.second = first ? was : leaf;
	}

	function leafOf(node:Null<Split>, id:String):Null<Split> {
		if (node == null) return null;
		if (node.isLeaf()) return node.group == id ? node : null;

		final left = leafOf(node.first, id);
		return left != null ? left : leafOf(node.second, id);
	}

	function detach(id:String):Void {
		root = without(root, id);
	}

	function without(node:Null<Split>, id:String):Null<Split> {
		if (node == null) return null;
		if (node.isLeaf()) return node.group == id ? null : node;

		node.first = without(node.first, id);
		node.second = without(node.second, id);

		if (node.first == null) return node.second;
		if (node.second == null) return node.first;
		return node;
	}

	function prune(groups:Array<Group>):Void {
		final live = new Array<String>();
		for (group in groups) if (!group.empty()) live.push(group.id);

		root = keeping(root, live);
		for (id in live) if (leafOf(root, id) == null) attach(id);
	}

	function keeping(node:Null<Split>, live:Array<String>):Null<Split> {
		if (node == null) return null;
		if (node.isLeaf()) return live.indexOf(node.group) >= 0 ? node : null;

		node.first = keeping(node.first, live);
		node.second = keeping(node.second, live);

		if (node.first == null) return node.second;
		if (node.second == null) return node.first;
		return node;
	}

	public function save():String {
		return written(root);
	}

	function written(node:Null<Split>):String {
		if (node == null) return ".";
		if (node.isLeaf()) return "@" + node.group;

		return (node.down ? "v" : "h") + Math.round(node.ratio * 1000) / 1000
			+ "(" + written(node.first) + "," + written(node.second) + ")";
	}

	public function load(state:String, groups:Array<Group>):Void {
		reading = state;
		at = 0;
		root = read();
		prune(groups);
	}

	var reading:String = "";
	var at:Int = 0;

	function read():Null<Split> {
		if (at >= reading.length) return null;

		final head = reading.charAt(at);
		if (head == ".") {
			at++;
			return null;
		}

		if (head == "@") {
			at++;
			final start = at;
			while (at < reading.length && reading.charAt(at) != "," && reading.charAt(at) != ")") at++;
			return Split.leaf(reading.substring(start, at));
		}

		if (head != "v" && head != "h") return null;

		final down = head == "v";
		at++;

		final start = at;
		while (at < reading.length && reading.charAt(at) != "(") at++;
		final ratio = Std.parseFloat(reading.substring(start, at));

		at++;
		final first = read();
		if (at < reading.length && reading.charAt(at) == ",") at++;
		final second = read();
		if (at < reading.length && reading.charAt(at) == ")") at++;

		if (first == null) return second;
		if (second == null) return first;
		return Split.of(down, Math.isNaN(ratio) ? 0.5 : ratio, first, second);
	}
}

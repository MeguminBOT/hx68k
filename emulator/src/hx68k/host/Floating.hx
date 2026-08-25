package hx68k.host;

import hx68k.host.Zone.Side;

class Floating implements Layout {
	var held:Map<String, Bool> = [];

	public function new() {}

	public function name():String {
		return "floating";
	}

	public function freeform():Bool {
		return true;
	}

	public function adopt(groups:Array<Group>):Void {
		for (group in groups) if (!held.exists(group.id)) held.set(group.id, true);
	}

	public function place(groups:Array<Group>, width:Float, height:Float, metrics:Metrics):Void {
		final least = metrics.reserved;

		for (group in groups) {
			if (group.empty()) continue;

			if (group.width < metrics.leastWide) group.width = metrics.leastWide;
			if (group.height < metrics.leastHigh) group.height = metrics.leastHigh;

			if (group.width > width) group.width = width;
			if (group.height > height - least) group.height = height - least;

			if (group.x + group.width > width) group.x = width - group.width;
			if (group.y + group.height > height) group.y = height - group.height;

			if (group.x < 0) group.x = 0;
			if (group.y < least) group.y = least;
		}
	}

	public function aim(groups:Array<Group>, moving:Group, pointerX:Float, pointerY:Float,
			width:Float, height:Float, metrics:Metrics, into:Zone):Void {
		into.clear();

		final reach = metrics.advance * 4;

		for (group in groups) {
			if (group == moving || group.empty()) continue;
			if (pointerX < group.x || pointerX >= group.x + group.width) continue;
			if (pointerY < group.y || pointerY >= group.y + group.height) continue;

			final midX = group.x + group.width * 0.5;
			final midY = group.y + group.height * 0.5;

			if (Math.abs(pointerX - midX) <= reach && Math.abs(pointerY - midY) <= reach) {
				into.set(Middle, group.id, group.x, group.y, group.width, group.height);
				return;
			}

			if (pointerX < midX - reach && pointerX >= midX - reach * 3
					&& Math.abs(pointerY - midY) <= reach) {
				into.set(Left, group.id, group.x, group.y, group.width * 0.5, group.height);
				return;
			}

			if (pointerX > midX + reach && pointerX <= midX + reach * 3
					&& Math.abs(pointerY - midY) <= reach) {
				into.set(Right, group.id, group.x + group.width * 0.5, group.y, group.width * 0.5,
					group.height);
				return;
			}

			if (pointerY < midY - reach && pointerY >= midY - reach * 3
					&& Math.abs(pointerX - midX) <= reach) {
				into.set(Above, group.id, group.x, group.y, group.width, group.height * 0.5);
				return;
			}

			if (pointerY > midY + reach && pointerY <= midY + reach * 3
					&& Math.abs(pointerX - midX) <= reach) {
				into.set(Below, group.id, group.x, group.y + group.height * 0.5, group.width,
					group.height * 0.5);
				return;
			}

			return;
		}
	}

	public function settle(groups:Array<Group>, moving:Group, zone:Zone):Void {
		if (!zone.landing()) return;

		final target = seek(groups, zone.onto);
		if (target == null || target == moving) return;

		if (zone.side == Middle) {
			for (panel in moving.members.copy()) {
				moving.drop(panel);
				target.add(panel);
			}
			return;
		}

		final x = target.x;
		final y = target.y;
		final wide = target.width;
		final high = target.height;

		switch (zone.side) {
			case Left:
				target.x = x + wide * 0.5;
				target.width = wide * 0.5;
				moving.x = x;
				moving.y = y;
				moving.width = wide * 0.5;
				moving.height = high;
			case Right:
				target.width = wide * 0.5;
				moving.x = x + wide * 0.5;
				moving.y = y;
				moving.width = wide * 0.5;
				moving.height = high;
			case Above:
				target.y = y + high * 0.5;
				target.height = high * 0.5;
				moving.x = x;
				moving.y = y;
				moving.width = wide;
				moving.height = high * 0.5;
			case Below:
				target.height = high * 0.5;
				moving.x = x;
				moving.y = y + high * 0.5;
				moving.width = wide;
				moving.height = high * 0.5;
			case _:
		}
	}

	static function seek(groups:Array<Group>, id:Null<String>):Null<Group> {
		if (id == null) return null;
		for (group in groups) if (group.id == id) return group;
		return null;
	}

	public function save():String {
		final out = new Array<String>();
		for (id in held.keys()) out.push(id);
		return out.join(",");
	}

	public function load(state:String, groups:Array<Group>):Void {
		held = [];
		for (id in state.split(",")) if (id != "") held.set(id, true);
		adopt(groups);
	}
}

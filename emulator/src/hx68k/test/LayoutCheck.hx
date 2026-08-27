package hx68k.test;

import hx68k.host.ui.Metrics;
import hx68k.host.ui.Group;
import hx68k.host.ui.Layout;
import hx68k.host.ui.Grid;
import hx68k.host.ui.Floating;
import hx68k.host.ui.Zone;
import hx68k.host.ui.Zone.Side;

class LayoutCheck {
	static inline final FLOOR_WIDE = 1280;
	static inline final FLOOR_HIGH = 720;

	static inline final SCREEN = "screen";

	static var failures:Int = 0;
	static var checks:Int = 0;

	static function ok(what:String, held:Bool, saying:String):Void {
		checks++;
		if (held) return;
		failures++;
		Sys.println("  FAIL " + what + ": " + saying);
	}

	static function metricsFor(scale:Int, toolRows:Int = 1):Metrics {
		return new Metrics(8 * scale, 16 * scale, toolRows);
	}

	static function board():Array<Group> {
		final names = [SCREEN, "registers", "disassembly", "stack", "video", "usage"];
		final out = new Array<Group>();

		for (name in names) {
			final group = new Group(name);
			group.add(name);
			out.push(group);
		}

		return out;
	}

	static function seed(groups:Array<Group>, width:Float, height:Float, metrics:Metrics):Void {
		final column = width * 0.35;
		final each = (height - metrics.reserved) / (groups.length - 1);
		var y = metrics.reserved;

		for (group in groups) {
			if (group.id == SCREEN) {
				group.x = 0;
				group.y = metrics.reserved;
				group.width = width - column;
				group.height = height - metrics.reserved;
				continue;
			}

			group.x = width - column;
			group.y = y;
			group.width = column;
			group.height = each;
			y += each;
		}
	}

	static function of(groups:Array<Group>, id:String):Null<Group> {
		for (group in groups) if (group.id == id) return group;
		return null;
	}

	static function smallest(groups:Array<Group>, metrics:Metrics):Float {
		var least = -1.0;
		for (group in groups) {
			if (group.empty() || group.id == SCREEN) continue;
			if (least < 0 || group.height < least) least = group.height;
		}
		return least;
	}

	static function rowsIn(groups:Array<Group>, metrics:Metrics):Int {
		var total = 0;
		for (group in groups) {
			if (group.empty() || group.id == SCREEN) continue;
			total += metrics.rowsIn(group.height);
		}
		return total;
	}

	static function flanking(scale:Int, both:Bool):Void {
		final metrics = metricsFor(scale, 2);
		final groups = board();
		final grid = new Grid();

		grid.anchor(SCREEN, 0.5, Middle);
		seed(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);
		grid.adopt(groups);
		grid.place(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

		final screen = of(groups, SCREEN);
		var before = 0;
		var after = 0;

		for (group in groups) {
			if (group.empty() || group.id == SCREEN) continue;
			if (group.x + group.width <= screen.x + 1) before++;
			if (group.x >= screen.x + screen.width - 1) after++;
		}

		if (both) {
			ok("center " + scale + "x puts panels on both sides", before > 0 && after > 0,
				before + " to its left and " + after + " to its right");
			return;
		}

		ok("center " + scale + "x falls back to one side rather than shrinking a column",
			before == 0 || after == 0, before + " to its left and " + after + " to its right");
	}

	static function sided(side:Side):Void {
		final metrics = metricsFor(1, 2);
		final groups = board();
		final grid = new Grid();

		grid.anchor(SCREEN, 0.5, side);
		seed(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);
		grid.adopt(groups);
		grid.place(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

		final screen = of(groups, SCREEN);
		var before = 0;
		var after = 0;

		for (group in groups) {
			if (group.empty() || group.id == SCREEN) continue;
			if (group.x + group.width <= screen.x + 1) before++;
			if (group.x >= screen.x + screen.width - 1) after++;
		}

		switch (side) {
			case Left: ok("left puts the viewport leftmost", before == 0 && after > 0,
				before + " to its left and " + after + " to its right");
			case Right: ok("right puts the viewport rightmost", after == 0 && before > 0,
				before + " to its left and " + after + " to its right");
			case _: ok("center puts the viewport between them", before > 0 && after > 0,
				before + " to its left and " + after + " to its right");
		}
	}

	static function named(side:Side):String {
		return switch (side) {
			case Right: " right";
			case Middle: " center";
			case _: " left";
		}
	}

	static function floorCheck(layout:Layout, scale:Int, where:String):Void {
		final metrics = metricsFor(scale, 2);
		final groups = board();

		seed(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);
		layout.adopt(groups);
		layout.place(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

		final screen = of(groups, SCREEN);
		final least = smallest(groups, metrics);
		final rows = rowsIn(groups, metrics);

		Sys.println("  " + layout.name() + where + " " + scale + "x at " + FLOOR_WIDE + "x" + FLOOR_HIGH
			+ ": viewport " + Math.round(100 * screen.width / FLOOR_WIDE) + "%"
			+ ", smallest group " + Math.round(least) + " px"
			+ ", " + rows + " rows");

		ok(layout.name() + where + " " + scale + "x viewport", screen.width >= FLOOR_WIDE * 0.5 - 1,
			"the viewport is " + Math.round(screen.width) + " px of " + FLOOR_WIDE);

		ok(layout.name() + where + " " + scale + "x minimum group",
			least >= metrics.leastHigh - 1,
			"the smallest group is " + Math.round(least) + " px against a floor of "
				+ Math.round(metrics.leastHigh));

		var panels = 0;
		for (group in groups) panels += group.members.length;

		ok(layout.name() + where + " " + scale + "x keeps every panel", panels == 6,
			"six panels went in and " + panels + " are placed");
	}

	static function everyZone(layout:Layout):Void {
		final metrics = metricsFor(2, 2);
		final sides = [Side.Left, Side.Right, Side.Above, Side.Below, Side.Middle];

		for (side in sides) {
			final groups = board();
			seed(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);
			layout.adopt(groups);
			layout.place(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

			final moving = of(groups, "usage");
			final target = of(groups, "registers");

			final zone = new Zone();
			zone.set(side, target.id, target.x, target.y, target.width, target.height);
			layout.settle(groups, moving, zone);
			layout.place(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

			if (side == Side.Middle) {
				ok(layout.name() + " merge", target.holds("usage") && !moving.holds("usage"),
					"a middle drop did not move usage into the registers group");
				continue;
			}

			ok(layout.name() + " dock " + side, moving.holds("usage"),
				"usage lost its panel docking to side " + side);

			final apart = side == Side.Left ? moving.x < target.x
				: side == Side.Right ? moving.x > target.x
				: side == Side.Above ? moving.y < target.y
				: moving.y > target.y;

			ok(layout.name() + " side " + side, apart,
				"usage landed at " + Math.round(moving.x) + "," + Math.round(moving.y)
					+ " against registers at " + Math.round(target.x) + "," + Math.round(target.y));
		}
	}

	static function roundTrip(layout:Layout):Void {
		final metrics = metricsFor(2, 2);
		final groups = board();

		seed(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);
		layout.adopt(groups);

		final moving = of(groups, "usage");
		final target = of(groups, "registers");
		final zone = new Zone();
		zone.set(Side.Below, target.id, target.x, target.y, target.width, target.height);
		layout.settle(groups, moving, zone);
		layout.place(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

		final written = layout.save();

		final again = new Array<Group>();
		for (group in groups) {
			final copy = new Group(group.id);
			for (member in group.members) copy.add(member);
			copy.x = group.x;
			copy.y = group.y;
			copy.width = group.width;
			copy.height = group.height;
			again.push(copy);
		}

		layout.load(written, again);
		layout.place(again, FLOOR_WIDE, FLOOR_HIGH, metrics);

		ok(layout.name() + " round trip", layout.save() == written,
			"saved \"" + written + "\" and read back \"" + layout.save() + "\"");

		for (group in groups) {
			final mirror = of(again, group.id);
			if (mirror == null) {
				ok(layout.name() + " round trip groups", false, group.id + " went missing");
				continue;
			}
		}

		ok(layout.name() + " round trip count", again.length == groups.length,
			"had " + groups.length + " groups and read back " + again.length);
	}

	static function keepsPanels(first:Layout, second:Layout):Void {
		final metrics = metricsFor(2, 2);
		final groups = board();

		seed(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

		first.adopt(groups);
		first.place(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

		second.adopt(groups);
		second.place(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

		first.adopt(groups);
		first.place(groups, FLOOR_WIDE, FLOOR_HIGH, metrics);

		var panels = 0;
		for (group in groups) panels += group.members.length;

		ok("switching arrangement", panels == 6,
			"six panels went in and " + panels + " came back");
	}

	static function main():Void {
		run();
	}

	public static function run():Void {
		Sys.println("--- the layout model, with no window anywhere near it ---");

		for (scale in 1...4) {
			for (side in [Side.Left, Side.Middle, Side.Right]) {
				final tiled = new Grid();
				tiled.anchor(SCREEN, 0.5, side);
				floorCheck(tiled, scale, named(side));
			}
			floorCheck(new Floating(), scale, "");
		}

		sided(Left);
		sided(Middle);
		sided(Right);

		flanking(1, true);
		flanking(2, false);
		flanking(3, false);

		everyZone(new Grid());
		everyZone(new Floating());

		roundTrip(new Grid());
		roundTrip(new Floating());

		keepsPanels(new Grid(), new Floating());

		Sys.println("  " + checks + " layout checks, " + failures + " failures");
		if (failures > 0) Sys.exit(1);
	}
}

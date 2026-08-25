package hx68k.host;

class Group {
	public final id:String;

	public var x:Float = 0;
	public var y:Float = 0;
	public var width:Float = 0;
	public var height:Float = 0;

	public var order:Int = 0;

	public final members:Array<String> = [];

	public var active:Int = 0;

	public function new(id:String) {
		this.id = id;
	}

	public function add(panel:String):Void {
		if (members.indexOf(panel) >= 0) return;
		members.push(panel);
	}

	public function drop(panel:String):Bool {
		final at = members.indexOf(panel);
		if (at < 0) return false;

		members.splice(at, 1);
		if (active >= members.length) active = members.length - 1;
		if (active < 0) active = 0;
		return true;
	}

	public function holds(panel:String):Bool {
		return members.indexOf(panel) >= 0;
	}

	public function showing():Null<String> {
		return active >= 0 && active < members.length ? members[active] : null;
	}

	public function show(panel:String):Void {
		final at = members.indexOf(panel);
		if (at >= 0) active = at;
	}

	public function tabbed():Bool {
		return members.length > 1;
	}

	public function empty():Bool {
		return members.length == 0;
	}

	public static function written(groups:Array<Group>):String {
		final out = new Array<String>();

		for (group in groups) {
			out.push([
				group.id,
				Std.string(Math.round(group.x)),
				Std.string(Math.round(group.y)),
				Std.string(Math.round(group.width)),
				Std.string(Math.round(group.height)),
				Std.string(group.order),
				Std.string(group.active),
				group.members.join(",")
			].join(";"));
		}

		return out.join("|");
	}

	public static function restore(groups:Array<Group>, state:String):Int {
		if (state == "") return 0;

		final byId = new Map<String, Group>();
		for (group in groups) byId.set(group.id, group);

		var restored = 0;

		for (record in state.split("|")) {
			final parts = record.split(";");
			if (parts.length < 8) continue;

			final group = byId.get(parts[0]);
			if (group == null) continue;

			group.x = whole(parts[1], group.x);
			group.y = whole(parts[2], group.y);
			group.width = whole(parts[3], group.width);
			group.height = whole(parts[4], group.height);
			group.order = Std.int(whole(parts[5], group.order));

			while (group.members.length > 0) group.members.pop();
			for (member in parts[7].split(",")) if (member != "") group.add(member);

			group.active = Std.int(whole(parts[6], 0));
			if (group.active >= group.members.length) group.active = group.members.length - 1;
			if (group.active < 0) group.active = 0;

			restored++;
		}

		return restored;
	}

	static function whole(said:String, fallback:Float):Float {
		final parsed = Std.parseInt(said);
		return parsed == null ? fallback : parsed;
	}
}

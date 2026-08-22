package hx68k.map;

typedef Line = {
	final generated:Int;
	final file:Int;
	final line:Int;
}

typedef Function = {
	final symbol:String;
	final generated:Int;
	final file:Int;
	final line:Int;
	final name:String;
}

typedef Static = {
	final symbol:String;
	final file:Int;
	final line:Int;
	final name:String;
	final ctype:String;
}

typedef Site = {
	final file:String;
	final line:Int;
	final name:String;
}

class Hxmap {
	public final source:String;
	public final root:String;
	public final files:Array<String> = [];
	public final lines:Array<Line> = [];
	public final functions:Array<Function> = [];
	public final statics:Array<Static> = [];

	public function new(path:String) {
		var source = "";
		var root = "";

		for (text in sys.io.File.getContent(path).split("\n")) {
			final parts = text.split(" ");
			switch (parts[0]) {
				case "hxmap":
					if (parts[1] != "1") throw path + " is version " + parts[1] + ", expected 1";
				case "source": source = parts[1];
				case "root": root = parts[1];
				case "file": files[Std.parseInt(parts[1])] = parts[2];
				case "line": lines.push({
						generated: Std.parseInt(parts[1]),
						file: Std.parseInt(parts[2]),
						line: Std.parseInt(parts[3])
					});
				case "function": functions.push({
						symbol: parts[1],
						generated: Std.parseInt(parts[2]),
						file: Std.parseInt(parts[3]),
						line: Std.parseInt(parts[4]),
						name: parts[5]
					});
				case "static": statics.push({
						symbol: parts[1],
						file: Std.parseInt(parts[2]),
						line: Std.parseInt(parts[3]),
						name: parts[4],
						ctype: parts[5]
					});
				case _:
			}
		}

		this.source = source;
		this.root = root;
	}

	public function at(generated:Int):Null<Site> {
		var best:Null<Line> = null;
		for (record in lines) {
			if (record.generated > generated) continue;
			if (best == null || record.generated > best.generated) best = record;
		}

		var holder:Null<Function> = null;
		for (record in functions) {
			if (record.generated > generated) continue;
			if (holder == null || record.generated > holder.generated) holder = record;
		}

		if (holder != null && (best == null || holder.generated > best.generated))
			return {file: files[holder.file], line: holder.line, name: holder.name};
		if (best == null) return null;

		return {
			file: files[best.file],
			line: best.line,
			name: holder == null ? "" : holder.name
		};
	}
}

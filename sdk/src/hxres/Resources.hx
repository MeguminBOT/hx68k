package hxres;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

typedef Declared = {
	final line:String;
	final type:String;
	final symbol:String;
}

class Resources {
	static final KINDS = ["image", "palette", "sprite", "tileset", "music", "sound", "binary"];

	public static function build(target:String):Array<Field> {
		final fields = Context.getBuildFields();
		final lines = [];

		for (field in fields) {
			final declared = describe(field);
			if (declared == null) continue;

			lines.push(declared.line);
			field.kind = FVar(TPath({pack: ["md", "res"], name: declared.type}), null);
			field.access = [AStatic, APublic];
			field.meta.push({name: ":native", params: [macro $v{declared.symbol}], pos: field.pos});
		}

		if (lines.length > 0) write(target, lines);
		return fields;
	}

	static function describe(field:Field):Null<Declared> {
		for (entry in field.meta) {
			final kind = StringTools.startsWith(entry.name, ":") ? entry.name.substr(1) : entry.name;
			if (KINDS.indexOf(kind) < 0) continue;

			final arguments = entry.params.map(p -> constant(p));
			final file = source(arguments[0], entry.pos);

			return switch (kind) {
				case "image": {
					line: 'IMAGE ${field.name} "$file" ' + option(arguments, 1, "NONE"),
					type: "Image",
					symbol: '(&${field.name})'
				};
				case "palette": {
					line: 'PALETTE ${field.name} "$file"',
					type: "Palette",
					symbol: '(&${field.name})'
				};
				case "sprite": {
					if (arguments.length < 3)
						Context.error("A sprite needs its frame size: @:sprite(file, width, height).", entry.pos);
					{
						line: 'SPRITE ${field.name} "$file" ${arguments[1]} ${arguments[2]} '
							+ option(arguments, 3, "NONE") + " " + option(arguments, 4, "0"),
						type: "SpriteDefinition",
						symbol: '(&${field.name})'
					};
				}
				case "tileset": {
					line: 'TILESET ${field.name} "$file" ' + option(arguments, 1, "NONE"),
					type: "TileSet",
					symbol: '(&${field.name})'
				};
				case "music": {
					line: 'XGM ${field.name} "$file"',
					type: "Music",
					symbol: field.name
				};
				case "sound": {
					line: 'WAV ${field.name} "$file" ' + option(arguments, 1, "XGM"),
					type: "Sound",
					symbol: field.name
				};
				case _: {
					line: 'BIN ${field.name} "$file" ' + option(arguments, 1, "2"),
					type: "Binary",
					symbol: field.name
				};
			}
		}

		return null;
	}

	static function constant(e:Expr):String {
		return switch (e.expr) {
			case EConst(CString(s)): s;
			case EConst(CInt(v)): v;
			case EConst(CIdent(name)): name;
			case _: Context.error("A resource takes constants only.", e.pos);
		}
	}

	static function option(arguments:Array<String>, index:Int, fallback:String):String {
		return index < arguments.length ? arguments[index] : fallback;
	}

	static function source(path:String, pos:Position):String {
		if (!sys.FileSystem.exists(path))
			Context.error("No such resource: " + path, pos);
		return StringTools.replace(sys.FileSystem.absolutePath(path), "\\", "/");
	}

	static function write(target:String, lines:Array<String>):Void {
		final content = lines.join("\n") + "\n";
		if (sys.FileSystem.exists(target) && sys.io.File.getContent(target) == content) return;

		final directory = haxe.io.Path.directory(target);
		if (directory != "" && !sys.FileSystem.exists(directory)) sys.FileSystem.createDirectory(directory);
		sys.io.File.saveContent(target, content);
	}
}
#end

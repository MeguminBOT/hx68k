package hxres;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import hxres.Patterns.Optimisation;
import hxres.Patterns.Ordering;
import hxres.Sprite.Aim;

typedef Declared = {
	final line:String;
	final type:String;
	final symbol:String;
	final bytes:Int;
}

class Resources {
	static final KINDS = ["image", "palette", "sprite", "tileset", "music", "sound", "binary"];

	public static function build(name:String):Array<Field> {
		final fields = Context.getBuildFields();
		final emit = new Emit(name);
		final cuts = new Array<hxres.Frames.Cut>();
		final lines = [];

		final measured = [];

		for (field in fields) {
			final declared = describe(field, emit, cuts);
			if (declared == null) continue;

			if (declared.line != "") lines.push(declared.line);
			field.kind = FVar(TPath({pack: ["md", "res"], name: declared.type}), null);
			field.access = [AStatic, APublic];
			field.meta.push({name: ":native", params: [macro $v{declared.symbol}], pos: field.pos});

			if (declared.bytes >= 0) measured.push({
				name: field.name + "Length",
				doc: null,
				access: [AStatic, APublic, AInline],
				kind: FVar(macro :Int, macro $v{declared.bytes}),
				pos: field.pos,
				meta: []
			});
		}

		for (field in measured) fields.push(field);

		final mixed = !emit.empty() && lines.length > 0;
		final pending = name + "_pending";

		if (mixed) emit.include(pending + ".h");
		if (!emit.empty()) emit.write(generated());

		write(resources() + "/" + (mixed ? pending : name) + ".res", lines);
		write(resources() + "/" + (mixed ? name : pending) + ".res", []);
		return fields;
	}

	static function describe(field:Field, emit:Emit, cuts:Array<hxres.Frames.Cut>):Null<Declared> {
		for (entry in field.meta) {
			final kind = StringTools.startsWith(entry.name, ":") ? entry.name.substr(1) : entry.name;
			if (KINDS.indexOf(kind) < 0) continue;

			final arguments = entry.params.map(p -> constant(p));
			final file = source(arguments[0], entry.pos);
			final symbol = emit.name + "_" + field.name;

			return switch (kind) {
				case "image": {
					native(entry.pos, () -> {
						final picture = read(file, true);
						final patterns = Patterns.of(picture, Optimisation.Every, Ordering.Row, false);
						emit.image(symbol, picture, patterns,
							Cells.of(picture, patterns, 0, Optimisation.Every, Ordering.Row));
					});
					{line: "", type: "Image", symbol: '(&${symbol})', bytes: -1};
				}
				case "palette": {
					native(entry.pos, () -> emit.palette(symbol, read(file, false)));
					{line: "", type: "Palette", symbol: '(&${symbol})', bytes: -1};
				}
				case "tileset": {
					native(entry.pos, () -> {
						final picture = read(file, true);
						emit.tileset(symbol, Patterns.of(picture,
							optimisation(option(arguments, 1, "ALL"), entry.pos), Ordering.Row,
							false));
					});
					{line: "", type: "TileSet", symbol: '(&${symbol})', bytes: -1};
				}
				case "sprite": {
					if (arguments.length < 3)
						Context.error("A sprite needs its frame size: @:sprite(file, width, height).", entry.pos);
					native(entry.pos, () -> emit.sprite(symbol, new Frames(read(file, true),
						Std.parseInt(arguments[1]), Std.parseInt(arguments[2]),
						Std.parseInt(option(arguments, 4, "0")), Aim.Balanced, cuts)));
					{line: "", type: "SpriteDefinition", symbol: '(&${symbol})', bytes: -1};
				}
				case "music": {
					var bytes = 0;
					native(entry.pos, () -> bytes = emit.binary(symbol,
						hxres.music.Xgc.compile(sys.io.File.getBytes(file),
							number(arguments, 1, -1)),
						256, 256, 0, true, "NONE"));
					{line: "", type: "Music", symbol: symbol, bytes: bytes};
				}
				case "sound": {
					final driver = option(arguments, 1, "PCM");
					var bytes = 0;
					native(entry.pos, () -> bytes = emit.binary(symbol,
						hxres.Sounds.convert(sys.io.File.getBytes(file), driver,
							number(arguments, 2, 0)),
						hxres.Sounds.alignOf(driver), hxres.Sounds.alignOf(driver),
						hxres.Sounds.fillOf(driver),
						option(arguments, 3, "false") != "false", "NONE"));
					{line: "", type: "Sample", symbol: symbol, bytes: bytes};
				}
				case _: {
					var bytes = 0;
					native(entry.pos, () -> bytes = emit.binary(symbol,
						sys.io.File.getBytes(file),
						number(arguments, 1, 2), number(arguments, 2, 2), number(arguments, 3, 0),
						option(arguments, 4, "true") != "false", option(arguments, 5, "NONE")));
					{line: "", type: "Binary", symbol: symbol, bytes: bytes};
				}
			}
		}

		return null;
	}

	static function optimisation(named:String, pos:Position):Optimisation {
		return switch (named.toUpperCase()) {
			case "ALL" | "1": Optimisation.Every;
			case "DUPLICATE" | "2": Optimisation.Duplicates;
			case "NONE" | "0": Optimisation.Nothing;
			case _:
				Context.error(named + " is not an optimisation level. Use ALL, DUPLICATE or NONE.",
					pos);
				Optimisation.Every;
		}
	}

	static function native(pos:Position, work:Void->Void):Void {
		try {
			work();
		} catch (e:haxe.Exception) {
			Context.error(e.message, pos);
		}
	}

	static function read(file:String, aligned:Bool):Picture {
		final picture = Png.read(file);
		if (aligned && ((picture.width & 7) != 0 || (picture.height & 7) != 0))
			throw new haxe.Exception(file + " is " + picture.width + " by " + picture.height
				+ ", and both have to be a multiple of eight.");
		if (!picture.indexed())
			throw new haxe.Exception(file + " is a color image. Save it as an indexed PNG of "
				+ "sixteen or sixty four colors.");
		return picture;
	}

	static function generated():String {
		if (!Context.defined("md-output"))
			Context.error("Resources need -D md-output to say where the generated C goes.", Context.currentPos());
		return Context.definedValue("md-output");
	}

	static function resources():String {
		return haxe.io.Path.directory(haxe.io.Path.removeTrailingSlashes(generated())) + "/res";
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

	static function number(arguments:Array<String>, index:Int, fallback:Int):Int {
		if (index >= arguments.length) return fallback;
		final value = Std.parseInt(arguments[index]);
		return value == null ? fallback : value;
	}

	static function source(path:String, pos:Position):String {
		if (!sys.FileSystem.exists(path)) {
			final onPath = try Context.resolvePath(path) catch (_:Dynamic) null;
			if (onPath == null) Context.error("No such resource: " + path, pos);
			return StringTools.replace(sys.FileSystem.absolutePath(onPath), "\\", "/");
		}
		return StringTools.replace(sys.FileSystem.absolutePath(path), "\\", "/");
	}

	static function write(target:String, lines:Array<String>):Void {
		if (lines.length == 0) {
			if (sys.FileSystem.exists(target)) sys.FileSystem.deleteFile(target);
			return;
		}
		Emit.put(target, lines.join("\n") + "\n");
	}
}
#end

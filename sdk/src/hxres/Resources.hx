package hxres;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import hxres.Patterns.Optimisation;
import hxres.Patterns.Ordering;

typedef Declared = {
	final line:String;
	final type:String;
	final symbol:String;
}

class Resources {
	static final KINDS = ["image", "palette", "sprite", "tileset", "music", "sound", "binary"];

	public static function build(name:String):Array<Field> {
		final fields = Context.getBuildFields();
		final emit = new Emit(name);
		final lines = [];

		for (field in fields) {
			final declared = describe(field, emit);
			if (declared == null) continue;

			if (declared.line != "") lines.push(declared.line);
			field.kind = FVar(TPath({pack: ["md", "res"], name: declared.type}), null);
			field.access = [AStatic, APublic];
			field.meta.push({name: ":native", params: [macro $v{declared.symbol}], pos: field.pos});
		}

		final mixed = !emit.empty() && lines.length > 0;
		final pending = name + "_pending";

		if (mixed) emit.include(pending + ".h");
		if (!emit.empty()) emit.write(generated());

		write(resources() + "/" + (mixed ? pending : name) + ".res", lines);
		write(resources() + "/" + (mixed ? name : pending) + ".res", []);
		return fields;
	}

	static function describe(field:Field, emit:Emit):Null<Declared> {
		for (entry in field.meta) {
			final kind = StringTools.startsWith(entry.name, ":") ? entry.name.substr(1) : entry.name;
			if (KINDS.indexOf(kind) < 0) continue;

			final arguments = entry.params.map(p -> constant(p));
			final file = source(arguments[0], entry.pos);

			return switch (kind) {
				case "image": {
					native(entry.pos, () -> {
						final picture = read(file, true);
						final patterns = Patterns.of(picture, Optimisation.Every, Ordering.Row, false);
						emit.image(field.name, picture, patterns,
							Cells.of(picture, patterns, 0, Optimisation.Every, Ordering.Row));
					});
					{line: "", type: "Image", symbol: '(&${field.name})'};
				}
				case "palette": {
					native(entry.pos, () -> emit.palette(field.name, read(file, false)));
					{line: "", type: "Palette", symbol: '(&${field.name})'};
				}
				case "tileset": {
					native(entry.pos, () -> {
						final picture = read(file, true);
						emit.tileset(field.name, Patterns.of(picture, Optimisation.Every, Ordering.Row, false));
					});
					{line: "", type: "TileSet", symbol: '(&${field.name})'};
				}
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
					native(entry.pos, () -> emit.binary(field.name, sys.io.File.getBytes(file),
						option(arguments, 2, "0") != "0"));
					{line: "", type: "Binary", symbol: field.name};
				}
			}
		}

		return null;
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
			throw new haxe.Exception(file + " is a colour image. Save it as an indexed PNG of "
				+ "sixteen or sixty four colours.");
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

	static function source(path:String, pos:Position):String {
		if (!sys.FileSystem.exists(path))
			Context.error("No such resource: " + path, pos);
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

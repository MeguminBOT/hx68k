package hxres;

#if (macro || md_runtime)
import haxe.io.Bytes;

class Emit {
	static inline final PER_LINE = 8;

	static inline final NEAR = "__attribute__((section(\".rodata_bin\"), aligned(2)))";

	static inline final FAR = "__attribute__((section(\".rodata_binf\"), aligned(2)))";

	public final name:String;

	final blocks:Array<String> = [];
	final structures:Array<String> = [];
	final declarations:Array<String> = [];
	final includes:Array<String> = [];
	final shapes:Array<String> = [];
	final shared:Map<String, String> = new Map<String, String>();

	public function new(name:String) {
		this.name = name;
	}

	public function include(header:String):Void {
		includes.push("#include \"" + header + "\"");
	}

	public inline function empty():Bool {
		return declarations.length == 0;
	}

	public function palette(symbol:String, picture:Picture):Void {
		final colors = entries(picture);
		final data = block(symbol + "_data", "u16", words(colors), false);
		structures.push("const Palette " + symbol + " = { " + colors.length + ", (u16*)" + data + " };");
		declarations.push("extern const Palette " + symbol + ";");
	}

	public function tileset(symbol:String, patterns:Patterns):Void {
		final data = block(symbol + "_data", "u32", longs(patterns.data()), false);
		structures.push("const TileSet " + symbol + " = { 0, " + patterns.count() + ", (u32*)" + data + " };");
		declarations.push("extern const TileSet " + symbol + ";");
	}

	public function image(symbol:String, picture:Picture, patterns:Patterns, cells:Cells):Void {
		final colors = entries(picture);
		final tiles = block(symbol + "_tileset_data", "u32", longs(patterns.data()), false);
		final map = block(symbol + "_tilemap_data", "u16", words(cells.entries), false);
		final palette = block(symbol + "_palette_data", "u16", words(colors), false);

		structures.push("static const TileSet " + symbol + "_tileset = { 0, " + patterns.count()
			+ ", (u32*)" + tiles + " };");
		structures.push("static const TileMap " + symbol + "_tilemap = { 0, " + cells.across + ", " + cells.down
			+ ", (u16*)" + map + " };");
		structures.push("static const Palette " + symbol + "_palette = { " + colors.length
			+ ", (u16*)" + palette + " };");
		structures.push("const Image " + symbol + " = { (Palette*)&" + symbol + "_palette, (TileSet*)&" + symbol
			+ "_tileset, (TileMap*)&" + symbol + "_tilemap };");
		declarations.push("extern const Image " + symbol + ";");
	}

	public function sprite(symbol:String, frames:Frames):Void {
		final palette = block(symbol + "_palette_data", "u16", words(frames.palette), false);
		structures.push("static const Palette " + symbol + "_palette = { " + frames.palette.length
			+ ", (u16*)" + palette + " };");

		final named = new Array<String>();

		for (index in 0...frames.animations.length) {
			final animation = frames.animations[index];
			final stem = symbol + "_animation" + index;
			final held = new Array<String>();

			for (at in 0...animation.frames.length) {
				final frame = animation.frames[at];
				final own = stem + "_frame" + at;
				final tiles = block(own + "_tileset_data", "u32", longs(frame.patterns.data()), false);

				structures.push("static const TileSet " + own + "_tileset = { 0, " + frame.patterns.count()
					+ ", (u32*)" + tiles + " };");

				shape(frame.pieces.length);

				final pieces = frame.pieces.map(piece -> "{ " + piece.bytes().join(", ") + " }");
				structures.push("static const " + shapeName(frame.pieces.length) + " " + own + " = { "
					+ frame.leading() + ", " + frame.timer + ", (TileSet*)&" + own + "_tileset, NULL, {"
					+ NEWLINE + "\t" + pieces.join("," + NEWLINE + "\t") + NEWLINE + "} };");

				held.push("(AnimationFrame*)&" + own);
			}

			structures.push("static AnimationFrame* const " + stem + "_frames[] = {" + NEWLINE
				+ held.map(one -> "\t" + one).join("," + NEWLINE) + NEWLINE + "};");
			structures.push("static const Animation " + stem + " = { " + animation.frames.length + ", "
				+ animation.loop + ", (AnimationFrame**)" + stem + "_frames };");
			named.push(stem);
		}

		structures.push("static Animation* const " + symbol + "_animations[] = {" + NEWLINE
			+ named.map(one -> "\t(Animation*)&" + one).join("," + NEWLINE) + NEWLINE + "};");

		structures.push("const SpriteDefinition " + symbol + " = { " + (frames.across * 8) + ", "
			+ (frames.down * 8) + ", (Palette*)&" + symbol + "_palette, " + frames.animations.length
			+ ", (Animation**)" + symbol + "_animations, " + frames.mostPatterns() + ", "
			+ frames.mostPieces() + " };");

		declarations.push("extern const SpriteDefinition " + symbol + ";");
	}

	function shape(pieces:Int):Void {
		final name = shapeName(pieces);
		if (shapes.indexOf(name) >= 0) return;
		shapes.push(name);
		declarations.push("typedef struct {" + NEWLINE
			+ "\ts8 numSprite;" + NEWLINE
			+ "\tu8 timer;" + NEWLINE
			+ "\tTileSet* tileset;" + NEWLINE
			+ "\tvoid* collision;" + NEWLINE
			+ "\tFrameVDPSprite pieces[" + pieces + "];" + NEWLINE
			+ "} " + name + ";");
	}

	static inline function shapeName(pieces:Int):String {
		return "hxres_frame" + pieces;
	}

	public function binary(symbol:String, data:Bytes, align:Int, sizeAlign:Int, fill:Int, far:Bool,
			squeeze:String):Int {
		final sizedData = sized(data, sizeAlign, fill);

		final squeezed = switch (squeeze.toUpperCase()) {
			case "NONE" | "0": sizedData;
			case "APLIB" | "1": Aplib.pack(sizedData);
			case "LZ4W" | "FAST" | "2": Lz4w.pack(sizedData);
			case _: throw new haxe.Exception(squeeze + " is not a compression this knows. "
				+ "Use NONE, APLIB or LZ4W.");
		}

		if (squeeze.toUpperCase() != "NONE" && squeeze != "0")
			declarations.push("#define " + symbol + "_unpacked " + sizedData.length);

		final padded = evened(squeezed);
		final values = new Array<String>();
		for (i in 0...padded.length) values.push("0x" + StringTools.hex(padded.get(i), 2));

		blocks.push("const u8 " + symbol + "[" + padded.length + "] " + placed(far, align) + " = {"
			+ NEWLINE + laid(values) + NEWLINE + "};");
		declarations.push("extern const u8 " + symbol + "[" + padded.length + "];");
		return padded.length;
	}

	public static function evened(data:Bytes):Bytes {
		if ((data.length & 1) == 0) return data;

		final out = Bytes.alloc(data.length + 1);
		out.blit(0, data, 0, data.length);
		out.set(data.length, 0);
		return out;
	}

	public static function sized(data:Bytes, align:Int, fill:Int):Bytes {
		if (align <= 0) return data;

		final whole = Std.int((data.length + (align - 1)) / align) * align;
		if (whole == data.length) return data;

		final out = Bytes.alloc(whole);
		out.blit(0, data, 0, data.length);
		for (i in data.length...whole) out.set(i, fill & 0xFF);
		return out;
	}

	static function placed(far:Bool, align:Int):String {
		return "__attribute__((section(\"" + (far ? ".rodata_binf" : ".rodata_bin") + "\"), aligned("
			+ (align < 2 ? 2 : align) + ")))";
	}

	public function source():String {
		return "#include \"" + name + ".h\"" + NEWLINE + NEWLINE
			+ blocks.join(NEWLINE + NEWLINE) + NEWLINE + NEWLINE
			+ structures.join(NEWLINE) + NEWLINE;
	}

	public function header():String {
		final guard = "_RES_" + name.toUpperCase() + "_H_";
		final opening = includes.length > 0 ? includes.join(NEWLINE) + NEWLINE + NEWLINE : "";
		return "#include \"hx.h\"" + NEWLINE + NEWLINE
			+ "#ifndef " + guard + NEWLINE + "#define " + guard + NEWLINE + NEWLINE
			+ opening + declarations.join(NEWLINE) + NEWLINE + NEWLINE
			+ "#endif" + NEWLINE;
	}

	public function write(into:String):Void {
		put(into + "/" + name + ".c", source());
		put(into + "/" + name + ".h", header());
	}

	public static function put(path:String, content:String):Void {
		if (sys.FileSystem.exists(path) && sys.io.File.getContent(path) == content) return;
		final directory = haxe.io.Path.directory(path);
		if (directory != "" && !sys.FileSystem.exists(directory)) sys.FileSystem.createDirectory(directory);
		sys.io.File.saveContent(path, content);
	}

	function block(symbol:String, type:String, values:Array<String>, far:Bool):String {
		final body = laid(values);
		final already = shared.get(type + body);
		if (already != null) return already;

		blocks.push("static const " + type + " " + symbol + "[" + values.length + "] " + (far ? FAR : NEAR)
			+ " = {" + NEWLINE + body + NEWLINE + "};");
		shared.set(type + body, symbol);
		return symbol;
	}

	static var NEWLINE(get, never):String;

	static inline function get_NEWLINE():String {
		return String.fromCharCode(10);
	}

	static function laid(values:Array<String>):String {
		final lines = new Array<String>();
		var at = 0;
		while (at < values.length) {
			final take = values.length - at < PER_LINE ? values.length - at : PER_LINE;
			lines.push("\t" + values.slice(at, at + take).join(", "));
			at += take;
		}
		return lines.join("," + NEWLINE);
	}

	static function entries(picture:Picture):Array<Int> {
		final all = picture.entries(0x0EEE);
		return all.length > 64 ? all.slice(0, 64) : all;
	}

	static function words(values:Array<Int>):Array<String> {
		return values.map(value -> "0x" + StringTools.hex(value & 0xFFFF, 4));
	}

	static function longs(values:Array<Int>):Array<String> {
		return values.map(value -> "0x" + StringTools.hex(value, 8));
	}
}
#end

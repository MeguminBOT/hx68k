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
		final colours = entries(picture);
		final data = block(symbol + "_data", "u16", words(colours), false);
		structures.push("const Palette " + symbol + " = { " + colours.length + ", (u16*)" + data + " };");
		declarations.push("extern const Palette " + symbol + ";");
	}

	public function tileset(symbol:String, patterns:Patterns):Void {
		final data = block(symbol + "_data", "u32", longs(patterns.data()), false);
		structures.push("const TileSet " + symbol + " = { 0, " + patterns.count() + ", (u32*)" + data + " };");
		declarations.push("extern const TileSet " + symbol + ";");
	}

	public function image(symbol:String, picture:Picture, patterns:Patterns, cells:Cells):Void {
		final colours = entries(picture);
		final tiles = block(symbol + "_tileset_data", "u32", longs(patterns.data()), false);
		final map = block(symbol + "_tilemap_data", "u16", words(cells.entries), false);
		final palette = block(symbol + "_palette_data", "u16", words(colours), false);

		structures.push("static const TileSet " + symbol + "_tileset = { 0, " + patterns.count()
			+ ", (u32*)" + tiles + " };");
		structures.push("static const TileMap " + symbol + "_tilemap = { 0, " + cells.across + ", " + cells.down
			+ ", (u16*)" + map + " };");
		structures.push("static const Palette " + symbol + "_palette = { " + colours.length
			+ ", (u16*)" + palette + " };");
		structures.push("const Image " + symbol + " = { (Palette*)&" + symbol + "_palette, (TileSet*)&" + symbol
			+ "_tileset, (TileMap*)&" + symbol + "_tilemap };");
		declarations.push("extern const Image " + symbol + ";");
	}

	public function binary(symbol:String, data:Bytes, far:Bool):Void {
		final values = new Array<String>();
		for (i in 0...data.length) values.push("0x" + StringTools.hex(data.get(i), 2));
		blocks.push("const u8 " + symbol + "[" + data.length + "] " + (far ? FAR : NEAR) + " = {"
			+ NEWLINE + laid(values) + NEWLINE + "};");
		declarations.push("extern const u8 " + symbol + "[" + data.length + "];");
	}

	public function source():String {
		return "#include \"" + name + ".h\"" + NEWLINE + NEWLINE
			+ blocks.join(NEWLINE + NEWLINE) + NEWLINE + NEWLINE
			+ structures.join(NEWLINE) + NEWLINE;
	}

	public function header():String {
		final guard = "_RES_" + name.toUpperCase() + "_H_";
		final opening = includes.length > 0 ? includes.join(NEWLINE) + NEWLINE + NEWLINE : "";
		return "#include <genesis.h>" + NEWLINE + NEWLINE
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

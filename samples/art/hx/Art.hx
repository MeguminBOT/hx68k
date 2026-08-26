package;

@:build(hxres.Resources.build("art"))
@:md.include("art.h")
extern class Art {
	@:image("gfx/blocks.png") static var blocks;
	@:palette("gfx/blocks.png") static var blockPalette;
	@:sprite("gfx/diamond.png", 2, 2) static var diamond;
	@:tileset("gfx/blocks.png") static var blockTiles;
	@:music("audio/tune.vgm") static var tune;
	@:binary("data/table.dat", 2, 16, 0xAA) static var table;
	@:binary("data/table.dat", 2, 16, 0xAA, true, "APLIB") static var squeezed;
	@:binary("data/table.dat", 2, 16, 0xAA, true, "LZ4W") static var wordSqueezed;
	@:binary("data/spread.dat", 2, 1, 0x00, true, "LZ4W") static var sweep;
}

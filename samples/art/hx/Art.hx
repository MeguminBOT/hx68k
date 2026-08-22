package;

@:build(hxres.Resources.build("rom/res/art.res"))
@:md.include("art.h")
extern class Art {
	@:image("gfx/blocks.png") static var blocks;
	@:palette("gfx/blocks.png") static var blockPalette;
	@:sprite("gfx/diamond.png", 2, 2) static var diamond;
	@:music("audio/tune.vgm") static var tune;
}

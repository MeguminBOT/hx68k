package md;

@:build(hxres.Resources.build("mdfonts"))
@:md.include("mdfonts.h")
extern class Fonts {
	@:tileset("md/fonts/default.png", "NONE") static var normal;
}

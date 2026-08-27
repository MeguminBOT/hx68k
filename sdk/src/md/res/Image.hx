package md.res;

@:md.type("const Image*")
extern class Image {
	var palette(default, null):md.res.Palette;
	var tileset(default, null):md.res.TileSet;
	var tilemap(default, null):md.res.TileMap;
}

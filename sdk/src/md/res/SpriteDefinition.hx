package md.res;

import md.UInt16;
import md.Vector;

@:md.type("const SpriteDefinition*")
extern class SpriteDefinition {
	@:native("w") var width(default, null):UInt16;
	@:native("h") var height(default, null):UInt16;
	var palette(default, null):md.res.Palette;
	@:native("numAnimation") var animationCount(default, null):UInt16;
	var animations(default, null):Vector<md.res.Animation>;
	@:native("maxNumTile") var mostTiles(default, null):UInt16;
	@:native("maxNumSprite") var mostPieces(default, null):UInt16;
}

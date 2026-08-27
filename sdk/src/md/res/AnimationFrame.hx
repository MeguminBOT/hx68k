package md.res;

import md.Int8;
import md.UInt8;

@:md.type("AnimationFrame*")
extern class AnimationFrame {
	@:native("numSprite") var pieces(default, null):Int8;
	var timer(default, null):UInt8;
	var tileset(default, null):md.res.TileSet;
}

package md.res;

import md.UInt16;
import md.Vector;

@:md.type("const TileMap*")
extern class TileMap {
	var compression(default, null):UInt16;
	@:native("w") var across(default, null):UInt16;
	@:native("h") var down(default, null):UInt16;
	@:native("tilemap") var data(default, null):Vector<UInt16>;
}

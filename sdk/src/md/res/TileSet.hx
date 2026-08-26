package md.res;

import md.UInt16;
import md.UInt32;
import md.Vector;

@:md.type("const TileSet*")
extern class TileSet {
	var compression(default, null):UInt16;
	@:native("numTile") var count(default, null):UInt16;
	@:native("tiles") var data(default, null):Vector<UInt32>;
}

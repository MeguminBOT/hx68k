package sgdk;

import md.Plane;
import md.UInt16;
import md.UInt32;
import md.UInt8;
import md.Vector;

@:md.include("genesis.h")
extern class Tilemap {
	@:native("VDP_setPlaneSize") static function setPlaneSize(w:UInt16, h:UInt16, setupVram:Bool):Void;
	@:native("VDP_getPlaneWidth") static function columns():UInt16;
	@:native("VDP_getPlaneHeight") static function rows():UInt16;
	@:native("VDP_getPlaneAddress") static function address(plane:Plane, x:UInt16, y:UInt16):UInt16;

	@:native("VDP_setTileMapXY") static function setCell(plane:Plane, cell:UInt16, x:UInt16, y:UInt16):Void;
	@:native("VDP_fillTileMapRect") static function fill(plane:Plane, cell:UInt16, x:UInt16, y:UInt16,
		w:UInt16, h:UInt16):Void;
	@:native("VDP_fillTileMapRectInc") static function fillIncrementing(plane:Plane, cell:UInt16,
		x:UInt16, y:UInt16, w:UInt16, h:UInt16):Void;
	@:native("VDP_clearTileMapRect") static function clear(plane:Plane, x:UInt16, y:UInt16,
		w:UInt16, h:UInt16):Void;
	@:native("VDP_clearPlane") static function clearPlane(plane:Plane, wait:Bool):Void;

	@:native("VDP_loadTileData") static function setPatterns(data:Vector<UInt32>, index:UInt16,
		count:UInt16, how:Transfer):Void;
	@:native("VDP_fillTileData") static function fillPatterns(value:UInt8, index:UInt16, count:UInt16,
		wait:Bool):Void;
	@:native("VDP_loadTileSet") static function setPatternsFromResource(tiles:md.res.TileSet,
		index:UInt16, how:Transfer):Bool;
}

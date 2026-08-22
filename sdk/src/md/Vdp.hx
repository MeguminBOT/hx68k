package md;

extern class Vdp {
	@:native("VDP_init") static function init():Void;
	@:native("VDP_resetScreen") static function resetScreen():Void;
	@:native("VDP_setEnable") static function setEnable(on:Bool):Void;
	@:native("VDP_isEnable") static function isEnabled():Bool;

	@:native("VDP_setReg") static function setRegister(index:UInt16, value:UInt8):Void;
	@:native("VDP_getReg") static function register(index:UInt16):UInt8;
	@:native("VDP_setAutoInc") static function setAutoIncrement(value:UInt8):Void;
	@:native("VDP_getAutoInc") static function autoIncrement():UInt8;

	@:native("VDP_setScreenWidth320") static function setWidth320():Void;
	@:native("VDP_setScreenWidth256") static function setWidth256():Void;
	@:native("VDP_getScreenWidth") static function width():UInt16;
	@:native("VDP_getScreenHeight") static function height():UInt16;
	@:native("VDP_setPlaneSize") static function setPlaneSize(w:UInt16, h:UInt16, setupVram:Bool):Void;
	@:native("VDP_getPlaneWidth") static function planeWidth():UInt16;
	@:native("VDP_getPlaneHeight") static function planeHeight():UInt16;
	@:native("VDP_getPlaneAddress") static function planeAddress(plane:Plane, x:UInt16, y:UInt16):UInt16;

	@:native("VDP_setBackgroundColor") static function setBackgroundColour(index:UInt8):Void;
	@:native("VDP_getBackgroundColor") static function backgroundColour():UInt8;

	@:native("VDP_setHorizontalScroll") static function setHorizontalScroll(plane:Plane, value:Int16):Void;
	@:native("VDP_setVerticalScroll") static function setVerticalScroll(plane:Plane, value:Int16):Void;
	@:native("VDP_setHIntCounter") static function setHorizontalInterruptCounter(value:UInt8):Void;
	@:native("VDP_setHInterrupt") static function setHorizontalInterrupt(on:Bool):Void;

	@:native("VDP_clearPlane") static function clearPlane(plane:Plane, wait:Bool):Void;
	@:native("VDP_clearTileMapRect") static function clearTiles(plane:Plane, x:UInt16, y:UInt16,
		w:UInt16, h:UInt16):Void;
	@:native("VDP_setTileMapXY") static function setTile(plane:Plane, tile:UInt16, x:UInt16, y:UInt16):Void;
	@:native("VDP_fillTileMapRect") static function fillTiles(plane:Plane, tile:UInt16, x:UInt16, y:UInt16,
		w:UInt16, h:UInt16):Void;
	@:native("VDP_fillTileMapRectInc") static function fillTilesIncrementing(plane:Plane, tile:UInt16,
		x:UInt16, y:UInt16, w:UInt16, h:UInt16):Void;

	@:native("VDP_loadTileData") static function loadTiles(data:Vector<UInt32>, index:UInt16, count:UInt16,
		how:Transfer):Void;
	@:native("VDP_fillTileData") static function fillTileData(value:UInt8, index:UInt16, count:UInt16,
		wait:Bool):Void;
	@:native("VDP_loadDefaultFont") static function loadDefaultFont(how:Transfer):Bool;
	@:native("VDP_drawImage") static function drawImage(plane:Plane, image:md.res.Image, x:UInt16,
		y:UInt16):Bool;
	@:native("VDP_drawImageEx") static function drawImageOn(plane:Plane, image:md.res.Image,
		baseTile:UInt16, x:UInt16, y:UInt16, loadPalette:Bool, dma:Bool):Bool;
	@:native("VDP_loadTileSet") static function loadTileSet(tiles:md.res.TileSet, index:UInt16,
		how:Transfer):Bool;
	@:native("VDP_getSpriteListAddress") static function spriteListAddress():UInt16;

	@:native("VDP_drawText") static function drawText(text:String, x:UInt16, y:UInt16):Void;
	@:native("VDP_drawTextBG") static function drawTextOn(plane:Plane, text:String, x:UInt16, y:UInt16):Void;
	@:native("VDP_drawNum") static function drawNumber(value:Int, x:UInt16, y:UInt16):Void;
	@:native("VDP_clearText") static function clearText(x:UInt16, y:UInt16, w:UInt16):Void;
	@:native("VDP_clearTextLine") static function clearTextLine(y:UInt16):Void;
	@:native("VDP_setTextPalette") static function setTextPalette(palette:UInt16):Void;
	@:native("VDP_setTextPlane") static function setTextPlane(plane:Plane):Void;

	@:native("VDP_getScanlineNumber") static function scanline():UInt16;
	@:native("VDP_waitVSync") static function waitVSync():Bool;
	@:native("VDP_waitVBlank") static function waitVBlank(forceNext:Bool):Bool;
	@:native("VDP_waitDMACompletion") static function waitDma():Void;
	@:native("VDP_waitFIFOEmpty") static function waitFifo():Void;
}

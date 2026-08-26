package md.sgdk;

import md.Int16;
import md.Transfer;
import md.UInt16;
import md.UInt8;

extern class SpriteTable {
	@:native("VDP_getSpriteListAddress") static function base():UInt16;
	@:native("VDP_clearSprites") static function clear():Void;
	@:native("VDP_setSpriteFull") static function set(index:UInt16, x:Int16, y:Int16, size:UInt8,
		attribut:UInt16, link:UInt8):Void;
	@:native("VDP_setSprite") static function setWithoutLink(index:UInt16, x:Int16, y:Int16,
		size:UInt8, attribut:UInt16):Void;
	@:native("VDP_setSpritePosition") static function setPosition(index:UInt16, x:Int16, y:Int16):Void;
	@:native("VDP_setSpriteSize") static function setShape(index:UInt16, size:UInt8):Void;
	@:native("VDP_setSpriteAttribut") static function setAttribute(index:UInt16, attribut:UInt16):Void;
	@:native("VDP_setSpriteLink") static function setNext(index:UInt16, link:UInt8):Void;
	@:native("VDP_updateSprites") static function update(count:UInt16, how:Transfer):Void;
}

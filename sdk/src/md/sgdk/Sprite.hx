package md.sgdk;

import md.Int16;
import md.UInt16;
import md.res.SpriteDefinition;

@:md.type("Sprite*")
extern class SpriteHandle {}

extern class Sprite {
	@:native("SPR_init") static function init():Void;
	@:native("SPR_initEx") static function initWithVram(vramSize:UInt16):Void;
	@:native("SPR_reset") static function reset():Void;
	@:native("SPR_clear") static function clear():Void;
	@:native("SPR_update") static function update():Void;
	@:native("SPR_isInitialized") static function ready():Bool;

	@:native("SPR_addSprite") static function add(definition:SpriteDefinition, x:Int16, y:Int16,
		attribute:UInt16):SpriteHandle;
	@:native("SPR_releaseSprite") static function release(sprite:SpriteHandle):Void;

	@:native("SPR_setPosition") static function setPosition(sprite:SpriteHandle, x:Int16, y:Int16):Void;
	@:native("SPR_setVisibility") static function setVisibility(sprite:SpriteHandle, value:Int):Void;
	@:native("SPR_setPalette") static function setPalette(sprite:SpriteHandle, palette:UInt16):Void;
	@:native("SPR_setFrame") static function setFrame(sprite:SpriteHandle, frame:UInt16):Void;
	@:native("SPR_setAnim") static function setAnimation(sprite:SpriteHandle, animation:UInt16):Void;
	@:native("SPR_setDepth") static function setDepth(sprite:SpriteHandle, depth:Int16):Void;
}

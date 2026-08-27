package sgdk;

import md.UInt16;
import md.Vector;

@:md.include("genesis.h")
extern class Palette {
	@:native("PAL_setColor") static function setColor(index:UInt16, value:UInt16):Void;
	@:native("PAL_getColor") static function color(index:UInt16):UInt16;
	@:native("PAL_setColors") static function setColors(index:UInt16, from:Vector<UInt16>, count:UInt16,
		how:Transfer):Void;
	@:native("PAL_getColors") static function colors(index:UInt16, into:Vector<UInt16>, count:UInt16):Void;

	@:native("PAL_setPaletteColors") static function setFromResource(index:UInt16,
		palette:md.res.Palette, how:Transfer):Void;
	@:native("PAL_setPalette") static function setPalette(which:UInt16, from:Vector<UInt16>, how:Transfer):Void;
	@:native("PAL_getPalette") static function palette(which:UInt16, into:Vector<UInt16>):Void;

	@:native("PAL_fadeTo") static function fadeTo(fromColor:UInt16, toColor:UInt16, target:Vector<UInt16>,
		frames:UInt16, async:Bool):Void;
	@:native("PAL_fadeOut") static function fadeOut(fromColor:UInt16, toColor:UInt16, frames:UInt16,
		async:Bool):Void;
	@:native("PAL_doFadeStep") static function stepFade():Bool;
	@:native("PAL_isDoingFade") static function fading():Bool;
	@:native("PAL_interruptFade") static function stopFade():Void;
	@:native("PAL_waitFadeCompletion") static function waitFade():Void;
}

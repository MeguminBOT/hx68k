package md.sgdk;

import md.UInt16;
import md.UInt32;

extern class System {
	@:native("SYS_doVBlankProcess") static function doVBlankProcess():Bool;
	@:native("SYS_nextFrame") static function nextFrame():Bool;
	@:native("SYS_isInVInt") static function inVerticalInterrupt():Bool;

	@:native("SYS_disableInts") static function disableInterrupts():Void;
	@:native("SYS_enableInts") static function enableInterrupts():Void;
	@:native("SYS_setInterruptMaskLevel") static function setInterruptMask(level:UInt16):Void;
	@:native("SYS_getInterruptMaskLevel") static function interruptMask():UInt16;

	@:native("SYS_isNTSC") static function isNtsc():UInt16;
	@:native("SYS_isPAL") static function isPal():UInt16;
	@:native("SYS_getFPS") static function framesPerSecond():UInt32;
	@:native("SYS_getCPULoad") static function cpuLoad():UInt16;
	@:native("SYS_getStackPointer") static function stackPointer():UInt32;

	@:native("SYS_computeChecksum") static function checksum():UInt16;
	@:native("SYS_isChecksumOk") static function checksumOk():Bool;

	@:native("SYS_setVIntCallback") static function onVerticalInterrupt(handler:Void->Void):Void;
	@:native("SYS_setHIntCallback") static function onHorizontalInterrupt(handler:Void->Void):Void;
	@:native("SYS_setExtIntCallback") static function onExternalInterrupt(handler:Void->Void):Void;
	@:native("SYS_setVBlankCallback") static function onVBlank(handler:Void->Void):Void;

	@:native("SYS_reset") static function reset():Void;
	@:native("SYS_hardReset") static function hardReset():Void;
}

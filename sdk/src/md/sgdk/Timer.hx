package md.sgdk;

import md.UInt16;
import md.UInt32;

extern class Timer {
	@:native("getTick") static function tick():UInt32;
	@:native("getSubTick") static function subTick():UInt32;
	@:native("getTime") static function time(fromTick:UInt16):UInt32;

	@:native("startTimer") static function start(which:UInt16):Void;
	@:native("getTimer") static function elapsed(which:UInt16, restart:UInt16):UInt32;

	@:native("waitTick") static function waitTicks(count:UInt32):Void;
	@:native("waitSubTick") static function waitSubTicks(count:UInt32):Void;
	@:native("waitMs") static function waitMilliseconds(count:UInt32):Void;
}

package md;

extern class Z80Bus {
	@:native("Z80_init") static function init():Void;
	@:native("Z80_requestBus") static function request(wait:Bool):Void;
	@:native("Z80_getAndRequestBus") static function requestAndReport(wait:Bool):Bool;
	@:native("Z80_releaseBus") static function release():Void;
	@:native("Z80_isBusTaken") static function taken():Bool;

	@:native("Z80_startReset") static function startReset():Void;
	@:native("Z80_endReset") static function endReset():Void;
	@:native("Z80_clear") static function clear():Void;

	@:native("Z80_read") static function read(at:UInt16):UInt8;
	@:native("Z80_write") static function write(at:UInt16, value:UInt8):Void;
	@:native("Z80_upload") static function upload(to:UInt16, data:Vector<UInt8>, size:UInt16):Void;
	@:native("Z80_download") static function download(from:UInt16, into:Vector<UInt8>, size:UInt16):Void;
	@:native("Z80_setBank") static function setBank(bank:UInt16):Void;
}

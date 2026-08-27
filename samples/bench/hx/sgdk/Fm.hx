package sgdk;

import md.UInt16;
import md.UInt8;

@:md.include("genesis.h")
extern class Fm {
	@:native("YM2612_reset") static function reset():Void;
	@:native("YM2612_readStatus") static function status():UInt8;
	@:native("YM2612_writeReg") static function setRegister(bank:UInt16, register:UInt8,
		value:UInt8):Void;
	@:native("YM2612_enableDAC") static function enableDac():Void;
	@:native("YM2612_disableDAC") static function disableDac():Void;
}

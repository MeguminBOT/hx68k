package sgdk;

import md.UInt16;
import md.UInt8;

@:md.include("genesis.h")
extern class Psg {
	@:native("PSG_reset") static function reset():Void;
	@:native("PSG_write") static function write(value:UInt8):Void;
	@:native("PSG_setEnvelope") static function setAttenuation(channel:UInt8, level:UInt8):Void;
	@:native("PSG_setTone") static function setTone(channel:UInt8, value:UInt16):Void;
	@:native("PSG_setFrequency") static function setFrequency(channel:UInt8, hertz:UInt16):Void;
	@:native("PSG_setNoise") static function setNoise(white:UInt8, rate:UInt8):Void;
}

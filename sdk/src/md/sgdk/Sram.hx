package md.sgdk;

import md.UInt16;
import md.UInt32;
import md.UInt8;

extern class Sram {
	@:native("SRAM_enable") static function enable():Void;
	@:native("SRAM_enableRO") static function enableReadOnly():Void;
	@:native("SRAM_disable") static function disable():Void;

	@:native("SRAM_readByte") static function readByte(offset:UInt32):UInt8;
	@:native("SRAM_readWord") static function readWord(offset:UInt32):UInt16;
	@:native("SRAM_readLong") static function readLong(offset:UInt32):UInt32;

	@:native("SRAM_writeByte") static function writeByte(offset:UInt32, value:UInt8):Void;
	@:native("SRAM_writeWord") static function writeWord(offset:UInt32, value:UInt16):Void;
	@:native("SRAM_writeLong") static function writeLong(offset:UInt32, value:UInt32):Void;
}

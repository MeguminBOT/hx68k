package md;

extern class Memory {
	static function readU8(address:Int):Int;
	static function readU16(address:Int):Int;
	static function readU32(address:Int):Int;
	static function writeU8(address:Int, value:Int):Void;
	static function writeU16(address:Int, value:Int):Void;
	static function writeU32(address:Int, value:Int):Void;
}

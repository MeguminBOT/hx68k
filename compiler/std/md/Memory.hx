package md;

extern class Memory {
	static function readU8(address:Int):Int;
	static function readU16(address:Int):Int;
	static function readU32(address:Int):Int;
	static function writeU8(address:Int, value:Int):Void;
	static function writeU16(address:Int, value:Int):Void;
	static function writeU32(address:Int, value:Int):Void;

	static function loadU8(address:Int):Int;
	static function loadU16(address:Int):Int;
	static function loadU32(address:Int):Int;
	static function storeU8(address:Int, value:Int):Void;
	static function storeU16(address:Int, value:Int):Void;
	static function storeU32(address:Int, value:Int):Void;

	static function addressOf<T>(value:T):Int;
}

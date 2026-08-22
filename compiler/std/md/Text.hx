package md;

extern class Text {
	static function length(s:String):Int;

	static function charAt(s:String, index:Int):Int;

	static function address(s:String):Int;

	static function pointer<T>(v:Vector<T>):Int;

	static function of(buffer:Vector<UInt8>):String;
}

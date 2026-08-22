package md;

@:md.include("native.h")
extern class Native {
	@:native("native_fill") static function fill():Void;
	@:native("native_build") static function build():Void;
	@:native("native_array_pass") static function arrayPass(seed:Int16):Int;
	@:native("native_wide_pass") static function widePass(seed:Int):Int;
	@:native("native_object_pass") static function objectPass(seed:Int16):Int;
}

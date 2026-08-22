package md;

@:md.include("testio.h")
extern class Probe {
	@:native("hx_report") static function report(value:Int):Void;
	@:native("hx_done") static function done():Void;
	@:native("hx_seed") static function seed():Int;
}

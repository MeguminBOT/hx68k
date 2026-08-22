package md;

extern class VDP {
	@:native("VDP_setBackgroundColor") static function setBackgroundColor(value:Int):Void;
	@:native("VDP_drawText") static function drawText(str:String, x:Int, y:Int):Void;
	@:native("VDP_setTextPalette") static function setTextPalette(palette:Int):Void;
}

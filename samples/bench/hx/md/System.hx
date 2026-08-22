package md;

extern class System {
	@:native("SYS_doVBlankProcess") static function doVBlankProcess():Bool;
	@:native("SYS_disableInts") static function disableInts():Void;
	@:native("SYS_enableInts") static function enableInts():Void;
}

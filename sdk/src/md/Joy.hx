package md;

extern class Joy {
	static inline final UP = 0x0001;
	static inline final DOWN = 0x0002;
	static inline final LEFT = 0x0004;
	static inline final RIGHT = 0x0008;
	static inline final B = 0x0010;
	static inline final C = 0x0020;
	static inline final A = 0x0040;
	static inline final START = 0x0080;
	static inline final Z = 0x0100;
	static inline final Y = 0x0200;
	static inline final X = 0x0400;
	static inline final MODE = 0x0800;
	static inline final DIRECTIONS = 0x000F;
	static inline final BUTTONS = 0x0FF0;

	@:native("JOY_init") static function init():Void;
	@:native("JOY_reset") static function reset():Void;
	@:native("JOY_update") static function update():Void;

	@:native("JOY_readJoypad") static function read(port:UInt16):UInt16;
	@:native("JOY_readJoypadX") static function readX(port:UInt16):Int16;
	@:native("JOY_readJoypadY") static function readY(port:UInt16):Int16;

	@:native("JOY_getPortType") static function portType(port:UInt16):UInt8;
	@:native("JOY_getJoypadType") static function padType(port:UInt16):UInt8;
	@:native("JOY_setSupport") static function setSupport(port:UInt16, support:UInt16):Void;

	@:native("JOY_waitPress") static function waitPress(port:UInt16, buttons:UInt16):UInt16;
	@:native("JOY_waitPressBtn") static function waitAnyPress():Void;
}

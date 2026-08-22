package md;

extern class Maths {
	@:native("F16_sin") static function sin(angle:Fix16):Fix16;
	@:native("F16_cos") static function cos(angle:Fix16):Fix16;
	@:native("F16_sqrt") static function sqrt(value:Fix16):Fix16;
	@:native("F16_toInt") static function toInt(value:Fix16):Int;

	@:native("getApproximatedDistance") static function distance(dx:Int, dy:Int):UInt32;
	@:native("getLog2") static function log2(value:UInt32):UInt16;
	@:native("getNextPow2") static function nextPowerOfTwo(value:UInt32):UInt32;
}

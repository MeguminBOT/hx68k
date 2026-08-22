package hxmd.cpu.m68k;

interface Bus {
	function idle(cycles:Int):Void;
	function read(addr:Int, fc:Int, uds:Bool, lds:Bool):Int;
	function write(addr:Int, fc:Int, data:Int, uds:Bool, lds:Bool):Void;

	function faultAccess(read:Bool, addr:Int, fc:Int, data:Int):Int;
}

class FunctionCode {
	public static inline final USER_DATA = 1;
	public static inline final USER_PROGRAM = 2;
	public static inline final SUPER_DATA = 5;
	public static inline final SUPER_PROGRAM = 6;
	public static inline final CPU_SPACE = 7;
}

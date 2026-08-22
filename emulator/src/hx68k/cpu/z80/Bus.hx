package hx68k.cpu.z80;

interface Bus {
	function fetch(address:Int, refresh:Int):Int;
	function read(address:Int):Int;
	function write(address:Int, value:Int):Void;
	function input(port:Int):Int;
	function output(port:Int, value:Int):Void;
	function idle(states:Int):Void;
}

package hx68k.host.sdl;

@:include("events.h")
@:structAccess
@:native("HostEvent")
extern class Event {
	public var type:Int;
	public var windowID:Int;
	public var code:Int;
	public var value:Int;
	public var mods:Int;
	public var x:Single;
	public var y:Single;

	public function new();
}

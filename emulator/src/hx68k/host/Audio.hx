package hx68k.host;

@:include("audio.h")
extern class Audio {
	@:native("host_audio_start")
	static function start(rate:Int):Int;

	@:native("host_audio_stop")
	static function stop():Void;

	@:native("host_audio_push")
	static function push(interleaved:cpp.RawPointer<cpp.Int16>, frames:Int):Int;

	@:native("host_audio_queued")
	static function queued():Int;

	@:native("host_audio_starved")
	static function starved():Int;

	@:native("host_audio_clear")
	static function clear():Void;
}

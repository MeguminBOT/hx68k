package hx68k.host;

@:cppFileCode('
#ifdef HX_WINDOWS
extern "C" __declspec(dllimport) unsigned int __stdcall timeBeginPeriod(unsigned int uPeriod);
#pragma comment(lib, "winmm.lib")
#endif
')
class Clock {
	public static function fine():Void {
		#if windows
		untyped __cpp__('timeBeginPeriod(1)');
		#end
	}

	public static inline function stamp():Float {
		return haxe.Timer.stamp();
	}
}

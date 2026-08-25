package hx68k.host;

@:buildXml('
<files id="haxe">
	<compilerflag value="-I${SDL3PATH}/include" />
	<compilerflag value="-I${MINIAUDIOPATH}" />
	<compilerflag value="-I${NATIVEPATH}" />
</files>
<files id="__main__">
	<compilerflag value="-I${SDL3PATH}/include" />
	<compilerflag value="-I${MINIAUDIOPATH}" />
	<compilerflag value="-I${NATIVEPATH}" />
</files>
<files id="hx68k_native">
	<compilerflag value="-I${SDL3PATH}/include" />
	<compilerflag value="-I${MINIAUDIOPATH}" />
	<compilerflag value="-I${NATIVEPATH}" />
	<file name="${NATIVEPATH}/audio.cpp" />
	<file name="${NATIVEPATH}/events.cpp" />
	<file name="${NATIVEPATH}/render.cpp" />
</files>
<target id="haxe">
	<lib name="${SDL3PATH}/lib/SDL3.lib" />
	<files id="hx68k_native" />
</target>
')
class Native {
	public static function init():Void {}
}

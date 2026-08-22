package;

@:build(hxres.Resources.build("rom/res/tunes.res"))
@:md.include("tunes.h")
extern class Tunes {
	@:music("audio/tune.vgm") static var song;
}

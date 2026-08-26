package;

@:build(hxres.Resources.build("tunes"))
@:md.include("tunes.h")
extern class Tunes {
	@:music("audio/tune.vgm") static var song;
}

package md;

import md.res.Music;

extern class Sound {
	@:native("XGM_startPlay") static function play(tune:Music):Void;
	@:native("XGM_stopPlay") static function stop():Void;
	@:native("XGM_pausePlay") static function pause():Void;
	@:native("XGM_resumePlay") static function resume():Void;
	@:native("XGM_isPlaying") static function playing():Bool;
	@:native("XGM_setLoopNumber") static function setLoops(count:Int8):Void;
	@:native("XGM_setMusicTempo") static function setTempo(tempo:UInt16):Void;
	@:native("XGM_getMusicTempo") static function tempo():UInt16;
}

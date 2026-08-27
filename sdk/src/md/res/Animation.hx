package md.res;

import md.UInt8;
import md.Vector;

@:md.type("Animation*")
extern class Animation {
	@:native("numFrame") var count(default, null):UInt8;
	var loop(default, null):UInt8;
	var frames(default, null):Vector<md.res.AnimationFrame>;
}

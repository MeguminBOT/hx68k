package md.res;

import md.UInt16;
import md.Vector;

@:md.type("const Palette*")
extern class Palette {
	var length(default, null):UInt16;
	var data(default, null):Vector<UInt16>;
}

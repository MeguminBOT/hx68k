package hx68k.test;

import sys.FileSystem;

class Root {
	public static function of():String {
		var at = haxe.io.Path.removeTrailingSlashes(FileSystem.absolutePath(Sys.getCwd()));

		while (true) {
			if (FileSystem.exists(at + "/emulator") && FileSystem.exists(at + "/compiler")) return at;

			final up = haxe.io.Path.removeTrailingSlashes(haxe.io.Path.directory(at));
			if (up == "" || up == at) return "";
			at = up;
		}
	}

	public static function vendor(name:String):String {
		final root = of();
		return root == "" ? "../vendor/" + name : root + "/vendor/" + name;
	}
}

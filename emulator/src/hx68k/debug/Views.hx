package hx68k.debug;

class Views {
	public static function lines(view:View, limit:Int):Array<String> {
		final out = new Array<String>();
		for (row in view.rows(limit)) out.push(row.toString());
		return out;
	}

	public static function of(debugger:Debugger):Array<View> {
		return [
			new Registers(debugger),
			new Disassembly(debugger),
			new Stack(debugger),
			new Video(debugger),
			new Usage(debugger)
		];
	}
}

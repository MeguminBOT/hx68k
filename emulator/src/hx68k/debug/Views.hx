package hx68k.debug;

class Views {
	public static function of(debugger:Debugger):Array<View> {
		return [
			new Registers(debugger),
			new Disassembly(debugger),
			new Stack(debugger),
			new Video(debugger)
		];
	}
}

package hx68k.debug;

interface View {
	public function title():String;

	public function lines(rows:Int):Array<String>;
}

package hx68k.debug;

interface View {
	public function title():String;

	public function rows(limit:Int):Array<Row>;
}

package hx68k.debug;

class Stack implements View {
	final backtrace:Backtrace;

	public function new(debugger:Debugger) {
		this.backtrace = new Backtrace(debugger);
	}

	public function title():String {
		return "stack";
	}

	public function lines(rows:Int):Array<String> {
		final out = new Array<String>();
		for (frame in backtrace.walk(rows)) out.push(Backtrace.line(frame));
		return out;
	}
}

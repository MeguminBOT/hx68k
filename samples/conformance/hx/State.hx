package;

enum State {
	Idle;
	Running(ticks:Int);
	Done(code:Int);
}

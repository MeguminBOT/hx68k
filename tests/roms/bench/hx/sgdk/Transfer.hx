package sgdk;

enum abstract Transfer(Int) to Int {
	var Cpu = 0;
	var Direct = 1;
	var Queue = 2;
	var QueueCopy = 3;
}

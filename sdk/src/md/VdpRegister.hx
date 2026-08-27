package md;

enum abstract VdpRegister(Int) from Int to Int {
	var Mode = 0;
	var Display = 1;
	var PlaneA = 2;
	var Window = 3;
	var PlaneB = 4;
	var Sprites = 5;
	var Background = 7;
	var HorizontalInterrupt = 10;
	var Scrolling = 11;
	var Width = 12;
	var HorizontalScroll = 13;
	var AutoIncrement = 15;
	var PlaneSize = 16;
	var WindowX = 17;
	var WindowY = 18;
	var DmaLengthLow = 19;
	var DmaLengthHigh = 20;
	var DmaSourceLow = 21;
	var DmaSourceMiddle = 22;
	var DmaSourceHigh = 23;
}

package md;

enum abstract PortType(Int) from Int to Int {
	var Pad = 0x0D;
	var Nothing = 0x0F;
}

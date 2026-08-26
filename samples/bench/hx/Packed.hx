package;

@:build(hxres.Resources.build("packed"))
@:md.include("packed.h")
extern class Packed {
	@:binary("data/blob.dat", 2, 2, 0, true, "APLIB") static var aplib;
	@:binary("data/blob.dat", 2, 2, 0, true, "LZ4W") static var lz4w;
}

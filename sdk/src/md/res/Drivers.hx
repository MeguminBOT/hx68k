package md.res;

@:build(hxres.Resources.build("mddrivers"))
@:md.include("mddrivers.h")
extern class Drivers {
	@:binary("md/drivers/xgm.bin", 2, 2, 0, false) static var xgm;
	@:binary("md/drivers/xgm-stop.bin", 2, 2, 0, false) static var xgmStop;
	@:binary("md/drivers/silence.bin", 256, 256, 0, false) static var xgmSilence;
}

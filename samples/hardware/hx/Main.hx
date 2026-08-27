package;

import md.Probe;
import md.hw.Joypad;
import md.hw.Vdp;

class Main {
	static inline final BACKGROUND = 0x0E80;
	static inline final TILE = 0x0100;
	static inline final PATTERN = 0x1234;
	static inline final TRAIL = 0x0200;
	static inline final SHOWN = 0xF111;

	@:md.main
	static function main():Void {
		Vdp.register(7, 0);
		Vdp.colour(0, BACKGROUND);

		Vdp.writeAt(TILE, PATTERN);

		Vdp.address(Vdp.VRAM_WRITE, TRAIL);
		Vdp.write(SHOWN);
		Vdp.write(0);
		Vdp.write(0);
		Vdp.write(0);

		Joypad.open(0);

		Vdp.address(Vdp.CRAM_READ, 0);
		Probe.report(Vdp.read());

		Vdp.address(Vdp.VRAM_READ, TILE);
		Probe.report(Vdp.read());

		Probe.report(Joypad.read(0));
		Probe.done();

		while (true) {}
	}
}

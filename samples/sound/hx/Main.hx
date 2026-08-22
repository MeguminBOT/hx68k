package;

import md.Probe;
import md.Sound;
import md.System;
import md.Z80Bus;

class Main {
	@:md.main
	static function main():Void {
		Sound.play(Tunes.song);

		var frame = 0;
		while (frame < 8) {
			System.doVBlankProcess();
			frame++;
		}

		Probe.report(Z80Bus.driverReady() ? 1 : 0);
		Probe.report(Z80Bus.loadedDriver());
		Probe.report(Sound.playing() ? 1 : 0);
		Probe.done();

		while (true) {
			System.doVBlankProcess();
		}
	}
}

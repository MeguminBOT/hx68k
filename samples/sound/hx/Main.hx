package;

import md.Fm;
import md.Probe;
import md.Psg;
import md.sgdk.System;
import md.sgdk.Z80Bus;
import md.sgdk.Sound;

class Main {
	static inline final SETTLED = 0x5350;

	@:md.main
	static function main():Void {
		Psg.reset();
		Psg.setAttenuation(0, 2);
		Psg.setTone(0, 0x1A5);
		Psg.setAttenuation(1, 7);
		Psg.setFrequency(1, 440);
		Psg.setNoise(true, 2);
		Psg.setAttenuation(3, 5);

		Fm.reset();
		Fm.setAlgorithm(4, 3, 6);
		Fm.setPanning(4, true, false);
		Fm.setFrequency(4, 5, 0x2A9);
		Fm.setTotalLevel(4, 2, 0x1C);
		Fm.setMultiple(4, 2, 3, 9);
		Fm.keyOn(4, 0x0F);

		Probe.report(SETTLED);

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

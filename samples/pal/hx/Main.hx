package;

import md.Memory;
import md.Probe;
import md.hw.Vdp;

class Main {
	static inline final VERSION = 0xA10001;

	@:md.main
	static function main():Void {
		Probe.report(Vdp.status() & 0x0001);
		Probe.report((Memory.readU8(VERSION) >> 6) & 0x01);
		Probe.done();

		while (true) {}
	}
}

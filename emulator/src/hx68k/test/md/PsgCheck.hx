package hx68k.test.md;

import hx68k.md.Psg;

class PsgCheck {
	static inline final LATCH = 0x80;

	static inline final TONE0 = 0x00;

	static inline final VOLUME0 = 0x10;

	static inline final TONE2 = 0x40;

	static inline final NOISE = 0x60;

	static inline final VOLUME3 = 0x70;

	static inline final OFF = 0x0F;

	static inline final REPEATS = 57337;

	static var failures:Int = 0;
	static var checks:Int = 0;

	static function ok(what:String, held:Bool, saying:String):Void {
		checks++;
		if (held) return;
		failures++;
		Sys.println("  FAIL " + what + ": " + saying);
	}

	static function same(what:String, got:Int, wanted:Int):Void {
		ok(what, got == wanted, "wanted " + wanted + ", got " + got);
	}

	static function near(what:String, got:Int, wanted:Int, slack:Int):Void {
		final off = got - wanted;
		ok(what, (off < 0 ? -off : off) <= slack,
			"wanted " + wanted + " give or take " + slack + ", got " + got);
	}

	static function silent():Psg {
		final psg = new Psg();
		for (channel in 0...4) psg.write(LATCH | VOLUME0 | (channel << 5) | OFF);
		return psg;
	}

	static function sounding(register:Int, period:Int):Psg {
		final psg = silent();
		psg.write(LATCH | register | (period & 0x0F));
		psg.write((period >> 4) & 0x3F);
		psg.write(LATCH | VOLUME0 | (register << 1 & 0x60) | 0x00);
		return psg;
	}

	static function registers():Void {
		final psg = new Psg();

		psg.write(LATCH | TONE0 | 0x0A);
		same("a latch byte writes the low four bits of a period", psg.tone[0], 0x00A);

		psg.write(0x35);
		same("and a data byte writes the six above them", psg.tone[0], 0x35A);

		psg.write(LATCH | TONE2 | 0x07);
		psg.write(0x3F);
		same("each channel has its own period", psg.tone[2], 0x3F7);
		same("and the first one is untouched", psg.tone[0], 0x35A);

		psg.write(LATCH | VOLUME0 | 0x09);
		same("a latch byte writes an attenuation", psg.attenuation[0], 9);

		psg.write(0x3F);
		same("and a data byte writes only four bits of one", psg.attenuation[0], 0x0F);
	}

	static function volumes():Void {
		final psg = silent();

		psg.write(LATCH | VOLUME0 | OFF);
		same("attenuation fifteen is silence", psg.level(), 0);

		psg.write(LATCH | VOLUME0 | 0x00);
		final loudest = psg.level();
		ok("attenuation zero is the loudest there is", loudest > 0, "it was silent");

		var previous = loudest;
		for (step in 1...15) {
			psg.write(LATCH | VOLUME0 | step);
			final now = psg.level();
			near("attenuation " + step + " is two decibels under " + (step - 1),
				now, Math.round(previous * 0.794328), 1);
			previous = now;
		}
	}

	static function toggles(psg:Psg, steps:Int):Int {
		var previous = psg.level();
		var seen = 0;

		for (_ in 0...steps) {
			psg.run(Psg.DIVIDER);
			final now = psg.level();
			if (now != previous) seen++;
			previous = now;
		}

		return seen;
	}

	static function tones():Void {
		for (period in [1, 2, 16, 100, 1023]) {
			final psg = sounding(TONE0, period);
			near("a period of " + period + " toggles once every " + period + " counts",
				toggles(psg, period * 64), 64, 1);
		}

		final held = sounding(TONE0, 0);
		same("a period of zero never toggles", toggles(held, 4096), 0);
		ok("and holds the output high", held.level() > 0, "it was silent");
	}

	static function noise():Void {
		final psg = silent();

		psg.write(LATCH | NOISE | 0x04);
		psg.write(LATCH | VOLUME3 | 0x00);

		for (_ in 0...100) psg.run(Psg.DIVIDER * 0x10);
		ok("a hundred shifts move the register off where it started", psg.shift != 0x8000,
			"it is still 8000");

		psg.write(LATCH | NOISE | 0x04);
		same("writing the noise register resets the shift register", psg.shift, 0x8000);

		var zero = false;
		var steps = 0;

		while (steps <= REPEATS) {
			psg.run(Psg.DIVIDER * 0x10);
			steps++;
			if (psg.shift == 0) zero = true;
			if (psg.shift == 0x8000) break;
		}

		ok("white noise never shifts itself to zero", !zero, "it reached zero and would stay there");
		same("and comes back to where it started after as many shifts as the taps allow",
			steps, REPEATS);
	}

	static function periodic():Void {
		final psg = silent();

		psg.write(LATCH | NOISE | 0x00);
		psg.write(LATCH | VOLUME3 | 0x00);

		var high = 0;
		for (_ in 0...(16 * 64)) {
			psg.run(Psg.DIVIDER * 0x10);
			if ((psg.shift & 1) != 0) high++;
		}

		same("periodic noise is high one shift in sixteen", high, 64);
	}

	static function rates():Void {
		final psg = silent();
		psg.write(LATCH | VOLUME3 | 0x00);

		for (mode in 0...3) {
			psg.write(LATCH | NOISE | 0x04 | mode);
			final every = 0x10 << mode;
			var shifts = 0;
			var previous = psg.shift;

			for (_ in 0...(every * 64)) {
				psg.run(Psg.DIVIDER);
				if (psg.shift != previous) shifts++;
				previous = psg.shift;
			}

			near("noise mode " + mode + " shifts once every " + every + " counts", shifts, 64, 32);
		}

		psg.write(LATCH | TONE2 | 0x00);
		psg.write(0x04);
		psg.write(LATCH | NOISE | 0x07);

		var shifts = 0;
		var previous = psg.shift;
		for (_ in 0...(0x40 * 64)) {
			psg.run(Psg.DIVIDER);
			if (psg.shift != previous) shifts++;
			previous = psg.shift;
		}

		near("noise mode three shifts at the third channel's own period", shifts, 64, 32);
	}

	static function main():Void {
		run();
	}

	public static function run():Void {
		Sys.println("");
		Sys.println("what a write to the one port means");
		registers();

		Sys.println("what the four bits of attenuation are worth");
		volumes();

		Sys.println("what a period counts");
		tones();

		Sys.println("what the shift register does");
		noise();
		periodic();
		rates();

		Sys.println("");
		Sys.println(checks + " psg checks, " + failures + " failures");
		if (failures > 0) Sys.exit(1);
	}
}

package hx68k.test;

import sys.FileSystem;
import sys.io.File;

class OpnFixtures {
	static final ORDER = [0, 2, 1, 3];

	static final APART = [[0xA9, 0xAD], [0xAA, 0xAE], [0xA8, 0xAC]];

	static function main():Void {
		final args = Sys.args();
		final into = args.length > 0 ? args[0] : "tests/opn2/.build/scripts";

		if (!FileSystem.exists(into)) FileSystem.createDirectory(into);

		var made = 0;
		made += named(into);
		made += phase(into);
		made += envelopes(into);
		made += modulation(into);
		made += voices(into);
		made += ssg(into);
		made += channels(into);
		made += features(into);
		made += oscillator(into);
		made += separate(into);
		made += discrete(into);
		made += broad(into);

		Sys.println(made + " fixtures in " + into);
	}

	static function named(into:String):Int {
		var made = 0;

		for (algorithm in 0...8) {
			final voice = new OpnVoice().wiring(algorithm, 0).loud(0).note(4, 0x169);
			made += write(into, "main-algorithm-" + algorithm, [voice], [0]);
		}

		final feedbackLow = new OpnVoice().wiring(0, 3).loud(0).note(4, 0x169);
		made += write(into, "main-feedback-3", [feedbackLow], [0]);

		final feedbackHigh = new OpnVoice().wiring(4, 7).loud(0).note(4, 0x169);
		made += write(into, "main-feedback-7", [feedbackHigh], [0]);

		final multiples = new OpnVoice().wiring(2, 0).loud(0).note(4, 0x169);
		multiples.multiple[0] = 1;
		multiples.multiple[1] = 4;
		multiples.multiple[2] = 2;
		multiples.multiple[3] = 8;
		made += write(into, "main-multiple", [multiples], [0]);

		final detunes = new OpnVoice().wiring(4, 0).loud(0).note(4, 0x169);
		detunes.detune[0] = 1;
		detunes.detune[1] = 5;
		detunes.detune[2] = 2;
		detunes.detune[3] = 6;
		made += write(into, "main-detune", [detunes], [0]);

		made += write(into, "main-decay",
			[new OpnVoice().loud(0).envelope(25, 12, 0, 4, 7).note(4, 0x169)], [0]);
		made += write(into, "main-slow-attack",
			[new OpnVoice().loud(0).envelope(12, 6, 0, 2, 9).note(4, 0x169)], [0]);
		made += write(into, "main-low-note", [new OpnVoice().loud(0).note(1, 0x120)], [0]);
		made += write(into, "main-high-note", [new OpnVoice().loud(0).note(7, 0x500)], [0]);
		made += write(into, "main-quiet-carrier", [new OpnVoice().loud(40).note(4, 0x169)], [0]);
		made += write(into, "main-key-scaling",
			[new OpnVoice().loud(0).envelope(20, 14, 0, 3, 8, 3).note(6, 0x169)], [0]);

		final quiet = new OpnVoice().wiring(0, 0).note(4, 0x169);
		quiet.totalLevel[0] = 20;
		quiet.totalLevel[1] = 20;
		quiet.totalLevel[2] = 20;
		quiet.totalLevel[3] = 0;
		made += write(into, "main-modulated-quiet", [quiet], [0]);

		for (algorithm in [0, 1, 3]) {
			final voice = new OpnVoice().wiring(algorithm, 0).note(3, 0x180);
			voice.totalLevel[0] = 30;
			voice.totalLevel[1] = algorithm == 1 ? 30 : (algorithm == 0 ? 26 : 20);
			voice.totalLevel[2] = algorithm == 0 ? 22 : 20;
			voice.totalLevel[3] = 8;
			made += write(into, "main-gentle-" + algorithm, [voice], [0]);
		}

		return made;
	}

	static function phase(into:String):Int {
		var made = 0;

		for (detune in 0...8) {
			for (block in 0...8) {
				final voice = new OpnVoice().alone(0, 8).note(block, 0x100 + block * 0x90);
				voice.detune[0] = detune;
				made += write(into, "phase-detune-" + detune + "-block-" + block, [voice], [0]);
			}
		}

		for (multiple in 0...16) {
			final voice = new OpnVoice().alone(0, 8).note(4, 0x220);
			voice.multiple[0] = multiple;
			made += write(into, "phase-multiple-" + pad(multiple), [voice], [0]);
		}

		for (feedback in 0...8) {
			final voice = new OpnVoice().alone(0, 4).wiring(7, feedback);
			made += write(into, "phase-feedback-" + feedback, [voice], [0]);
		}

		for (block in 0...8) {
			for (frequency in [0x001, 0x040, 0x0FF, 0x100, 0x37F, 0x380, 0x400, 0x7FF]) {
				final voice = new OpnVoice().alone(0, 8).note(block, frequency);
				made += write(into, "phase-note-" + block + "-" + hex(frequency), [voice], [0]);
			}
		}

		return made;
	}

	static function envelopes(into:String):Int {
		final chance = new Chance(0x5E11);
		var made = 0;

		for (i in 0...200) {
			final voice = new OpnVoice().alone(0, 8);
			voice.attack[0] = chance.upTo(32);
			voice.decay[0] = chance.upTo(32);
			voice.sustain[0] = chance.upTo(32);
			voice.level[0] = chance.upTo(16);
			voice.release[0] = chance.upTo(16);
			voice.keyScale[0] = chance.upTo(4);
			voice.block = chance.upTo(8);
			voice.frequency = chance.between(0x40, 0x7FF);
			if (chance.odds(60)) voice.lift = chance.between(150, 1500);
			made += write(into, "envelope-" + pad(i), [voice], [0]);
		}

		return made;
	}

	static function modulation(into:String):Int {
		final chance = new Chance(0x30D);
		final levels = [0, 4, 8, 16, 24, 32, 48, 64];
		var made = 0;

		for (i in 0...120) {
			final voice = new OpnVoice().wiring(chance.upTo(8), chance.upTo(8));
			for (at in 0...4) {
				voice.totalLevel[at] = chance.pick(levels);
				voice.multiple[at] = chance.upTo(16);
				voice.detune[at] = chance.upTo(8);
			}
			voice.block = chance.upTo(8);
			voice.frequency = chance.between(0x40, 0x7FF);
			made += write(into, "modulation-" + pad(i), [voice], [0]);
		}

		return made;
	}

	static function voices(into:String):Int {
		final chance = new Chance(0x4051CE);
		final levels = [0, 4, 8, 16, 24, 32, 48, 64, 96];
		var made = 0;

		for (i in 0...120) {
			final voice = new OpnVoice().wiring(chance.upTo(8), chance.upTo(8));
			for (at in 0...4) {
				voice.detune[at] = chance.upTo(8);
				voice.multiple[at] = chance.upTo(16);
				voice.totalLevel[at] = chance.pick(levels);
				voice.keyScale[at] = chance.upTo(4);
				voice.attack[at] = chance.upTo(32);
				voice.decay[at] = chance.upTo(32);
				voice.sustain[at] = chance.upTo(32);
				voice.level[at] = chance.upTo(16);
				voice.release[at] = chance.upTo(16);
			}
			voice.block = chance.upTo(8);
			voice.frequency = chance.between(0x40, 0x7FF);
			made += write(into, "voice-" + pad(i), [voice], [0]);
		}

		return made;
	}

	static function ssg(into:String):Int {
		var made = 0;

		for (shape in 0...8) {
			for (rate in [12, 20, 28]) {
				final voice = new OpnVoice().alone(0, 8).envelope(28, rate, 4, 6, 9).note(4, 0x169);
				voice.ssg[0] = 0x08 | shape;
				made += write(into, "ssg-" + shape + "-rate-" + pad(rate), [voice], [0]);
			}
		}

		for (shape in 0...8) {
			final voice = new OpnVoice().alone(0, 8).envelope(28, 18, 6, 5, 7).note(4, 0x169);
			voice.ssg[0] = 0x08 | shape;
			voice.lift = 800;
			made += write(into, "ssg-" + shape + "-lifted", [voice], [0]);
		}

		return made;
	}

	static function channels(into:String):Int {
		var made = 0;

		for (which in 0...6) {
			final voice = new OpnVoice().wiring(4, 3).envelope(26, 9, 4, 3, 7).note(4, 0x169);
			voice.totalLevel[0] = 8;
			voice.totalLevel[1] = 12;
			voice.totalLevel[2] = 20;
			voice.totalLevel[3] = 0;
			for (at in 0...4) voice.detune[at] = 2;
			voice.lift = 900;
			made += write(into, "channel-" + which, [voice], [which]);
		}

		return made;
	}

	static function features(into:String):Int {
		var made = 0;

		for (rate in [1, 3, 7, 12, 20, 31]) {
			final voice = new OpnVoice().alone(0, 8).envelope(31, 20, rate, 4, 15);
			made += write(into, "feature-sustain-" + pad(rate), [voice], [0]);
		}

		for (rate in [1, 3, 7, 11, 15]) {
			final voice = new OpnVoice().alone(0, 8).envelope(31, 0, 0, 0, rate);
			voice.lift = 600;
			made += write(into, "feature-release-" + pad(rate), [voice], [0]);
		}

		for (scaling in 0...4) {
			final voice = new OpnVoice().alone(0, 8).envelope(18, 14, 6, 5, 15, scaling).note(5, 0x180);
			made += write(into, "feature-scaling-" + scaling, [voice], [0]);
		}

		for (level in [0, 1, 3, 8, 14, 15]) {
			final voice = new OpnVoice().alone(0, 8).envelope(31, 16, 4, level, 15);
			made += write(into, "feature-level-" + pad(level), [voice], [0]);
		}

		final held = new OpnVoice().alone(0, 8).envelope(20, 10, 3, 4, 9);
		held.lift = 500;
		made += write(into, "feature-lifted", [held], [0]);

		return made;
	}

	static function oscillator(into:String):Int {
		var made = 0;

		for (rate in 0...8) {
			final voice = new OpnVoice().alone(0, 16).note(4, 0x169);
			voice.ams = 3;
			voice.tremolo[0] = true;
			made += write(into, "lfo-tremolo-rate-" + rate, [voice], [0], rate);
		}

		for (depth in 0...4) {
			final voice = new OpnVoice().alone(0, 24).envelope(24, 12, 6, 4, 9).note(4, 0x169);
			voice.ams = depth;
			voice.tremolo[0] = true;
			made += write(into, "lfo-tremolo-depth-" + depth, [voice], [0], 5);
		}

		final held = new OpnVoice().alone(0, 24).note(4, 0x169);
		held.ams = 3;
		held.tremolo[0] = true;
		made += write(into, "lfo-tremolo-stopped", [held], [0]);

		for (depth in 0...8) {
			for (note in [0x040, 0x0F5, 0x169, 0x2A0, 0x3F8, 0x5A5, 0x7F0]) {
				final voice = new OpnVoice().alone(0, 8).note(4, note);
				voice.pms = depth;
				made += write(into, "lfo-vibrato-" + depth + "-" + hex(note), [voice], [0], 6);
			}
		}

		for (block in 0...8) {
			final voice = new OpnVoice().alone(0, 8).note(block, 0x4B7);
			voice.pms = 7;
			made += write(into, "lfo-vibrato-block-" + block, [voice], [0], 7);
		}

		final over = new OpnVoice().alone(0, 8).note(5, 0x7FE);
		over.pms = 7;
		made += write(into, "lfo-vibrato-over", [over], [0], 7);

		for (rate in [0, 3, 7]) {
			final voice = new OpnVoice().wiring(2, 4).envelope(26, 10, 5, 3, 8).note(4, 0x2C0);
			for (at in 0...4) {
				voice.totalLevel[at] = at == 3 ? 4 : 22;
				voice.detune[at] = at;
				voice.tremolo[at] = at != 1;
			}
			voice.ams = 2;
			voice.pms = 5;
			made += write(into, "lfo-together-" + rate, [voice], [0], rate);
		}

		return made;
	}

	static function separate(into:String):Int {
		var made = 0;

		for (which in 0...3) {
			final voice = new OpnVoice().wiring(7, 0).loud(16).note(2, 0x100);
			voice.apart[which] = 0x2A0;
			voice.apartBlock[which] = 5;
			made += write(into, "special-one-" + which, [voice], [2], -1, 1);
		}

		for (mode in 0...4) {
			final voice = new OpnVoice().wiring(7, 0).loud(16).note(2, 0x100);
			for (at in 0...3) {
				voice.apart[at] = 0x120 + at * 0x1C0;
				voice.apartBlock[at] = 1 + at * 2;
			}
			made += write(into, "special-mode-" + mode, [voice], [2], -1, mode);
		}

		for (detune in 1...4) {
			final voice = new OpnVoice().wiring(7, 0).loud(16).note(2, 0x100);
			for (at in 0...4) voice.detune[at] = detune;
			for (at in 0...3) {
				voice.apart[at] = 0x040 + at * 0x3B0;
				voice.apartBlock[at] = at * 3;
			}
			made += write(into, "special-detune-" + detune, [voice], [2], -1, 1);
		}

		for (scaling in 0...4) {
			final voice = new OpnVoice().wiring(7, 0).loud(8)
				.envelope(22, 13, 5, 4, 8, scaling).note(1, 0x0C0);
			for (at in 0...3) {
				voice.apart[at] = 0x1A0 + at * 0x2E0;
				voice.apartBlock[at] = 2 + at * 2;
			}
			voice.lift = 900;
			made += write(into, "special-scaling-" + scaling, [voice], [2], -1, 1);
		}

		for (depth in [3, 5, 7]) {
			final voice = new OpnVoice().wiring(4, 2).loud(12).note(4, 0x200);
			voice.pms = depth;
			for (at in 0...3) {
				voice.apart[at] = 0x070 + at * 0x390;
				voice.apartBlock[at] = 1 + at * 3;
			}
			made += write(into, "special-vibrato-" + depth, [voice], [2], 6, 1);
		}

		for (which in [0, 1, 4]) {
			final voice = new OpnVoice().wiring(7, 0).loud(16).note(2, 0x100);
			for (at in 0...3) {
				voice.apart[at] = 0x120 + at * 0x1C0;
				voice.apartBlock[at] = 1 + at * 2;
			}
			made += write(into, "special-elsewhere-" + which, [voice], [which], -1, 1);
		}

		for (period in [40, 120, 400]) {
			final voice = new OpnVoice().wiring(7, 0).loud(12)
				.envelope(26, 14, 0, 3, 11).note(4, 0x169);
			voice.keys = 0;
			for (at in 0...3) {
				voice.apart[at] = 0x100 + at * 0x240;
				voice.apartBlock[at] = 2 + at * 2;
			}
			made += write(into, "special-csm-" + pad(period), [voice], [2], -1, 2, period);
		}

		final both = new OpnVoice().wiring(4, 3).loud(10).envelope(22, 12, 4, 4, 9).note(4, 0x169);
		made += write(into, "special-csm-keyed", [both], [2], -1, 2, 200);

		final started = new OpnVoice().wiring(7, 0).loud(8).envelope(31, 0, 0, 0, 2).note(4, 0x169);
		started.keys = 0;
		made += write(into, "special-csm-started", [started], [2], -1, 2, 900);

		final idle = new OpnVoice().wiring(7, 0).loud(12).envelope(26, 14, 0, 3, 11).note(4, 0x169);
		idle.keys = 0;
		made += write(into, "special-csm-off", [idle], [2], -1, 1, 200);

		final chance = new Chance(0xC33);
		for (i in 0...40) {
			final voice = new OpnVoice().wiring(chance.upTo(8), chance.upTo(8));
			for (at in 0...4) {
				voice.detune[at] = chance.upTo(8);
				voice.multiple[at] = chance.upTo(16);
				voice.totalLevel[at] = chance.pick([0, 8, 16, 24, 40, 64]);
				voice.keyScale[at] = chance.upTo(4);
				voice.attack[at] = chance.upTo(32);
				voice.decay[at] = chance.upTo(32);
				voice.sustain[at] = chance.upTo(32);
				voice.level[at] = chance.upTo(16);
				voice.release[at] = chance.upTo(16);
			}
			voice.block = chance.upTo(8);
			voice.frequency = chance.between(0x40, 0x7FF);
			for (at in 0...3) {
				voice.apart[at] = chance.between(0x40, 0x7FF);
				voice.apartBlock[at] = chance.upTo(8);
			}
			if (chance.odds(50)) voice.lift = chance.between(200, 1200);
			made += write(into, "special-" + pad(i), [voice], [2], -1, 1 + chance.upTo(3));
		}

		return made;
	}

	static function discrete(into:String):Int {
		var made = 0;

		for (level in [0, 24, 48, 72, 96, 110, 120]) {
			final voice = new OpnVoice().wiring(7, 0).loud(level).note(4, 0x169);
			made += write(into, "discrete-quiet-" + pad(level), [voice], [0]);
		}

		for (sides in [0xC0, 0x80, 0x40, 0x00]) {
			final voice = new OpnVoice().wiring(4, 3).loud(20).note(4, 0x169);
			voice.panning = sides;
			made += write(into, "discrete-panning-" + hex(sides), [voice], [0]);
		}

		for (algorithm in 0...8) {
			final voice = new OpnVoice().wiring(algorithm, 2).envelope(24, 11, 5, 4, 8).note(4, 0x169);
			for (at in 0...4) voice.totalLevel[at] = at == 3 ? 16 : 28;
			voice.lift = 1100;
			made += write(into, "discrete-algorithm-" + algorithm, [voice], [0]);
		}

		final fading = new OpnVoice().alone(0, 12).envelope(31, 6, 2, 8, 4).note(3, 0x1C0);
		fading.lift = 400;
		made += write(into, "discrete-fading", [fading], [0]);

		final chance = new Chance(0x1ADDE2);
		for (i in 0...40) {
			final voices = [];
			final where = [];

			for (which in 0...6) {
				if (chance.odds(40)) continue;

				final voice = new OpnVoice().wiring(chance.upTo(8), chance.upTo(8));
				for (at in 0...4) {
					voice.detune[at] = chance.upTo(8);
					voice.multiple[at] = chance.upTo(16);
					voice.totalLevel[at] = chance.pick([8, 16, 32, 48, 64, 96, 110]);
					voice.attack[at] = chance.upTo(32);
					voice.decay[at] = chance.upTo(32);
					voice.sustain[at] = chance.upTo(32);
					voice.level[at] = chance.upTo(16);
					voice.release[at] = chance.upTo(16);
				}
				voice.panning = chance.pick([0xC0, 0xC0, 0x80, 0x40, 0x00]);
				voice.block = chance.upTo(8);
				voice.frequency = chance.between(0x40, 0x7FF);
				if (chance.odds(50)) voice.lift = chance.between(200, 1200);

				voices.push(voice);
				where.push(which);
			}

			if (voices.length == 0) {
				voices.push(new OpnVoice().loud(48));
				where.push(0);
			}

			made += write(into, "discrete-" + pad(i), voices, where);
		}

		return made + sampled(into);
	}

	static function sampled(into:String):Int {
		final lines:Array<String> = [];
		final chance = new Chance(0xDAC);

		byte(lines, 0, 0xB4 + 2, 0xC0);
		byte(lines, 1, 0xB4 + 2, 0xC0);
		byte(lines, 0, 0x2B, 0x80);

		for (i in 0...600) {
			final value = i < 300 ? Std.int(0x60 + (i * 64) / 300) : chance.between(0x70, 0x90);
			lines.push((i == 0 ? 40 : 4) + " 0 " + 0x2A);
			lines.push("2 1 " + (value & 0xFF));
		}

		return script(into, "discrete-sampled", lines);
	}

	static function broad(into:String):Int {
		final chance = new Chance(0xB40AD);
		final levels = [0, 0, 4, 8, 16, 24, 32, 48, 64, 96, 127];
		final sides = [0xC0, 0xC0, 0x80, 0x40, 0x00];
		var made = 0;

		for (i in 0...150) {
			final voices = [];
			final where = [];

			for (which in 0...6) {
				if (chance.odds(45)) continue;

				final voice = new OpnVoice().wiring(chance.upTo(8), chance.upTo(8));
				for (at in 0...4) {
					voice.detune[at] = chance.upTo(8);
					voice.multiple[at] = chance.upTo(16);
					voice.totalLevel[at] = chance.pick(levels);
					voice.keyScale[at] = chance.upTo(4);
					voice.attack[at] = chance.upTo(32);
					voice.decay[at] = chance.upTo(32);
					voice.sustain[at] = chance.upTo(32);
					voice.level[at] = chance.upTo(16);
					voice.release[at] = chance.upTo(16);
				}
				voice.panning = chance.pick(sides);
				voice.block = chance.upTo(8);
				voice.frequency = chance.between(0x40, 0x7FF);
				if (chance.odds(50)) voice.lift = chance.between(200, 1200);

				voices.push(voice);
				where.push(which);
			}

			if (voices.length == 0) {
				voices.push(new OpnVoice().loud(8));
				where.push(0);
			}

			made += write(into, "random-" + pad(i), voices, where);
		}

		return made;
	}

	static function write(into:String, name:String, voices:Array<OpnVoice>, where:Array<Int>,
			lfo:Int = -1, mode:Int = 0, timer:Int = -1):Int {
		final lines:Array<String> = [];

		if (lfo >= 0) byte(lines, 0, 0x22, 0x08 | (lfo & 7));

		if (timer >= 0) {
			final count = 1024 - timer;
			byte(lines, 0, 0x24, (count >> 2) & 0xFF);
			byte(lines, 0, 0x25, count & 3);
		}

		if (mode != 0 || timer >= 0) {
			byte(lines, 0, 0x27, ((mode & 3) << 6) | (timer >= 0 ? 0x05 : 0));
		}
		for (i in 0...voices.length) registers(lines, voices[i], where[i]);
		for (i in 0...voices.length) key(lines, voices[i], where[i], voices[i].keys, 2);

		for (i in 0...voices.length) {
			if (voices[i].lift >= 0) key(lines, voices[i], where[i], 0, voices[i].lift);
		}

		return script(into, name, lines);
	}

	static function script(into:String, name:String, lines:Array<String>):Int {
		File.saveContent(into + "/" + name + ".txt", lines.join("\n") + "\n");
		return 1;
	}

	static function registers(lines:Array<String>, voice:OpnVoice, where:Int):Void {
		final part = where >= 3 ? 1 : 0;
		final channel = where % 3;
		final port = part * 2;

		for (group in 0...4) {
			final at = ORDER[group];
			final slot = group * 4 + channel;
			byte(lines, port, 0x30 + slot, ((voice.detune[at] & 7) << 4) | (voice.multiple[at] & 0x0F));
			byte(lines, port, 0x40 + slot, voice.totalLevel[at] & 0x7F);
			byte(lines, port, 0x50 + slot, ((voice.keyScale[at] & 3) << 6) | (voice.attack[at] & 0x1F));
			byte(lines, port, 0x60 + slot, (voice.tremolo[at] ? 0x80 : 0) | (voice.decay[at] & 0x1F));
			byte(lines, port, 0x70 + slot, voice.sustain[at] & 0x1F);
			byte(lines, port, 0x80 + slot, ((voice.level[at] & 0x0F) << 4) | (voice.release[at] & 0x0F));
			byte(lines, port, 0x90 + slot, voice.ssg[at] & 0x0F);
		}

		byte(lines, port, 0xB0 + channel, ((voice.feedback & 7) << 3) | (voice.algorithm & 7));
		byte(lines, port, 0xB4 + channel,
			voice.panning | ((voice.ams & 3) << 4) | (voice.pms & 7));
		byte(lines, port, 0xA4 + channel, ((voice.block & 7) << 3) | ((voice.frequency >> 8) & 7));
		byte(lines, port, 0xA0 + channel, voice.frequency & 0xFF);

		for (at in 0...3) {
			if (voice.apart[at] < 0) continue;
			byte(lines, 0, APART[at][1],
				((voice.apartBlock[at] & 7) << 3) | ((voice.apart[at] >> 8) & 7));
			byte(lines, 0, APART[at][0], voice.apart[at] & 0xFF);
		}
	}

	static function key(lines:Array<String>, voice:OpnVoice, where:Int, keys:Int, after:Int):Void {
		final select = (where % 3) + (where >= 3 ? 4 : 0);
		lines.push(after + " 0 " + 0x28);
		lines.push("2 1 " + (((keys & 0x0F) << 4) | select));
	}

	static function byte(lines:Array<String>, port:Int, register:Int, value:Int):Void {
		lines.push("2 " + port + " " + register);
		lines.push("2 " + (port + 1) + " " + (value & 0xFF));
	}

	static function pad(value:Int):String {
		return StringTools.lpad(Std.string(value), "0", 3);
	}

	static function hex(value:Int):String {
		return StringTools.lpad(StringTools.hex(value), "0", 3);
	}
}

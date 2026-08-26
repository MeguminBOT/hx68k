package hx68k.test;

import hx68k.md.Machine;
import hx68k.md.Memory;
import hx68k.md.Vdp;

private class Counting implements Memory {
	public function new() {}

	public function readWord(address:Int):Int {
		return 0x1000 | ((address >> 1) & 0x0FFF);
	}
}

class SlotCheck {
	static inline final H40 = 0x81;

	static inline final H32 = 0x01;

	static inline final DISPLAY_ON = 0x44;

	static inline final DISPLAY_OFF = 0x04;

	static inline final TALL = 0x08;

	static inline final VINT_ON = 0x20;

	static inline final VRAM_WRITE = 0x40000000;

	static inline final A_WRITE = 4 * 7;

	static inline final BUS_CYCLE = 4 * 7;

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

	static function set(vdp:Vdp, index:Int, value:Int):Void {
		vdp.writeControl(0x8000 | ((index & 0x1F) << 8) | (value & 0xFF));
	}

	static function ready(width:Int, display:Int):Vdp {
		final vdp = new Vdp(new Counting());

		set(vdp, 1, display);
		set(vdp, 12, width);
		set(vdp, 15, 2);

		vdp.writeControl((VRAM_WRITE >> 16) & 0xFFFF);
		vdp.writeControl(VRAM_WRITE & 0xFFFF);
		return vdp;
	}

	static function census(width:Int, display:Int):Int {
		final vdp = ready(width, display);
		final total = width == H40 ? Vdp.SLOTS_H40 : Vdp.SLOTS_H32;

		var open = 0;
		for (at in 1...total + 1) if (vdp.slotIsExternal(at)) open++;
		return open;
	}

	static function counting():Void {
		same("external slots on an active H40 line", census(H40, DISPLAY_ON), 18);
		same("external slots on an active H32 line", census(H32, DISPLAY_ON), 16);
		same("external slots on a blanked H40 line", census(H40, DISPLAY_OFF), 205);
		same("external slots on a blanked H32 line", census(H32, DISPLAY_OFF), 167);
	}

	static function holding():Void {
		final vdp = ready(H40, DISPLAY_ON);

		var held = 0;
		for (word in 0...Vdp.FIFO_DEPTH) {
			held += vdp.writeData(0x1000 + word);
			vdp.tick(A_WRITE);
		}

		same("four words fit without the bus being held", held, 0);
		same("and the queue holds all four", vdp.queued, Vdp.FIFO_DEPTH);
		ok("the status says the queue is full", (vdp.readStatus() & 0x0100) != 0, "it did not");
		ok("and not that it is empty", (vdp.readStatus() & 0x0200) == 0, "it said empty");

		final fifth = vdp.writeData(0x2000);
		ok("the fifth word holds the bus", fifth > 0, "it was let through");
		ok("for less than a line", fifth < Vdp.MASTER_PER_LINE,
			"it held for " + fifth + " of " + Vdp.MASTER_PER_LINE);

		final gap = Std.int(Vdp.MASTER_PER_LINE / 18);
		ok("for about the gap between two external slots on an active line",
			fifth <= gap * 3, "it held " + fifth + " where the average gap is " + gap);
	}

	static function blanking():Void {
		final vdp = ready(H40, DISPLAY_OFF);

		var held = 0;
		for (word in 0...64) {
			held += vdp.writeData(0x3000 + word);
			vdp.tick(A_WRITE);
		}

		same("a blanked line takes sixty-four words without holding the bus", held, 0);
	}

	static function landing():Void {
		final vdp = ready(H40, DISPLAY_ON);

		for (word in 0...Vdp.FIFO_DEPTH) vdp.writeData(0x4000 + word);
		same("nothing has landed yet", vdp.vram.get(1), 0);
		ok("and the queue holds it", vdp.queued == Vdp.FIFO_DEPTH, "queued " + vdp.queued);

		for (_ in 0...Vdp.MASTER_PER_LINE) vdp.tick(1);

		same("a line is long enough to drain all four", vdp.queued, 0);
		same("and the first word landed", (vdp.vram.get(0) << 8) | vdp.vram.get(1), 0x4000);
		same("and so did the fourth", (vdp.vram.get(6) << 8) | vdp.vram.get(7), 0x4003);
	}

	static function asked(vdp:Vdp, length:Int, source:Int, mode:Int):Void {
		set(vdp, 19, length & 0xFF);
		set(vdp, 20, (length >> 8) & 0xFF);
		set(vdp, 21, source & 0xFF);
		set(vdp, 22, (source >> 8) & 0xFF);
		set(vdp, 23, mode);
	}

	static function carried(vdp:Vdp, length:Int):Int {
		for (_ in 0...Vdp.MASTER_PER_LINE) {
			vdp.tick(1);
			if (!vdp.running() && vdp.queued == 0) break;
		}

		return length - (vdp.registers[19] | (vdp.registers[20] << 8)) - vdp.queued;
	}

	static function transferring(width:Int, display:Int, words:Int):Int {
		final vdp = ready(width, display);
		asked(vdp, words, 0, 0);

		vdp.writeControl(0x4000);
		vdp.writeControl(0x0080);
		return carried(vdp, words);
	}

	static function filling(width:Int, display:Int, bytes:Int):Int {
		final vdp = ready(width, display);
		asked(vdp, bytes, 0, 0x80);

		vdp.writeControl(0x4000);
		vdp.writeControl(0x0080);
		vdp.writeData(0xAA55);
		return carried(vdp, bytes);
	}

	static function copying(width:Int, display:Int, bytes:Int):Int {
		final vdp = ready(width, display);
		asked(vdp, bytes, 0x4000, 0xC0);

		vdp.writeControl(0x4000);
		vdp.writeControl(0x00C0);
		return carried(vdp, bytes);
	}

	static function dma():Void {
		same("a blanked H40 line carries 205 words of a transfer",
			transferring(H40, DISPLAY_OFF, 1000), 205);
		same("an active H40 line carries 18", transferring(H40, DISPLAY_ON, 1000), 18);
		same("a blanked H32 line carries 167", transferring(H32, DISPLAY_OFF, 1000), 167);
		same("an active H32 line carries 16", transferring(H32, DISPLAY_ON, 1000), 16);

		same("a transfer shorter than a line carries all of it",
			transferring(H40, DISPLAY_OFF, 40), 40);
	}

	static function fill():Void {
		same("a blanked H40 line carries 204 bytes of a fill, the first slot going to its word",
			filling(H40, DISPLAY_OFF, 1000), 204);
		same("an active H40 line carries 17", filling(H40, DISPLAY_ON, 1000), 17);
		same("a blanked H32 line carries 166", filling(H32, DISPLAY_OFF, 1000), 166);
		same("an active H32 line carries 15", filling(H32, DISPLAY_ON, 1000), 15);
	}

	static function over(vdp:Vdp, length:Int, lines:Int):Int {
		var master = Vdp.MASTER_PER_LINE * lines;

		while (master > 0) {
			final now = master < BUS_CYCLE ? master : BUS_CYCLE;
			vdp.tick(now);
			master -= now;
		}

		return length - (vdp.registers[19] | (vdp.registers[20] << 8)) - vdp.queued;
	}

	static function sustained():Void {
		final filled = ready(H40, DISPLAY_OFF);
		asked(filled, 4000, 0, 0x80);
		filled.writeControl(0x4000);
		filled.writeControl(0x0080);
		filled.writeData(0xAA55);
		same("ten blanked H40 lines fill 204 bytes and then 205 nine times over",
			over(filled, 4000, 10), 204 + 205 * 9);

		final moved = ready(H40, DISPLAY_OFF);
		asked(moved, 4000, 0, 0);
		moved.writeControl(0x4000);
		moved.writeControl(0x0080);
		same("and transfer 205 words on every one of them", over(moved, 4000, 10), 2050);

		final copied = ready(H40, DISPLAY_OFF);
		asked(copied, 4000, 0x4000, 0xC0);
		copied.writeControl(0x4000);
		copied.writeControl(0x00C0);
		same("and copy a byte every second slot, ten lines being 1025 of them",
			over(copied, 4000, 10), 1025);
	}

	static function copy():Void {
		same("a blanked H40 line carries 102 bytes of a copy, which reads before it writes",
			copying(H40, DISPLAY_OFF, 1000), 102);
		same("an active H40 line carries 9", copying(H40, DISPLAY_ON, 1000), 9);
		same("a blanked H32 line carries 83", copying(H32, DISPLAY_OFF, 1000), 83);
		same("an active H32 line carries 8", copying(H32, DISPLAY_ON, 1000), 8);
	}

	static function landed():Void {
		final vdp = ready(H40, DISPLAY_OFF);
		asked(vdp, 8, 0, 0x80);

		vdp.writeControl(0x4000);
		vdp.writeControl(0x0080);
		vdp.writeData(0xAA55);

		ok("a fill leaves the DMA running", vdp.running(), "it did not");
		ok("and says so in the status", (vdp.readStatus() & 0x0002) != 0, "the busy bit was clear");
		ok("but does not freeze the 68000", !vdp.transferring(), "it froze");

		for (_ in 0...Vdp.MASTER_PER_LINE) vdp.tick(1);

		ok("a line finishes eight bytes of it", !vdp.running(), "it is still running");
		ok("and the status says so", (vdp.readStatus() & 0x0002) == 0, "the busy bit was set");

		same("the word it started with landed", (vdp.vram.get(0) << 8) | vdp.vram.get(1), 0xAA55);
		same("and the high byte followed it", vdp.vram.get(3), 0xAA);
		same("at the address increment, not beside it", vdp.vram.get(2), 0);
	}

	static function copied():Void {
		final vdp = ready(H40, DISPLAY_OFF);
		for (at in 0...8) vdp.vram.set(0x4000 + at, 0x10 + at);

		set(vdp, 15, 1);
		asked(vdp, 8, 0x4000, 0xC0);

		vdp.writeControl(0x4000);
		vdp.writeControl(0x00C0);

		ok("a copy leaves the DMA running", vdp.running(), "it did not");
		ok("but does not freeze the 68000", !vdp.transferring(), "it froze");

		for (_ in 0...Vdp.MASTER_PER_LINE) vdp.tick(1);

		ok("a line finishes eight bytes of it", !vdp.running(), "it is still running");

		var wrong = 0;
		for (at in 0...8) if (vdp.vram.get(at) != 0x10 + at) wrong++;
		same("and every byte arrived where it was sent", wrong, 0);
	}

	static function through():Void {
		final vdp = ready(H40, DISPLAY_ON);
		asked(vdp, 1000, 0, 0);

		vdp.writeControl(0x4000);
		vdp.writeControl(0x0080);

		for (_ in 0...Vdp.MASTER_PER_LINE) vdp.tick(1);
		same("a transfer keeps the queue full while it runs", vdp.queued, Vdp.FIFO_DEPTH);
		ok("and is still running", vdp.running(), "it stopped");
	}

	static function exposure():Void {
		final vdp = ready(H40, DISPLAY_OFF);

		vdp.writeControl(0xC000);
		vdp.writeControl(0x0000);
		vdp.writeData(0x0EEE);

		for (word in 0...Vdp.FIFO_DEPTH) {
			vdp.writeControl(0x4000);
			vdp.writeControl(0x0000);
			vdp.writeData(word == 0 ? 0xF111 : 0x0000);
			for (_ in 0...64) vdp.tick(1);
		}

		vdp.writeControl(0x0000);
		vdp.writeControl(0x0020);
		same("a colour read shows the slot the next write will use", vdp.readData(), 0x0EEE | 0xF111);
	}

	static function counter(width:Int, last:Int, resume:Int):Void {
		final vdp = ready(width, DISPLAY_ON);
		final name = width == H40 ? "H40" : "H32";

		final seen:Array<Int> = [];
		var previous = -1;

		for (_ in 0...Vdp.MASTER_PER_LINE) {
			final now = vdp.horizontal();
			if (now != previous) seen.push(now);
			previous = now;
			vdp.tick(1);
		}

		same("the " + name + " horizontal counter starts at zero", seen[0], 0);
		same("and ends at 255", seen[seen.length - 1], 0xFF);
		same("over as many counts as the line has", seen.length, vdp.countsPerLine());

		var jumps = 0;
		var from = -1;
		var to = -1;
		for (i in 1...seen.length) {
			if (seen[i] == seen[i - 1] + 1) continue;
			jumps++;
			from = seen[i - 1];
			to = seen[i];
		}

		same("counting up with one jump in it", jumps, 1);
		same("from " + last, from, last);
		same("to " + resume, to, resume);
	}

	static function blanksAt(display:Int):Int {
		final vdp = ready(H40, display);

		for (_ in 0...Vdp.LINES_NTSC) {
			for (_ in 0...Vdp.MASTER_PER_LINE) vdp.tick(1);
			if ((vdp.readStatus() & 0x0008) != 0) return vdp.line;
		}

		return -1;
	}

	static function interruptsAt(display:Int):Int {
		final vdp = ready(H40, display);

		for (_ in 0...Vdp.LINES_NTSC) {
			for (_ in 0...Vdp.MASTER_PER_LINE) vdp.tick(1);
			if (vdp.irqLevel() == Vdp.VINT_LEVEL) return vdp.line;
		}

		return -1;
	}

	static function hundredths(hz:Int, lines:Int):Int {
		return Math.round(hz * 100.0 / (Vdp.MASTER_PER_LINE * lines));
	}

	static function standards():Void {
		final ntsc = ready(H40, DISPLAY_ON);
		same("a machine is NTSC until told otherwise", ntsc.lines, Vdp.LINES_NTSC);
		ok("and says so in the status", (ntsc.readStatus() & 0x0001) == 0, "the PAL bit was set");

		final pal = ready(H40, DISPLAY_ON);
		pal.standard(true);
		same("a PAL machine runs 313 lines", pal.lines, Vdp.LINES_PAL);
		ok("and says so in the status", (pal.readStatus() & 0x0001) != 0, "the PAL bit was clear");

		same("NTSC is 59.92 frames a second, in hundredths",
			hundredths(Vdp.MASTER_HZ, Vdp.LINES_NTSC), 5992);
		same("and PAL is 49.70", hundredths(Vdp.MASTER_HZ_PAL, Vdp.LINES_PAL), 4970);

		same("a PAL frame is 87 lines of vertical blanking in V28, as the documentation tallies it",
			Vdp.LINES_PAL - Vdp.LINES_V28 - 2, 87);
		same("and 71 in V30", Vdp.LINES_PAL - Vdp.LINES_V30 - 2, 71);
		same("where NTSC V28 is 36", Vdp.LINES_NTSC - Vdp.LINES_V28 - 2, 36);
	}

	static function headed(field:String):Bool {
		final rom = haxe.io.Bytes.alloc(Machine.REGION_AT + Machine.REGION_LENGTH);
		for (i in 0...Machine.REGION_LENGTH) {
			rom.set(Machine.REGION_AT + i, i < field.length ? field.charCodeAt(i) : " ".code);
		}
		return Machine.palByHeader(rom);
	}

	static function headers():Void {
		ok("a cartridge naming Europe alone is PAL", headed("E"), "it came back NTSC");
		ok("and one naming Europe and nowhere else, padded", headed("E             "),
			"it came back NTSC");
		ok("a cartridge naming Japan, the Americas and Europe is not", !headed("JUE"),
			"it came back PAL");
		ok("nor is one naming the Americas alone", !headed("U"), "it came back PAL");
		ok("nor Japan alone", !headed("J"), "it came back PAL");
		ok("a header of spaces is not", !headed("    "), "it came back PAL");
		ok("a ROM too short to hold a header is not",
			!Machine.palByHeader(haxe.io.Bytes.alloc(16)), "it came back PAL");
	}

	static function heights():Void {
		same("V28 leaves the active display after 224 lines",
			blanksAt(DISPLAY_ON), Vdp.LINES_V28);
		same("and V30 after 240", blanksAt(DISPLAY_ON | TALL), Vdp.LINES_V30);

		same("the vertical interrupt comes at the end of V28's 224",
			interruptsAt(DISPLAY_ON | VINT_ON), Vdp.LINES_V28);
		same("and at the end of V30's 240",
			interruptsAt(DISPLAY_ON | TALL | VINT_ON), Vdp.LINES_V30);
	}

	static function vertical():Void {
		final vdp = ready(H40, DISPLAY_ON);

		final seen:Array<Int> = [];
		var previous = -1;

		for (_ in 0...Vdp.MASTER_PER_LINE * Vdp.LINES_NTSC) {
			final now = (vdp.readCounter() >> 8) & 0xFF;
			if (now != previous) seen.push(now);
			previous = now;
			vdp.tick(1);
		}

		same("the vertical counter starts at zero", seen[0], 0);
		same("and ends at 255", seen[seen.length - 1], 0xFF);
		same("over as many counts as an NTSC frame has lines", seen.length, Vdp.LINES_NTSC);

		var jumps = 0;
		var from = -1;
		var to = -1;
		for (i in 1...seen.length) {
			if (seen[i] == seen[i - 1] + 1) continue;
			jumps++;
			from = seen[i - 1];
			to = seen[i];
		}

		same("counting up with one jump in it", jumps, 1);
		same("from " + Vdp.V_LAST, from, Vdp.V_LAST);
		same("to " + Vdp.V_RESUME, to, Vdp.V_RESUME);
	}

	static function counters():Void {
		counter(H40, Vdp.H_LAST_H40, Vdp.H_RESUME_H40);
		counter(H32, Vdp.H_LAST_H32, Vdp.H_RESUME_H32);
		vertical();
	}

	static function main():Void {
		run();
	}

	public static function run():Void {
		Sys.println("");
		Sys.println("where the external access slots are");
		counting();

		Sys.println("which television standard the machine is on");
		standards();

		Sys.println("what a cartridge header says the standard is");
		headers();

		Sys.println("where the active display ends, in each height");
		heights();

		Sys.println("what the counters read across a line and a frame");
		counters();

		Sys.println("what a transfer does with them");
		dma();
		through();

		Sys.println("what a VRAM fill does with them");
		fill();
		landed();

		Sys.println("what a VRAM copy does with them");
		copy();
		copied();

		Sys.println("what a dma keeps up over a run of lines");
		sustained();

		Sys.println("what the write FIFO does with them");
		exposure();
		holding();
		blanking();
		landing();

		Sys.println("");
		Sys.println(checks + " slot checks, " + failures + " failures");
		if (failures > 0) Sys.exit(1);
	}
}

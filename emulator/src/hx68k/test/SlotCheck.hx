package hx68k.test;

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

	static inline final VRAM_WRITE = 0x40000000;

	static inline final A_WRITE = 4 * 7;

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
		final blank = transferring(H40, DISPLAY_OFF, 1000);
		ok("a blanked H40 line carries about 205 words of a transfer",
			blank >= 200 && blank <= 210, "it carried " + blank);

		final active = transferring(H40, DISPLAY_ON, 1000);
		ok("an active H40 line carries about 18",
			active >= 15 && active <= 20, "it carried " + active);

		final narrow = transferring(H32, DISPLAY_OFF, 1000);
		ok("a blanked H32 line carries about 167",
			narrow >= 162 && narrow <= 172, "it carried " + narrow);

		final short = transferring(H40, DISPLAY_OFF, 40);
		same("a transfer shorter than a line carries all of it", short, 40);
	}

	static function fill():Void {
		final blank = filling(H40, DISPLAY_OFF, 1000);
		ok("a blanked H40 line carries about 204 bytes of a fill, the first slot going to its word",
			blank >= 199 && blank <= 209, "it carried " + blank);

		final active = filling(H40, DISPLAY_ON, 1000);
		ok("an active H40 line carries about 17",
			active >= 14 && active <= 20, "it carried " + active);

		final narrow = filling(H32, DISPLAY_OFF, 1000);
		ok("a blanked H32 line carries about 166",
			narrow >= 161 && narrow <= 171, "it carried " + narrow);
	}

	static function copy():Void {
		final blank = copying(H40, DISPLAY_OFF, 1000);
		ok("a blanked H40 line carries about 102 bytes of a copy, which reads before it writes",
			blank >= 97 && blank <= 107, "it carried " + blank);

		final active = copying(H40, DISPLAY_ON, 1000);
		ok("an active H40 line carries about 9",
			active >= 6 && active <= 12, "it carried " + active);

		final narrow = copying(H32, DISPLAY_OFF, 1000);
		ok("a blanked H32 line carries about 83",
			narrow >= 78 && narrow <= 88, "it carried " + narrow);
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

	static function counters():Void {
		counter(H40, Vdp.H_LAST_H40, Vdp.H_RESUME_H40);
		counter(H32, Vdp.H_LAST_H32, Vdp.H_RESUME_H32);
	}

	static function main():Void {
		run();
	}

	public static function run():Void {
		Sys.println("");
		Sys.println("where the external access slots are");
		counting();

		Sys.println("what the horizontal counter reads across a line");
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

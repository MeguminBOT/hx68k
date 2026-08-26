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

	static function transferring(width:Int, display:Int, words:Int):Int {
		final vdp = ready(width, display);

		set(vdp, 19, words & 0xFF);
		set(vdp, 20, (words >> 8) & 0xFF);
		set(vdp, 21, 0);
		set(vdp, 22, 0);
		set(vdp, 23, 0);

		vdp.writeControl(0x4000);
		vdp.writeControl(0x0080);

		var carried = 0;
		for (_ in 0...Vdp.MASTER_PER_LINE) {
			vdp.tick(1);
			if (!vdp.transferring()) break;
			carried++;
		}

		var landed = 0;
		for (at in 0...0x8000) if (vdp.vram.get(at * 2) != 0 || vdp.vram.get(at * 2 + 1) != 0) landed++;
		return landed;
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

	static function main():Void {
		run();
	}

	public static function run():Void {
		Sys.println("");
		Sys.println("where the external access slots are");
		counting();

		Sys.println("what a transfer does with them");
		dma();

		Sys.println("what the write FIFO does with them");
		holding();
		blanking();
		landing();

		Sys.println("");
		Sys.println(checks + " slot checks, " + failures + " failures");
		if (failures > 0) Sys.exit(1);
	}
}

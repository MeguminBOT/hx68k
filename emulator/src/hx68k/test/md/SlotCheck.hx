package hx68k.test.md;

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

	static inline final LATCH = 0x02;

	static inline final EXTERNAL_ON = 0x08;

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
			held += vdp.holdFor();
			vdp.writeData(0x1000 + word);
			vdp.tick(A_WRITE);
		}

		same("four words fit without the bus being held", held, 0);
		same("and the queue holds all four", vdp.queued, Vdp.FIFO_DEPTH);
		ok("the status says the queue is full", (vdp.readStatus() & 0x0100) != 0, "it did not");
		ok("and not that it is empty", (vdp.readStatus() & 0x0200) == 0, "it said empty");

		final fifth = vdp.holdFor();
		vdp.tick(fifth);
		vdp.writeData(0x2000);
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
			held += vdp.holdFor();
			vdp.writeData(0x3000 + word);
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
		same("a color read shows the slot the next write will use", vdp.readData(), 0x0EEE | 0xF111);
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

	static function widestGap(wide:Bool, upTo:Int, round:Bool):Int {
		final total = wide ? Vdp.SLOTS_H40 : Vdp.SLOTS_H32;
		var widest = 0;
		var previous = -1;
		var first = -1;

		for (at in 1...upTo + 1) {
			if (!Vdp.externalSlot(at, wide, false)) continue;
			if (first < 0) first = at;
			if (previous > 0 && at - previous > widest) widest = at - previous;
			previous = at;
		}

		if (round && first > 0 && first + total - previous > widest) widest = first + total - previous;
		return widest;
	}

	static function clocks(slots:Int, total:Int):Int {
		return Std.int(slots * Vdp.MASTER_PER_LINE / total);
	}

	static function microseconds(slots:Int, total:Int):Int {
		return Math.round(slots * (Vdp.MASTER_PER_LINE / total) * 100.0 / (Vdp.MASTER_HZ / 1000000.0));
	}

	static function longestHold(wide:Bool):Int {
		final vdp = ready(wide ? H40 : H32, DISPLAY_ON);
		var worst = 0;

		for (_ in 0...3000) {
			final held = vdp.holdFor();
			if (held > worst) worst = held;
			vdp.tick(held);
			vdp.writeData(0x1234);
			vdp.tick(BUS_CYCLE);
		}

		return worst;
	}

	static function waiting():Void {
		same("an active H32 line has sixteen external slots in it", externalCount(false), 16);
		same("and an active H40 line eighteen", externalCount(true), 18);

		final narrow = widestGap(false, Vdp.SLOTS_H32, true);
		same("the widest gap between two of them is sixteen slots in H32", narrow, 16);
		same("which is the 5.96 microseconds the documentation gives, in hundredths",
			microseconds(narrow, Vdp.SLOTS_H32), 596);

		final body = widestGap(true, 173, false);
		same("the widest gap in the body of an H40 line is sixteen slots too", body, 16);
		same("which is the 4.77 the documentation gives, to within its own rounding",
			microseconds(body, Vdp.SLOTS_H40), 485);

		final whole = widestGap(true, Vdp.SLOTS_H40, true);
		same("H40's tail and line end leave a wider one than the documentation covers", whole, 26);
		same("which is 7.89 microseconds, and VDP-NOTES carries the disagreement",
			microseconds(whole, Vdp.SLOTS_H40), 789);

		same("the longest the bus is held in H32, plus the four cycles the write itself takes, "
			+ "is exactly that gap", longestHold(false) + BUS_CYCLE, clocks(narrow, Vdp.SLOTS_H32));
		same("and the same in H40", longestHold(true) + BUS_CYCLE, clocks(whole, Vdp.SLOTS_H40));
	}

	static function externalCount(wide:Bool):Int {
		final total = wide ? Vdp.SLOTS_H40 : Vdp.SLOTS_H32;
		var open = 0;
		for (at in 1...total + 1) if (Vdp.externalSlot(at, wide, false)) open++;
		return open;
	}

	static function reading(vdp:Vdp, at:Int):Void {
		vdp.writeControl(at & 0x3FFF);
		vdp.writeControl((at >> 14) & 0x03);
	}

	static function writingTo(vdp:Vdp, at:Int):Void {
		vdp.writeControl(0x4000 | (at & 0x3FFF));
		vdp.writeControl((at >> 14) & 0x03);
	}

	static function prefetching():Void {
		final vdp = ready(H40, DISPLAY_OFF);

		writingTo(vdp, 0x1000);
		vdp.writeData(0xAAAA);
		vdp.writeData(0xBBBB);
		for (_ in 0...Vdp.MASTER_PER_LINE) vdp.tick(1);

		reading(vdp, 0x1000);
		same("a read comes back with the word at the address it was set to",
			vdp.readData(), 0xAAAA);
		same("and the next with the one after it", vdp.readData(), 0xBBBB);

		reading(vdp, 0x1000);
		writingTo(vdp, 0x1000);
		vdp.writeData(0xCCCC);
		for (_ in 0...Vdp.MASTER_PER_LINE) vdp.tick(1);
		reading(vdp, 0x1000);
		same("a word written after the read was set up is seen by a read set up again",
			vdp.readData(), 0xCCCC);

		final queued = ready(H40, DISPLAY_OFF);
		writingTo(queued, 0x3000);
		queued.writeData(0x4444);
		ok("a word can still be sitting in the FIFO", queued.queued > 0, "the queue was empty");

		reading(queued, 0x3000);
		same("and setting a read drains it first, so the read sees it",
			queued.readData(), 0x4444);
		same("which leaves the queue empty", queued.queued, 0);
	}

	static function latching():Void {
		final free = ready(H40, DISPLAY_ON);
		final first = free.readCounter();
		for (_ in 0...400) free.tick(1);
		ok("with M3 clear the counter runs on", free.readCounter() != first, "it did not move");

		free.trigger();
		final after = free.readCounter();
		for (_ in 0...400) free.tick(1);
		ok("and a trigger freezes nothing", free.readCounter() != after, "it froze anyway");

		final stopped = ready(H40, DISPLAY_ON);
		set(stopped, 0, LATCH);
		stopped.trigger();
		final frozen = stopped.readCounter();
		for (_ in 0...800) stopped.tick(1);
		same("with M3 set a trigger freezes the counter", stopped.readCounter(), frozen);
		ok("and the VDP says it is holding one", stopped.latched, "it says it is not");

		set(stopped, 0, 0x00);
		ok("clearing M3 lets go of it", !stopped.latched, "it is still holding one");
		ok("and the counter runs again", stopped.readCounter() != frozen, "it stayed frozen");
	}

	static function wiring():Void {
		final machine = new Machine();
		machine.vdp.rendering = false;
		machine.vdp.writeControl(0x8000 | LATCH);

		machine.writeByte(0xA10009, 0x40);
		machine.writeByte(0xA10003, 0x00);
		ok("a port holding TH low latches nothing", !machine.vdp.latched, "it latched");

		machine.writeByte(0xA10003, 0x40);
		ok("and TH rising on it is the trigger", machine.vdp.latched, "it did not latch");

		machine.vdp.acknowledge(Vdp.EXTERNAL_LEVEL);
		machine.writeByte(0xA10003, 0x40);
		ok("writing the same high level again is not a second trigger, since HL is an edge",
			!machine.vdp.external, "it triggered on the level");

		final input = new Machine();
		input.vdp.rendering = false;
		input.vdp.writeControl(0x8000 | LATCH);
		input.writeByte(0xA10009, 0x00);
		ok("a port with TH left an input, which is how a light gun is wired, sees no edge",
			!input.vdp.latched, "it latched with nothing driving it");
	}

	static function externally():Void {
		final port = ready(H40, DISPLAY_ON);
		port.trigger();
		same("a trigger raises nothing while IE2 is clear", port.irqLevel(), 0);

		set(port, 11, EXTERNAL_ON);
		same("and level 2 the moment IE2 is set", port.irqLevel(), Vdp.EXTERNAL_LEVEL);

		port.acknowledge(Vdp.EXTERNAL_LEVEL);
		same("acknowledging it clears it", port.irqLevel(), 0);

		final both = ready(H40, DISPLAY_ON | VINT_ON);
		set(both, 11, EXTERNAL_ON);
		for (_ in 0...Vdp.MASTER_PER_LINE * (Vdp.LINES_V28 + 1)) both.tick(1);
		both.trigger();
		same("the vertical interrupt outranks the external one", both.irqLevel(), Vdp.VINT_LEVEL);

		both.acknowledge(Vdp.VINT_LEVEL);
		same("which is still waiting behind it", both.irqLevel(), Vdp.EXTERNAL_LEVEL);
	}

	static function sameText(what:String, got:String, wanted:String):Void {
		ok(what, got == wanted, "wanted " + wanted + ", got " + got);
	}

	static function fieldBit(mode:Int):String {
		final vdp = ready(H40, DISPLAY_ON);
		set(vdp, 12, H40 | mode);

		var out = "";

		for (_ in 0...4) {
			out += (vdp.readStatus() & 0x0010) != 0 ? "1" : "0";
			final was = vdp.frame;
			while (vdp.frame == was) vdp.tick(8);
		}

		return out;
	}

	static function shaped(mode:Int):Vdp {
		final vdp = ready(H40, DISPLAY_ON);
		set(vdp, 12, H40 | mode);
		return vdp;
	}

	static function interlacing():Void {
		sameText("a progressive frame never reports an odd field", fieldBit(0x00), "0000");
		sameText("interlace mode 1 reports every other one", fieldBit(0x02), "0101");
		sameText("and so does mode 2", fieldBit(0x06), "0101");

		ok("mode 1 doubles nothing", !shaped(0x02).doubled(), "it doubled");
		ok("and mode 2 doubles every vertical measurement", shaped(0x06).doubled(), "it did not");
		ok("a progressive frame doubles nothing either", !shaped(0x00).doubled(), "it doubled");
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

	static function walked(vdp:Vdp):Array<Int> {
		final seen:Array<Int> = [];
		var previous = -1;

		for (_ in 0...Vdp.MASTER_PER_LINE * vdp.lines) {
			final now = (vdp.readCounter() >> 8) & 0xFF;
			if (now != previous) seen.push(now);
			previous = now;
			vdp.tick(1);
		}

		return seen;
	}

	static function tallCounters():Void {
		final palTall = ready(H40, DISPLAY_ON | TALL);
		palTall.standard(true);
		final wide = walked(palTall);

		same("a PAL V30 frame counts as many times as a PAL frame has lines",
			wide.length, Vdp.LINES_PAL);
		same("the last before its jump is 0Ah", wide[266], Vdp.V_LAST_PAL_V30 & 0xFF);
		same("and it comes back at D2h", wide[267], Vdp.V_RESUME_PAL_V30 & 0xFF);
		same("ending at 255", wide[wide.length - 1], 0xFF);

		final ntscTall = ready(H40, DISPLAY_ON | TALL);
		final narrow = walked(ntscTall);

		same("an NTSC V30 frame counts as many times as an NTSC frame has lines",
			narrow.length, Vdp.LINES_NTSC);
		same("but its counter never jumps back, so it ends where the frame does",
			narrow[narrow.length - 1], (Vdp.LINES_NTSC - 1) & 0xFF);
	}

	static function blankingFlag():Void {
		final vdp = ready(H40, DISPLAY_ON);
		var set = -1;
		var last = -1;

		for (line in 0...Vdp.LINES_NTSC) {
			for (_ in 0...Vdp.MASTER_PER_LINE) vdp.tick(1);
			if ((vdp.readStatus() & 0x0008) == 0) continue;
			if (set < 0) set = vdp.line;
			last = vdp.line;
		}

		same("the blanking flag sets where the active display ends", set, Vdp.LINES_V28);
		same("and clears again on the last line of the frame, not at the wrap",
			last, Vdp.LINES_NTSC - 2);
	}

	static function verticalPal():Void {
		final vdp = ready(H40, DISPLAY_ON);
		vdp.standard(true);

		final seen = walked(vdp);

		same("a PAL frame counts as many times as it has lines", seen.length, Vdp.LINES_PAL);
		same("starting at zero", seen[0], 0);
		same("and ending at 255", seen[seen.length - 1], 0xFF);

		same("its counter runs past 255 and round again, so the last before the long jump is 2",
			seen[258], Vdp.V_LAST_PAL & 0xFF);
		same("and it comes back at CAh", seen[259], Vdp.V_RESUME_PAL & 0xFF);
	}

	static function interlacedCounter():Void {
		final vdp = ready(H40, DISPLAY_ON);
		set(vdp, 12, H40 | 0x06);

		final seen = walked(vdp);

		var odd = 0;
		var even = 0;
		for (value in seen) if ((value & 1) != 0) odd++ else even++;

		same("interlace leaves the counter with as many readings as before", seen.length,
			Vdp.LINES_NTSC);
		same("the lower half of the count reads back doubled, and so even", even, 128);
		same("and the upper half odd, since the ninth bit it lost lands in bit 0",
			odd, Vdp.LINES_NTSC - 128);
		same("the first reading is still zero", seen[0], 0);
		same("and the last still 255", seen[seen.length - 1], 0xFF);
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
		same("to " + (vdp.vResume & 0xFF), to, vdp.vResume & 0xFF);
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

		waiting();

		Sys.println("what a read of the data port comes back with");
		prefetching();

		Sys.println("what stops the HV counter and what the trigger raises");
		latching();
		wiring();
		externally();

		Sys.println("which of the three interlace settings is running");
		interlacing();

		Sys.println("what a cartridge header says the standard is");
		headers();

		Sys.println("where the active display ends, in each height");
		heights();

		Sys.println("what the counters read across a line and a frame");
		verticalPal();
		tallCounters();
		blankingFlag();
		interlacedCounter();
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

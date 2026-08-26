package hx68k.md;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.ds.Vector;

class Savestate {
	static inline final MAGIC = 0x48583638;
	static inline final VERSION = 6;

	public static function of(machine:Machine):Bytes {
		final out = new BytesOutput();
		out.bigEndian = true;

		out.writeInt32(MAGIC);
		out.writeInt32(VERSION);

		writeCpu(out, machine.cpu);
		writeZ80(out, machine.z80);
		writeVdp(out, machine.vdp);
		writeSound(out, machine.sound);
		writeMachine(out, machine);

		out.write(machine.ram);
		out.write(machine.z80Ram);

		return out.getBytes();
	}

	public static function into(machine:Machine, bytes:Bytes):Void {
		final input = new BytesInput(bytes);
		input.bigEndian = true;

		if (input.readInt32() != MAGIC) throw "not a savestate";
		final version = input.readInt32();
		if (version != VERSION) throw "savestate version " + version + ", expected " + VERSION;

		readCpu(input, machine.cpu);
		readZ80(input, machine.z80);
		readVdp(input, machine.vdp);
		readSound(input, machine.sound);
		readMachine(input, machine);

		input.readBytes(machine.ram, 0, machine.ram.length);
		input.readBytes(machine.z80Ram, 0, machine.z80Ram.length);
	}

	static function writeCpu(out:BytesOutput, cpu:hx68k.cpu.m68k.M68000):Void {
		for (i in 0...8) out.writeInt32(cpu.d[i]);
		for (i in 0...8) out.writeInt32(cpu.a[i]);

		out.writeInt32(cpu.inactiveSp);
		out.writeInt32(cpu.pc);
		out.writeInt32(cpu.ird);
		out.writeInt32(cpu.irc);
		out.writeInt32(cpu.pcAtStart);
		out.writeInt32(cpu.opcode);
		out.writeInt32(cpu.faultIr);
		out.writeInt32(cpu.faultPc);
		out.writeInt32(cpu.imask);
		out.writeByte(flags(cpu));
	}

	static function readCpu(input:BytesInput, cpu:hx68k.cpu.m68k.M68000):Void {
		for (i in 0...8) cpu.d[i] = input.readInt32();
		for (i in 0...8) cpu.a[i] = input.readInt32();

		cpu.inactiveSp = input.readInt32();
		cpu.pc = input.readInt32();
		cpu.ird = input.readInt32();
		cpu.irc = input.readInt32();
		cpu.pcAtStart = input.readInt32();
		cpu.opcode = input.readInt32();
		cpu.faultIr = input.readInt32();
		cpu.faultPc = input.readInt32();
		cpu.imask = input.readInt32();

		final bits = input.readByte();
		cpu.xf = (bits & 0x01) != 0;
		cpu.nf = (bits & 0x02) != 0;
		cpu.zf = (bits & 0x04) != 0;
		cpu.vf = (bits & 0x08) != 0;
		cpu.cf = (bits & 0x10) != 0;
		cpu.t = (bits & 0x20) != 0;
		cpu.s = (bits & 0x40) != 0;
		cpu.faulted = (bits & 0x80) != 0;
	}

	static function flags(cpu:hx68k.cpu.m68k.M68000):Int {
		return (cpu.xf ? 0x01 : 0) | (cpu.nf ? 0x02 : 0) | (cpu.zf ? 0x04 : 0) | (cpu.vf ? 0x08 : 0)
			| (cpu.cf ? 0x10 : 0) | (cpu.t ? 0x20 : 0) | (cpu.s ? 0x40 : 0) | (cpu.faulted ? 0x80 : 0);
	}

	static function writeZ80(out:BytesOutput, z80:hx68k.cpu.z80.Z80):Void {
		for (value in [z80.a, z80.f, z80.b, z80.c, z80.d, z80.e, z80.h, z80.l]) out.writeInt32(value);
		for (value in [z80.af2, z80.bc2, z80.de2, z80.hl2]) out.writeInt32(value);
		for (value in [z80.ix, z80.iy, z80.sp, z80.pc, z80.wz]) out.writeInt32(value);
		for (value in [z80.i, z80.r, z80.im, z80.q, z80.p, z80.previousQ]) out.writeInt32(value);

		out.writeByte((z80.iff1 ? 1 : 0) | (z80.iff2 ? 2 : 0) | (z80.ei ? 4 : 0) | (z80.halted ? 8 : 0));
	}

	static function readZ80(input:BytesInput, z80:hx68k.cpu.z80.Z80):Void {
		z80.a = input.readInt32();
		z80.f = input.readInt32();
		z80.b = input.readInt32();
		z80.c = input.readInt32();
		z80.d = input.readInt32();
		z80.e = input.readInt32();
		z80.h = input.readInt32();
		z80.l = input.readInt32();

		z80.af2 = input.readInt32();
		z80.bc2 = input.readInt32();
		z80.de2 = input.readInt32();
		z80.hl2 = input.readInt32();

		z80.ix = input.readInt32();
		z80.iy = input.readInt32();
		z80.sp = input.readInt32();
		z80.pc = input.readInt32();
		z80.wz = input.readInt32();

		z80.i = input.readInt32();
		z80.r = input.readInt32();
		z80.im = input.readInt32();
		z80.q = input.readInt32();
		z80.p = input.readInt32();
		z80.previousQ = input.readInt32();

		final bits = input.readByte();
		z80.iff1 = (bits & 1) != 0;
		z80.iff2 = (bits & 2) != 0;
		z80.ei = (bits & 4) != 0;
		z80.halted = (bits & 8) != 0;
	}

	static function writeVdp(out:BytesOutput, vdp:Vdp):Void {
		writeVector(out, vdp.registers);
		writeVector(out, vdp.cram);
		writeVector(out, vdp.vsram);
		out.write(vdp.vram);

		out.writeInt32(vdp.line);
		out.writeInt32(vdp.frame);
		out.writeInt32(vdp.dot);
		out.writeInt32(vdp.address);
		out.writeInt32(vdp.code);
		out.writeInt32(vdp.hintCounter);
		out.writeByte((vdp.pending ? 1 : 0) | (vdp.filling ? 2 : 0) | (vdp.vint ? 4 : 0) | (vdp.hint ? 8 : 0)
			| (vdp.dmaFetched ? 16 : 0));

		out.writeInt32(vdp.served);
		out.writeInt32(vdp.fifoHead);
		out.writeInt32(vdp.queued);
		for (i in 0...Vdp.FIFO_DEPTH) {
			out.writeInt32(vdp.fifoCode[i]);
			out.writeInt32(vdp.fifoAddress[i]);
			out.writeInt32(vdp.fifoValue[i]);
		}

		out.writeInt32(vdp.dmaMode);
		out.writeInt32(vdp.dmaLeft);
		out.writeInt32(vdp.dmaWord);
		out.writeInt32(vdp.dmaBank);
		out.writeInt32(vdp.dmaByte);
	}

	static function readVdp(input:BytesInput, vdp:Vdp):Void {
		readVector(input, vdp.registers);
		vdp.decode();
		readVector(input, vdp.cram);
		readVector(input, vdp.vsram);
		input.readBytes(vdp.vram, 0, vdp.vram.length);

		vdp.line = input.readInt32();
		vdp.frame = input.readInt32();
		vdp.dot = input.readInt32();
		vdp.next = vdp.dot < Vdp.ACTIVE_TICKS ? Vdp.ACTIVE_TICKS : Vdp.MASTER_PER_LINE;
		vdp.address = input.readInt32();
		vdp.code = input.readInt32();
		vdp.hintCounter = input.readInt32();

		final bits = input.readByte();
		vdp.pending = (bits & 1) != 0;
		vdp.filling = (bits & 2) != 0;
		vdp.vint = (bits & 4) != 0;
		vdp.hint = (bits & 8) != 0;
		vdp.dmaFetched = (bits & 16) != 0;

		vdp.served = input.readInt32();
		vdp.fifoHead = input.readInt32();
		vdp.queued = input.readInt32();
		for (i in 0...Vdp.FIFO_DEPTH) {
			vdp.fifoCode[i] = input.readInt32();
			vdp.fifoAddress[i] = input.readInt32();
			vdp.fifoValue[i] = input.readInt32();
		}

		vdp.dmaMode = input.readInt32();
		vdp.dmaLeft = input.readInt32();
		vdp.dmaWord = input.readInt32();
		vdp.dmaBank = input.readInt32();
		vdp.dmaByte = input.readInt32();
	}

	static function writeSound(out:BytesOutput, sound:Sound):Void {
		writePsg(out, sound.psg);
		writeYm(out, sound.ym);

		out.writeInt32(sound.psgClocks);
		out.writeInt32(sound.ymClocks);
		out.writeDouble(sound.samples);
		out.writeInt32(sound.fmLeft);
		out.writeInt32(sound.fmRight);
		out.writeInt32(sound.olderLeft);
		out.writeInt32(sound.olderRight);
		out.writeInt32(sound.wentLeft);
		out.writeInt32(sound.wentRight);
		out.writeDouble(sound.heldLeft);
		out.writeDouble(sound.heldRight);
		out.writeDouble(sound.bend);
	}

	static function readSound(input:BytesInput, sound:Sound):Void {
		readPsg(input, sound.psg);
		readYm(input, sound.ym);

		sound.psgClocks = input.readInt32();
		sound.ymClocks = input.readInt32();
		sound.samples = input.readDouble();
		sound.fmLeft = input.readInt32();
		sound.fmRight = input.readInt32();
		sound.olderLeft = input.readInt32();
		sound.olderRight = input.readInt32();
		sound.wentLeft = input.readInt32();
		sound.wentRight = input.readInt32();
		sound.heldLeft = input.readDouble();
		sound.heldRight = input.readDouble();

		sound.steerBy(input.readDouble());

		sound.head = 0;
		sound.tail = 0;
		sound.held = 0;
	}

	static function writePsg(out:BytesOutput, psg:Psg):Void {
		writeVector(out, psg.tone);
		writeVector(out, psg.attenuation);
		writeVector(out, psg.counter);
		writeVector(out, psg.output);

		out.writeInt32(psg.latched);
		out.writeInt32(psg.noise);
		out.writeInt32(psg.shift);
		out.writeInt32(psg.total);
		out.writeInt32(psg.counted);
		out.writeInt32(psg.spare);
	}

	static function readPsg(input:BytesInput, psg:Psg):Void {
		readVector(input, psg.tone);
		readVector(input, psg.attenuation);
		readVector(input, psg.counter);
		readVector(input, psg.output);

		psg.latched = input.readInt32();
		psg.noise = input.readInt32();
		psg.shift = input.readInt32();
		psg.total = input.readInt32();
		psg.counted = input.readInt32();
		psg.spare = input.readInt32();
	}

	static function writeYm(out:BytesOutput, ym:Ym2612):Void {
		writeVector(out, ym.registers);
		for (i in 0...6) writeChannel(out, ym.channels[i]);

		out.writeInt32(ym.address);
		out.writeInt32(ym.part);
		out.writeInt32(ym.timerA);
		out.writeInt32(ym.timerB);
		out.writeInt32(ym.timerACount);
		out.writeInt32(ym.timerBCount);
		out.writeInt32(ym.status);
		out.writeInt32(ym.envelopeCounter);
		out.writeInt32(ym.envelopeDivider);
		out.writeInt32(ym.visible);
		out.writeInt32(ym.position);
		out.writeInt32(ym.pendingHalf);
		out.writeInt32(ym.pendingAddress);
		out.writeInt32(ym.pendingValue);
		out.writeInt32(ym.pendingIn);
		out.writeInt32(ym.lfoPhase);
		out.writeInt32(ym.lfoRate);
		out.writeInt32(ym.lfoHeld);
		out.writeInt32(ym.vibrato);
		out.writeInt32(ym.swell);
		out.writeInt32(ym.mode);
		out.writeInt32(ym.busyFor);
		out.writeInt32(ym.dac);

		out.writeByte((ym.ticking ? 1 : 0) | (ym.waiting ? 2 : 0) | (ym.lfoOn ? 4 : 0)
			| (ym.csmKeyed ? 8 : 0) | (ym.dacOn ? 16 : 0));
	}

	static function readYm(input:BytesInput, ym:Ym2612):Void {
		readVector(input, ym.registers);
		for (i in 0...6) readChannel(input, ym.channels[i]);

		ym.address = input.readInt32();
		ym.part = input.readInt32();
		ym.timerA = input.readInt32();
		ym.timerB = input.readInt32();
		ym.timerACount = input.readInt32();
		ym.timerBCount = input.readInt32();
		ym.status = input.readInt32();
		ym.envelopeCounter = input.readInt32();
		ym.envelopeDivider = input.readInt32();
		ym.visible = input.readInt32();
		ym.position = input.readInt32();
		ym.pendingHalf = input.readInt32();
		ym.pendingAddress = input.readInt32();
		ym.pendingValue = input.readInt32();
		ym.pendingIn = input.readInt32();
		ym.lfoPhase = input.readInt32();
		ym.lfoRate = input.readInt32();
		ym.lfoHeld = input.readInt32();
		ym.vibrato = input.readInt32();
		ym.swell = input.readInt32();
		ym.mode = input.readInt32();
		ym.busyFor = input.readInt32();
		ym.dac = input.readInt32();

		final bits = input.readByte();
		ym.ticking = (bits & 1) != 0;
		ym.waiting = (bits & 2) != 0;
		ym.lfoOn = (bits & 4) != 0;
		ym.csmKeyed = (bits & 8) != 0;
		ym.dacOn = (bits & 16) != 0;
	}

	static function writeChannel(out:BytesOutput, channel:Channel):Void {
		for (i in 0...4) writeOperator(out, channel.operators[i]);

		out.writeInt32(channel.algorithm);
		out.writeInt32(channel.feedback);
		out.writeInt32(channel.frequency);
		out.writeInt32(channel.block);
		out.writeInt32(channel.tremoloDepth);
		out.writeInt32(channel.vibratoDepth);
		out.writeInt32(channel.armed);
		out.writeInt32(channel.keyRequest);
		out.writeInt32(channel.published);
		out.writeInt32(channel.delivered);
		out.writeInt32(channel.accumulated);
		out.writeInt32(channel.carried);
		out.writeInt32(channel.lateTwo);
		out.writeInt32(channel.earlierTwo);
		out.writeInt32(channel.previous);
		out.writeInt32(channel.older);
		out.writeInt32(channel.swept);

		writeVector(out, channel.outputs);
		writeVector(out, channel.notes);
		writeVector(out, channel.blocks);

		out.writeByte((channel.left ? 1 : 0) | (channel.right ? 2 : 0)
			| (channel.separate ? 4 : 0) | (channel.levelled ? 8 : 0));
	}

	static function readChannel(input:BytesInput, channel:Channel):Void {
		for (i in 0...4) readOperator(input, channel.operators[i]);

		channel.algorithm = input.readInt32();
		channel.feedback = input.readInt32();
		channel.frequency = input.readInt32();
		channel.block = input.readInt32();
		channel.tremoloDepth = input.readInt32();
		channel.vibratoDepth = input.readInt32();
		channel.armed = input.readInt32();
		channel.keyRequest = input.readInt32();
		channel.published = input.readInt32();
		channel.delivered = input.readInt32();
		channel.accumulated = input.readInt32();
		channel.carried = input.readInt32();
		channel.lateTwo = input.readInt32();
		channel.earlierTwo = input.readInt32();
		channel.previous = input.readInt32();
		channel.older = input.readInt32();
		channel.swept = input.readInt32();

		readVector(input, channel.outputs);
		readVector(input, channel.notes);
		readVector(input, channel.blocks);

		final bits = input.readByte();
		channel.left = (bits & 1) != 0;
		channel.right = (bits & 2) != 0;
		channel.separate = (bits & 4) != 0;
		channel.levelled = (bits & 8) != 0;
	}

	static function writeOperator(out:BytesOutput, each:Operator):Void {
		out.writeInt32(each.detune);
		out.writeInt32(each.multiple);
		out.writeInt32(each.totalLevel);
		out.writeInt32(each.keyScale);
		out.writeInt32(each.attackRate);
		out.writeInt32(each.decayRate);
		out.writeInt32(each.sustainRate);
		out.writeInt32(each.releaseRate);
		out.writeInt32(each.sustainLevel);
		out.writeInt32(each.phase);
		out.writeInt32(each.increment);
		out.writeInt32(each.envelope);
		out.writeInt32(each.state);
		out.writeInt32(each.ssg);

		out.writeByte((each.tremolo ? 1 : 0) | (each.keyed ? 2 : 0) | (each.restarts ? 4 : 0)
			| (each.repeats ? 8 : 0) | (each.rising ? 16 : 0) | (each.inverted ? 32 : 0)
			| (each.holding ? 64 : 0));
	}

	static function readOperator(input:BytesInput, each:Operator):Void {
		each.detune = input.readInt32();
		each.multiple = input.readInt32();
		each.totalLevel = input.readInt32();
		each.keyScale = input.readInt32();
		each.attackRate = input.readInt32();
		each.decayRate = input.readInt32();
		each.sustainRate = input.readInt32();
		each.releaseRate = input.readInt32();
		each.sustainLevel = input.readInt32();
		each.phase = input.readInt32();
		each.increment = input.readInt32();
		each.envelope = input.readInt32();
		each.state = input.readInt32();
		each.ssg = input.readInt32();

		final bits = input.readByte();
		each.tremolo = (bits & 1) != 0;
		each.keyed = (bits & 2) != 0;
		each.restarts = (bits & 4) != 0;
		each.repeats = (bits & 8) != 0;
		each.rising = (bits & 16) != 0;
		each.inverted = (bits & 32) != 0;
		each.holding = (bits & 64) != 0;
	}

	static function writeMachine(out:BytesOutput, machine:Machine):Void {
		writeVector(out, machine.banks);
		writeVector(out, machine.padControl);
		writeVector(out, machine.padData);

		out.writeInt32(machine.cycles);
		out.writeInt32(machine.z80Master);
		out.writeInt32(machine.z80Bus.bank);
		out.writeInt32(machine.counted);
		out.writeByte((machine.z80BusRequest ? 1 : 0) | (machine.z80Running ? 2 : 0)
			| (machine.owed ? 4 : 0));
	}

	static function readMachine(input:BytesInput, machine:Machine):Void {
		readVector(input, machine.banks);
		readVector(input, machine.padControl);
		readVector(input, machine.padData);

		machine.cycles = input.readInt32();
		machine.z80Master = input.readInt32();
		machine.z80Bus.bank = input.readInt32();
		machine.counted = input.readInt32();

		final bits = input.readByte();
		machine.z80BusRequest = (bits & 1) != 0;
		machine.z80Running = (bits & 2) != 0;
		machine.owed = (bits & 4) != 0;
	}

	static function writeVector(out:BytesOutput, values:Vector<Int>):Void {
		for (i in 0...values.length) out.writeInt32(values[i]);
	}

	static function readVector(input:BytesInput, values:Vector<Int>):Void {
		for (i in 0...values.length) values[i] = input.readInt32();
	}
}

package hx68k.md;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.ds.Vector;

class Savestate {
	static inline final MAGIC = 0x48583638;
	static inline final VERSION = 1;

	public static function of(machine:Machine):Bytes {
		final out = new BytesOutput();
		out.bigEndian = true;

		out.writeInt32(MAGIC);
		out.writeInt32(VERSION);

		writeCpu(out, machine.cpu);
		writeZ80(out, machine.z80);
		writeVdp(out, machine.vdp);
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
		out.writeByte((vdp.pending ? 1 : 0) | (vdp.filling ? 2 : 0) | (vdp.vint ? 4 : 0) | (vdp.hint ? 8 : 0));
	}

	static function readVdp(input:BytesInput, vdp:Vdp):Void {
		readVector(input, vdp.registers);
		readVector(input, vdp.cram);
		readVector(input, vdp.vsram);
		input.readBytes(vdp.vram, 0, vdp.vram.length);

		vdp.line = input.readInt32();
		vdp.frame = input.readInt32();
		vdp.dot = input.readInt32();
		vdp.address = input.readInt32();
		vdp.code = input.readInt32();
		vdp.hintCounter = input.readInt32();

		final bits = input.readByte();
		vdp.pending = (bits & 1) != 0;
		vdp.filling = (bits & 2) != 0;
		vdp.vint = (bits & 4) != 0;
		vdp.hint = (bits & 8) != 0;
	}

	static function writeMachine(out:BytesOutput, machine:Machine):Void {
		writeVector(out, machine.banks);
		writeVector(out, machine.padControl);
		writeVector(out, machine.padData);

		out.writeInt32(machine.cycles);
		out.writeInt32(machine.z80Master);
		out.writeInt32(machine.z80Bus.bank);
		out.writeByte((machine.z80BusRequest ? 1 : 0) | (machine.z80Running ? 2 : 0));
	}

	static function readMachine(input:BytesInput, machine:Machine):Void {
		readVector(input, machine.banks);
		readVector(input, machine.padControl);
		readVector(input, machine.padData);

		machine.cycles = input.readInt32();
		machine.z80Master = input.readInt32();
		machine.z80Bus.bank = input.readInt32();

		final bits = input.readByte();
		machine.z80BusRequest = (bits & 1) != 0;
		machine.z80Running = (bits & 2) != 0;
	}

	static function writeVector(out:BytesOutput, values:Vector<Int>):Void {
		for (i in 0...values.length) out.writeInt32(values[i]);
	}

	static function readVector(input:BytesInput, values:Vector<Int>):Void {
		for (i in 0...values.length) values[i] = input.readInt32();
	}
}

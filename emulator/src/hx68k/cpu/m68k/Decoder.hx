package hx68k.cpu.m68k;

import haxe.ds.Vector;

class Decoder {
	public static function build():Vector<M68000->Void> {
		final t = new Vector<M68000->Void>(0x10000);
		for (i in 0...0x10000) t[i] = null;

		nop(t);
		Moves.moveq(t);
		Moves.move(t);
		Arithmetic.tst(t);
		Arithmetic.clr(t);
		Arithmetic.unary(t, 0x4600, Arithmetic.NOT);
		Arithmetic.unary(t, 0x4400, Arithmetic.NEG);
		Arithmetic.unary(t, 0x4000, Arithmetic.NEGX);
		Moves.swapExt(t);

		Arithmetic.aluEaToReg(t, 0x8000, Arithmetic.OP_OR);
		Arithmetic.aluEaToReg(t, 0xC000, Arithmetic.OP_AND);
		Arithmetic.aluEaToReg(t, 0x9000, Arithmetic.OP_SUB);
		Arithmetic.aluEaToReg(t, 0xD000, Arithmetic.OP_ADD);
		Arithmetic.aluEaToReg(t, 0xB000, Arithmetic.OP_CMP);

		Arithmetic.aluRegToEa(t, 0x8000, Arithmetic.OP_OR);
		Arithmetic.aluRegToEa(t, 0xC000, Arithmetic.OP_AND);
		Arithmetic.aluRegToEa(t, 0x9000, Arithmetic.OP_SUB);
		Arithmetic.aluRegToEa(t, 0xD000, Arithmetic.OP_ADD);
		Arithmetic.aluRegToEa(t, 0xB000, Arithmetic.OP_EOR);

		Arithmetic.aluAddress(t, 0x9000, Arithmetic.OP_SUB);
		Arithmetic.aluAddress(t, 0xD000, Arithmetic.OP_ADD);
		Arithmetic.aluAddress(t, 0xB000, Arithmetic.OP_CMP);

		Arithmetic.aluImmediate(t, 0x0000, Arithmetic.OP_OR);
		Arithmetic.aluImmediate(t, 0x0200, Arithmetic.OP_AND);
		Arithmetic.aluImmediate(t, 0x0400, Arithmetic.OP_SUB);
		Arithmetic.aluImmediate(t, 0x0600, Arithmetic.OP_ADD);
		Arithmetic.aluImmediate(t, 0x0A00, Arithmetic.OP_EOR);
		Arithmetic.aluImmediate(t, 0x0C00, Arithmetic.OP_CMP);

		Arithmetic.quick(t);
		Arithmetic.cmpm(t);

		Shifts.shiftsReg(t);
		Shifts.shiftsMem(t);
		Shifts.bitOps(t);

		Arithmetic.extended(t, 0xC100, Arithmetic.EX_ABCD);
		Arithmetic.extended(t, 0x8100, Arithmetic.EX_SBCD);
		Arithmetic.extended(t, 0xD100, Arithmetic.EX_ADDX);
		Arithmetic.extended(t, 0x9100, Arithmetic.EX_SUBX);
		Arithmetic.nbcd(t);
		Moves.exg(t);

		Branches.branches(t);
		Branches.dbcc(t);
		Branches.scc(t);
		Branches.jumps(t);
		Moves.effectiveAddress(t);
		Moves.linkage(t);
		Branches.returns(t);
		Moves.movem(t);
		Moves.movep(t);
		MultiplyDivide.multiply(t);
		MultiplyDivide.divide(t);

		Exceptions.traps(t);
		Exceptions.check(t);
		Exceptions.statusRegister(t);
		Exceptions.statusImmediate(t);
		Shifts.tas(t);
		Exceptions.supervisorOnly(t);

		return t;
	}

	static function nop(t:Vector<M68000->Void>):Void {
		t[0x4E71] = function(c:M68000) c.prefetch();
	}
}

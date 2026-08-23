package hx68k.cpu.m68k;

import haxe.ds.Vector;
import hx68k.cpu.m68k.Addressing.*;
import hx68k.cpu.m68k.Flags.*;

class Moves {
	public static function moveq(t:Vector<M68000->Void>):Void {
		for (reg in 0...8) {
			for (imm in 0...256) {
				final r = reg;
				final v = signExt8(imm);
				t[0x7000 | (reg << 9) | imm] = function(c:M68000) {
					c.d[r] = v;
					c.nf = v < 0;
					c.zf = v == 0;
					c.vf = false;
					c.cf = false;
					c.prefetch();
				}
			}
		}
	}

	public static function move(t:Vector<M68000->Void>):Void {
		final bases = [0x1000, 0x3000, 0x2000];
		final sizes = [1, 2, 4];

		for (i in 0...bases.length) {
			final base = bases[i];
			final size = sizes[i];

			for (dm in 0...8) for (dr in 0...8) for (sm in 0...8) for (sr in 0...8) {
				if (dm == 7 && dr > 1) continue;
				if (sm == 7 && sr > 4) continue;
				if (dm == 1 && size == 1) continue;
				if (sm == 1 && size == 1) continue;

				final op = base | (dr << 9) | (dm << 6) | (sm << 3) | sr;
				final srcMode = sm, srcReg = sr, dstMode = dm, dstReg = dr, sz = size;
				final srcExt = extWords(sm, sr, size);
				final srcMem = sm >= 2 && !(sm == 7 && sr == 4);

				final earlyVc = size != 4 || srcMem || dm == 4 || dm == 7;
				final earlyNz = size != 4 || (dm != 2 && dm != 3 && !(dm == 7 && dr == 1 && srcMem));
				final lowWordN = size == 4 && srcMem && (dm == 2 || dm == 3 || (dm == 7 && dr == 1));

				t[op] = function(c:M68000) {
					final v = readEa(c, srcMode, srcReg, sz, 0);
					if (c.faulted) return;

					c.faultPc = (c.pcAtStart + (srcExt << 1)) | 0;

					if (dstMode == 1) {
						c.a[dstReg] = sz == 2 ? signExt16(v) : (v | 0);
						c.prefetch();
						return;
					}

					if (dstMode == 0) {
						writeReg(c, dstReg, sz, v);
						setLogicFlags(c, v, sz);
						c.prefetch();
						return;
					}

					if (earlyNz) setNz(c, v, sz);
					else if (lowWordN) {
						c.nf = (v & 0x8000) != 0;
						c.zf = v == 0;
					}
					if (earlyVc) {
						c.vf = false;
						c.cf = false;
					}

					if (dstMode == 3) {
						final addr = c.a[dstReg] | 0;
						final step = (dstReg == 7 && sz == 1) ? 2 : sz;
						if (sz == 1 || (addr & 1) == 0) c.a[dstReg] = (addr + step) | 0;
						writeMem(c, addr, sz, v);
						if (c.faulted) return;
						settleFlags(c, v, sz, earlyNz, earlyVc);
						c.prefetch();
						return;
					}

					if (dstMode == 4) {
						final step = (dstReg == 7 && sz == 1) ? 2 : sz;
						final addr = (c.a[dstReg] - step) | 0;
						if (sz != 4 || (addr & 1) == 0) c.a[dstReg] = addr;
						c.prefetch();
						if (c.faulted) return;
						if (sz == 4) {
							c.faultIr = c.opcode;
							c.writeLongLowFirst(addr, c.dataFc(), v);
						} else {
							writeMem(c, addr, sz, v);
						}
						if (c.faulted) return;
						settleFlags(c, v, sz, earlyNz, earlyVc);
						return;
					}

					if (dstMode == 7 && dstReg == 1) {
						if (srcMem) {
							final hi = c.fetchExt();
							final lo = c.irc;
							writeMem(c, ((hi << 16) | lo) | 0, sz, v);
							if (c.faulted) return;
							settleFlags(c, v, sz, earlyNz, earlyVc);
							c.fetchExt();
							c.prefetch();
							return;
						}

						final hi = c.fetchExt();
						final lo = c.fetchExt();
						c.faultPc = (c.pcAtStart + (srcExt << 1) + 2) | 0;
						writeMem(c, ((hi << 16) | lo) | 0, sz, v);
						if (c.faulted) return;
						settleFlags(c, v, sz, earlyNz, earlyVc);
						c.prefetch();
						return;
					}

					final addr = eaAddr(c, dstMode, dstReg, sz);
					if (c.faulted) return;
					writeMem(c, addr, sz, v);
					if (c.faulted) return;
					settleFlags(c, v, sz, earlyNz, earlyVc);
					c.prefetch();
				}
			}
		}
	}

	static inline function movemValue(c:M68000, index:Int):Int {
		return index < 8 ? c.d[index] : c.a[index - 8];
	}

	static inline function movemRead(c:M68000, index:Int, size:Int, addr:Int, fc:Int):Void {
		final raw = size == 2 ? c.readWord(addr, fc) : c.readLong(addr, fc);
		if (c.faulted) return;
		final v = size == 2 ? signExt16(raw) : raw;
		if (index < 8) c.d[index] = v; else c.a[index - 8] = v;
	}

	public static function movem(t:Vector<M68000->Void>):Void {
		for (dr in 0...2) for (long in 0...2) for (m in 0...8) for (r in 0...8) {
			final toMemory = dr == 0;
			final ok = toMemory ? (m == 2 || m == 4 || m == 5 || m == 6 || (m == 7 && r <= 1)) : (m == 2 || m == 3 || m == 5
				|| m == 6 || (m == 7 && r <= 3));
			if (!ok) continue;

			final mode = m, reg = r;
			final size = long == 1 ? 4 : 2;

			t[0x4880 | (dr << 10) | (long << 6) | (m << 3) | r] = function(c:M68000) {
				final mask = c.fetchExt();

				if (toMemory) {
					if (mode == 4) {
						c.faultPc = c.pc | 0;
						var addr = c.a[reg] | 0;
						for (i in 0...16) {
							if ((mask & (1 << i)) == 0) continue;
							final v = movemValue(c, 15 - i);
							addr = (addr - size) | 0;
							if (size == 2) c.writeWord(addr, c.dataFc(), v & 0xFFFF); else
								c.writeLongLowFirst(addr, c.dataFc(), v);
							if (c.faulted) return;
						}
						c.a[reg] = addr;
						c.prefetch();
						return;
					}

					var addr = eaAddr(c, mode, reg, size);
					if (c.faulted) return;
					c.faultPc = c.pc | 0;
					for (i in 0...16) {
						if ((mask & (1 << i)) == 0) continue;
						final v = movemValue(c, i);
						if (size == 2) c.writeWord(addr, c.dataFc(), v & 0xFFFF); else
							c.writeLong(addr, c.dataFc(), v);
						if (c.faulted) return;
						addr = (addr + size) | 0;
					}
					c.prefetch();
					return;
				}

				var addr = mode == 3 ? (c.a[reg] | 0) : eaAddr(c, mode, reg, size);
				if (c.faulted) return;
				c.faultPc = c.pc | 0;

				final fc = (mode == 7 && reg >= 2) ? c.progFc() : c.dataFc();
				for (i in 0...16) {
					if ((mask & (1 << i)) == 0) continue;
					movemRead(c, i, size, addr, fc);
					if (c.faulted) return;
					addr = (addr + size) | 0;
				}

				c.readWord(addr, fc);
				if (c.faulted) return;
				if (mode == 3) c.a[reg] = addr;
				c.prefetch();
			}
		}
	}

	public static function movep(t:Vector<M68000->Void>):Void {
		for (dreg in 0...8) for (opmode in 4...8) for (areg in 0...8) {
			final d = dreg, a = areg;
			final size = (opmode & 1) == 1 ? 4 : 2;
			final toMemory = opmode >= 6;

			t[0x0008 | (dreg << 9) | (opmode << 6) | areg] = function(c:M68000) {
				final addr = (c.a[a] + signExt16(c.fetchExt())) | 0;
				final count = size == 4 ? 4 : 2;

				if (toMemory) {
					var shift = (count - 1) << 3;
					for (i in 0...count) {
						c.writeByte((addr + (i << 1)) | 0, c.dataFc(), (c.d[d] >>> shift) & 0xFF);
						shift -= 8;
					}
					c.prefetch();
					return;
				}

				var v = 0;
				for (i in 0...count) v = (v << 8) | c.readByte((addr + (i << 1)) | 0, c.dataFc());
				if (size == 4) c.d[d] = v | 0; else c.d[d] = (c.d[d] & 0xFFFF0000) | (v & 0xFFFF);
				c.prefetch();
			}
		}
	}

	public static function swapExt(t:Vector<M68000->Void>):Void {
		for (r in 0...8) {
			final reg = r;

			t[0x4840 | r] = function(c:M68000) {
				final v = c.d[reg];
				final res = ((v << 16) | (v >>> 16)) | 0;
				c.d[reg] = res;
				setLogicFlags(c, res, 4);
				c.prefetch();
			}

			t[0x4880 | r] = function(c:M68000) {
				final res = signExt8(c.d[reg] & 0xFF) & 0xFFFF;
				c.d[reg] = (c.d[reg] & 0xFFFF0000) | res;
				setLogicFlags(c, res, 2);
				c.prefetch();
			}

			t[0x48C0 | r] = function(c:M68000) {
				final res = signExt16(c.d[reg] & 0xFFFF);
				c.d[reg] = res;
				setLogicFlags(c, res, 4);
				c.prefetch();
			}
		}
	}

	public static function exg(t:Vector<M68000->Void>):Void {
		for (rx in 0...8) for (ry in 0...8) {
			final x = rx, y = ry;

			t[0xC140 | (rx << 9) | ry] = function(c:M68000) {
				final tmp = c.d[x];
				c.d[x] = c.d[y];
				c.d[y] = tmp;
				c.prefetch();
				c.idle(2);
			}

			t[0xC148 | (rx << 9) | ry] = function(c:M68000) {
				final tmp = c.a[x];
				c.a[x] = c.a[y];
				c.a[y] = tmp;
				c.prefetch();
				c.idle(2);
			}

			t[0xC188 | (rx << 9) | ry] = function(c:M68000) {
				final tmp = c.d[x];
				c.d[x] = c.a[y];
				c.a[y] = tmp;
				c.prefetch();
				c.idle(2);
			}
		}
	}

	public static function effectiveAddress(t:Vector<M68000->Void>):Void {
		for (m in 0...8) for (r in 0...8) {
			if (!control(m, r)) continue;

			final mode = m, reg = r;
			final extra = (m == 6 || (m == 7 && r == 3)) ? 2 : 0;

			for (areg in 0...8) {
				final a = areg;
				t[0x41C0 | (areg << 9) | (m << 3) | r] = function(c:M68000) {
					final addr = eaAddr(c, mode, reg, 4);
					c.idle(extra);
					c.a[a] = addr;
					c.prefetch();
				}
			}

			final absolute = m == 7 && r <= 1;

			t[0x4840 | (m << 3) | r] = function(c:M68000) {
				final addr = eaAddr(c, mode, reg, 4);
				c.idle(extra);
				if (absolute) {
					push32(c, addr);
					if (c.faulted) return;
					c.prefetch();
					return;
				}
				c.prefetch();
				push32(c, addr);
			}
		}
	}

	public static function linkage(t:Vector<M68000->Void>):Void {
		for (reg in 0...8) {
			final r = reg;

			t[0x4E50 | reg] = function(c:M68000) {
				final disp = signExt16(c.fetchExt());
				push32(c, c.a[r] | 0);
				if (c.faulted) return;
				c.a[r] = c.a[7] | 0;
				c.a[7] = (c.a[7] + disp) | 0;
				c.prefetch();
			}

			t[0x4E58 | reg] = function(c:M68000) {
				final sp = c.a[r] | 0;
				c.faultPc = c.pcAtStart;
				final v = c.readLong(sp, c.dataFc());
				if (c.faulted) return;
				c.a[7] = (sp + 4) | 0;
				c.a[r] = v;
				c.prefetch();
			}
		}
	}
}

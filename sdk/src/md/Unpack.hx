package md;

class Unpack {
	static var source:Int = 0;
	static var tag:Int = 0;
	static var left:Int = 0;

	public static function aplib(from:Int, into:Int):Int {
		source = from;
		tag = 0;
		left = 0;

		var out:Int = into;
		var lwm:Int = 2;
		var last:Int = 0;

		Memory.storeU8(out, Memory.loadU8(source++));
		out++;

		while (true) {
			if (bit() == 0) {
				Memory.storeU8(out, Memory.loadU8(source++));
				out++;
				lwm = 2;
				continue;
			}

			if (bit() == 0) {
				var length:Int = gamma() - lwm;
				var offset:Int;

				if (length == 0) {
					offset = last;
					length = gamma();
				} else {
					offset = ((length - 1) << 8) | Memory.loadU8(source++);
					length = gamma();
					if (offset >= 32000) length += 2;
					else if (offset >= 1280) length += 1;
					else if (offset < 128) length += 2;
					last = offset;
				}

				out = repeat(out, offset, length);
				lwm = 1;
				continue;
			}

			if (bit() == 0) {
				final held:Int = Memory.loadU8(source++);
				final offset:Int = held >> 1;
				if (offset == 0) break;

				out = repeat(out, offset, 2 + (held & 1));
				last = offset;
				lwm = 1;
				continue;
			}

			var offset:Int = 0;
			var taken:Int = 4;
			while (taken-- > 0) offset = (offset << 1) | bit();

			if (offset == 0) {
				Memory.storeU8(out, 0);
			} else {
				final value:Int = Memory.loadU8(out - offset);
				Memory.storeU8(out, value);
			}

			out++;
			lwm = 2;
		}

		return out - into;
	}

	@:md.body("	const u8* source = (const u8*)from;
	u8* target = (u8*)into;

	__asm__ __volatile__ (
		\"1:\\n\"
		\"	moveq	#0,%%d0\\n\"
		\"	move.b	(%0)+,%%d0\\n\"
		\"	moveq	#0,%%d1\\n\"
		\"	move.b	(%0)+,%%d1\\n\"
		\"	move.w	%%d0,%%d3\\n\"
		\"	or.w	%%d1,%%d3\\n\"
		\"	beq.w	8f\\n\"
		\"	move.w	%%d0,%%d2\\n\"
		\"	lsr.w	#4,%%d2\\n\"
		\"	add.w	%%d2,%%d2\\n\"
		\"	lea	2f(%%pc),%%a1\\n\"
		\"	suba.w	%%d2,%%a1\\n\"
		\"	jmp	(%%a1)\\n\"
		\"	.rept	15\\n\"
		\"	move.w	(%0)+,(%1)+\\n\"
		\"	.endr\\n\"
		\"2:	and.w	#15,%%d0\\n\"
		\"	beq.w	5f\\n\"
		\"	addq.w	#1,%%d1\\n\"
		\"	add.w	%%d1,%%d1\\n\"
		\"	move.l	%1,%%a0\\n\"
		\"	suba.w	%%d1,%%a0\\n\"
		\"	addq.w	#1,%%d0\\n\"
		\"	add.w	%%d0,%%d0\\n\"
		\"	lea	4f(%%pc),%%a1\\n\"
		\"	suba.w	%%d0,%%a1\\n\"
		\"	jmp	(%%a1)\\n\"
		\"	.rept	16\\n\"
		\"	move.w	(%%a0)+,(%1)+\\n\"
		\"	.endr\\n\"
		\"4:	bra.w	1b\\n\"
		\"5:	tst.w	%%d1\\n\"
		\"	beq.w	1b\\n\"
		\"	move.w	(%0)+,%%d3\\n\"
		\"	neg.w	%%d3\\n\"
		\"	and.w	#32767,%%d3\\n\"
		\"	addq.w	#1,%%d3\\n\"
		\"	add.w	%%d3,%%d3\\n\"
		\"	move.l	%1,%%a0\\n\"
		\"	suba.w	%%d3,%%a0\\n\"
		\"	addq.w	#1,%%d1\\n\"
		\"6:	move.w	(%%a0)+,(%1)+\\n\"
		\"	dbra	%%d1,6b\\n\"
		\"	bra.w	1b\\n\"
		\"8:	move.w	(%0),%%d3\\n\"
		\"	btst	#15,%%d3\\n\"
		\"	beq.s	9f\\n\"
		\"	move.b	%%d3,(%1)\\n\"
		\"	addq.l	#1,%1\\n\"
		\"9:\\n\"
		: \"+a\" (source), \"+a\" (target)
		:
		: \"d0\", \"d1\", \"d2\", \"d3\", \"a0\", \"a1\", \"memory\", \"cc\"
	);

	return (s32)target - into;")
	public static function lz4w(from:Int, into:Int):Int {
		return 0;
	}

	static inline function repeat(out:Int, offset:Int, length:Int):Int {
		return Copy.bytes(out, out - offset, length);
	}

	static inline function repeatWords(out:Int, offset:Int, words:Int):Int {
		return Copy.words(out, out - offset, words);
	}

	static function bit():Int {
		if (left == 0) {
			tag = Memory.loadU8(source++);
			left = 8;
		}
		left--;
		return (tag >> left) & 1;
	}

	static function gamma():Int {
		var value:Int = 1;
		var more:Int = 1;

		while (more == 1) {
			value = (value << 1) | bit();
			more = bit();
		}

		return value;
	}
}

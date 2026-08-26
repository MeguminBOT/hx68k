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

	@:md.body("	register const u8* held __asm__(\"a0\") = (const u8*)from;
	register u8* grown __asm__(\"a1\") = (u8*)into;

	__asm__ __volatile__ (
		\"	.macro	LZ4W_NEXT\\n\"
		\"	moveq	#0,%%d1\\n\"
		\"	moveq	#0,%%d0\\n\"
		\"	move.b	(%%a0)+,%%d0\\n\"
		\"	move.b	(%%a0)+,%%d1\\n\"
		\"	add.w	%%d0,%%d0\\n\"
		\"	add.w	%%d0,%%d0\\n\"
		\"	jmp	(%%a3,%%d0.w)\\n\"
		\"	.endm\\n\"
		\"\\n\"
		\"	.macro	LZ4W_MATCH words\\n\"
		\"	add.w	%%d1,%%d1\\n\"
		\"	neg.w	%%d1\\n\"
		\"	lea	-2(%%a1,%%d1.w),%%a2\\n\"
		\"	.rept	((\\\\words)+1)\\n\"
		\"	move.w	(%%a2)+,(%%a1)+\\n\"
		\"	.endr\\n\"
		\"	LZ4W_NEXT\\n\"
		\"	.endm\\n\"
		\"\\n\"
		\"	.macro	LZ4W_LONG\\n\"
		\"	move.w	(%%a0)+,%%d0\\n\"
		\"	add.w	%%d0,%%d0\\n\"
		\"	bcs.w	Lfromsource\\n\"
		\"	lea	-2(%%a1,%%d0.w),%%a2\\n\"
		\"	neg.w	%%d1\\n\"
		\"	jmp	(%%a4,%%d1.w)\\n\"
		\"	.endm\\n\"
		\"\\n\"
		\"	.macro	LZ4W_GROUP match\\n\"
		\"Lliteral14match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral12match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral10match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral8match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral6match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral4match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral2match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral0match\\\\match:\\n\"
		\"	LZ4W_MATCH \\\\match\\n\"
		\"Lliteral15match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral13match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral11match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral9match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral7match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral5match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral3match\\\\match:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral1match\\\\match:	move.w	(%%a0)+,(%%a1)+\\n\"
		\"	LZ4W_MATCH \\\\match\\n\"
		\"	.endm\\n\"
		\"\\n\"
		\"	.macro	LZ4W_ROW literal\\n\"
		\"	.irp	match,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15\\n\"
		\"	bra.w	Lliteral\\\\literal\\\\()match\\\\match\\n\"
		\"	.endr\\n\"
		\"	.endm\\n\"
		\"\\n\"
		\"	lea	Ltable(%%pc),%%a3\\n\"
		\"	lea	Lmatchlength(%%pc),%%a4\\n\"
		\"	LZ4W_NEXT\\n\"
		\"\\n\"
		\"Ltable:\\n\"
		\"	LZ4W_ROW 0\\n\"
		\"	LZ4W_ROW 1\\n\"
		\"	LZ4W_ROW 2\\n\"
		\"	LZ4W_ROW 3\\n\"
		\"	LZ4W_ROW 4\\n\"
		\"	LZ4W_ROW 5\\n\"
		\"	LZ4W_ROW 6\\n\"
		\"	LZ4W_ROW 7\\n\"
		\"	LZ4W_ROW 8\\n\"
		\"	LZ4W_ROW 9\\n\"
		\"	LZ4W_ROW 10\\n\"
		\"	LZ4W_ROW 11\\n\"
		\"	LZ4W_ROW 12\\n\"
		\"	LZ4W_ROW 13\\n\"
		\"	LZ4W_ROW 14\\n\"
		\"	LZ4W_ROW 15\\n\"
		\"\\n\"
		\"	.irp	match,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15\\n\"
		\"	LZ4W_GROUP \\\\match\\n\"
		\"	.endr\\n\"
		\"\\n\"
		\"Lliteral14match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral12match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral10match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral8match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral6match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral4match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral2match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"	add.w	%%d1,%%d1\\n\"
		\"	beq.w	Lnext\\n\"
		\"	LZ4W_LONG\\n\"
		\"\\n\"
		\"Lliteral15match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral13match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral11match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral9match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral7match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral5match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral3match0:	move.l	(%%a0)+,(%%a1)+\\n\"
		\"Lliteral1match0:	move.w	(%%a0)+,(%%a1)+\\n\"
		\"	add.w	%%d1,%%d1\\n\"
		\"	beq.w	Lnext\\n\"
		\"	LZ4W_LONG\\n\"
		\"\\n\"
		\"Lliteral0match0:\\n\"
		\"	add.w	%%d1,%%d1\\n\"
		\"	beq.w	Ldone\\n\"
		\"	LZ4W_LONG\\n\"
		\"\\n\"
		\"Lfromsource:\\n\"
		\"	lea	-2(%%a0,%%d0.w),%%a2\\n\"
		\"	lsr.w	#1,%%d1\\n\"
		\"	addq.w	#1,%%d1\\n\"
		\"Lfromsourceloop:\\n\"
		\"	move.w	(%%a2)+,(%%a1)+\\n\"
		\"	dbra	%%d1,Lfromsourceloop\\n\"
		\"	LZ4W_NEXT\\n\"
		\"\\n\"
		\"	.rept	255\\n\"
		\"	move.w	(%%a2)+,(%%a1)+\\n\"
		\"	.endr\\n\"
		\"Lmatchlength:\\n\"
		\"	move.w	(%%a2)+,(%%a1)+\\n\"
		\"	move.w	(%%a2)+,(%%a1)+\\n\"
		\"	moveq	#0,%%d1\\n\"
		\"Lnext:\\n\"
		\"	moveq	#0,%%d0\\n\"
		\"	move.b	(%%a0)+,%%d0\\n\"
		\"	move.b	(%%a0)+,%%d1\\n\"
		\"	add.w	%%d0,%%d0\\n\"
		\"	add.w	%%d0,%%d0\\n\"
		\"	jmp	(%%a3,%%d0.w)\\n\"
		\"\\n\"
		\"Ldone:\\n\"
		\"	move.w	(%%a0)+,%%d0\\n\"
		\"	bpl.s	Lnobyte\\n\"
		\"	move.b	%%d0,(%%a1)+\\n\"
		\"Lnobyte:\\n\"
		\"	.purgem	LZ4W_NEXT\\n\"
		\"	.purgem	LZ4W_MATCH\\n\"
		\"	.purgem	LZ4W_LONG\\n\"
		\"	.purgem	LZ4W_GROUP\\n\"
		\"	.purgem	LZ4W_ROW\\n\"
		: \"+a\" (held), \"+a\" (grown)
		:
		: \"d0\", \"d1\", \"a2\", \"a3\", \"a4\", \"memory\", \"cc\"
	);

	return (s32)grown - into;")
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

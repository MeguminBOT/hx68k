#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>

#include "md.h"
#include "m68k.h"

static int g_checks;
static int g_fails;
static int g_suite_fails;

/*
 * What Musashi saw, written out so hx68k-emu can be held to the same numbers
 * running the same ROM. Paths are relative to the repository root.
 */
static FILE *g_dump;

static void dump_rom(const char *name, const char *dir)
{
	if (!g_dump)
		return;
	fprintf(g_dump, "rom %s %s/rom/out/release/rom.bin %s/rom/out/release/rom.out\n",
	        name, dir, dir);
}

static void dump_line(const char *fmt, ...)
{
	va_list ap;

	if (!g_dump)
		return;

	va_start(ap, fmt);
	vfprintf(g_dump, fmt, ap);
	va_end(ap);
	fprintf(g_dump, "\n");
}

static void check(int ok, const char *fmt, ...)
{
	va_list ap;

	g_checks++;
	if (ok) {
		printf("  ok   ");
	} else {
		g_fails++;
		g_suite_fails++;
		printf("  FAIL ");
	}

	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	printf("\n");
}

static void suite(const char *name)
{
	g_suite_fails = 0;
	printf("\n%s\n", name);
}

static int boot(const char *rom, const char *sym)
{
	if (!md_load_rom(rom)) {
		printf("  FAIL cannot load rom: %s\n", rom);
		g_fails++;
		g_checks++;
		return 0;
	}
	if (!sym_load(sym)) {
		printf("  FAIL cannot load symbols: %s\n", sym);
		g_fails++;
		g_checks++;
		return 0;
	}
	md_reset();
	return 1;
}

static uint16_t plane_entry(uint32_t base, uint32_t col, uint32_t row)
{
	uint32_t w = md_plane_width();
	uint32_t a = (base + ((row * w) + col) * 2) & 0xFFFE;
	return (uint16_t)((md_vram[a] << 8) | md_vram[a | 1]);
}

static int32_t expect_ramp(int32_t t)
{
	int32_t phase = (t >> 2) & 31;
	int32_t level = phase < 16 ? phase : 31 - phase;
	return level << 1;
}

static int32_t expect_entity_sum(int32_t frames)
{
	int32_t total = 0;
	int i;

	for (i = 0; i < 64; i++)
		total += ((i * 4) + frames * (i + 1)) & 255;

	return total;
}

static void suite_spike(const char *rom, const char *sym)
{
	const char *text = "HX68K SPIKE";
	const size_t text_len = 11;
	uint32_t main_addr = 0;
	uint32_t frame_addr = 0;
	uint32_t live_addr = 0;
	uint32_t sum_addr = 0;
	uint32_t bases[3];
	const char *base_names[3] = { "plane A", "plane B", "window" };
	int reached = 0;
	int f;
	int32_t last_frame_value;
	size_t i, j;
	size_t seq_count = 0;
	uint16_t seq[64];
	int text_ok = 0;
	int text_which = -1;

	suite("spike: haxe codegen on real 68000");

	if (!boot(rom, sym))
		return;

	check(sym_lookup("Main_main", &main_addr), "symbol Main_main found (0x%06X)", main_addr);
	check(sym_lookup("Main_frame", &frame_addr), "symbol Main_frame found (0x%06X)", frame_addr);
	check(sym_lookup("Main_live", &live_addr), "symbol Main_live found (0x%06X)", live_addr);
	check(sym_lookup("Main_sum", &sum_addr), "symbol Main_sum found (0x%06X)", sum_addr);

	if (!main_addr || !frame_addr)
		return;

	md_watch_pc(main_addr);

	for (f = 0; f < 60 && !reached; f++) {
		md_run_frame();
		reached = md_pc_was_hit(main_addr);
	}

	check(reached, "cpu reached Main_main within 60 frames");
	if (!reached) {
		md_dump_context();
		return;
	}

	/* a natively booted ROM clears the whole of VRAM, CRAM and VSRAM through the data port
	   before its own loop starts, which is more than a frame's worth of writes. Wait for the
	   frame counter to start moving before measuring how fast it moves. */
	{
		int32_t settling = (int32_t)md_read_ram32(frame_addr);

		for (f = 0; f < 30; f++) {
			md_run_frame();
			if ((int32_t)md_read_ram32(frame_addr) != settling)
				break;
		}
		md_run_frame();
	}

	{
		int32_t before = (int32_t)md_read_ram32(frame_addr);
		int steady = 1;
		int32_t prev = before;

		for (f = 0; f < 10; f++) {
			int32_t now;
			md_run_frame();
			now = (int32_t)md_read_ram32(frame_addr);
			if (now != prev + 1)
				steady = 0;
			prev = now;
		}

		last_frame_value = prev;
		check(steady, "Main_frame advances exactly 1 per frame (%d -> %d)", before, prev);
	}

	if (live_addr && sum_addr) {
		int32_t live = (int32_t)md_read_ram32(live_addr);
		int32_t sum = (int32_t)md_read_ram32(sum_addr);
		int32_t want = expect_entity_sum(last_frame_value);

		check(live == 64, "pool allocated 64 entities (got %d)", live);
		check(sum == want, "64 pooled entities updated on frame %d (got %d want %d)",
		      last_frame_value, sum, want);
	}

	for (i = 0; i < md_log_count; i++) {
		if (md_log[i].kind == MD_W_CRAM && md_log[i].addr == 0) {
			if (seq_count < 64)
				seq[seq_count++] = md_log[i].value;
			else {
				memmove(seq, seq + 1, sizeof(seq) - sizeof(seq[0]));
				seq[63] = md_log[i].value;
			}
		}
	}

	check(seq_count > 8, "captured %u CRAM colour-0 writes", (unsigned)seq_count);

	if (seq_count > 8) {
		size_t k = seq_count < 32 ? seq_count : 32;
		int match = 1;
		int32_t first_t = last_frame_value - (int32_t)k + 1;

		for (i = 0; i < k; i++) {
			int32_t want = expect_ramp(first_t + (int32_t)i);
			if ((int32_t)seq[seq_count - k + i] != want) {
				match = 0;
				printf("       t=%d got 0x%04X want 0x%04X\n",
				       first_t + (int32_t)i, seq[seq_count - k + i], (unsigned)want);
				break;
			}
		}

		check(match, "last %u colour writes match ramp() computed on host", (unsigned)k);
	}

	bases[0] = (uint32_t)(md_vdp_reg[2] & 0x38) << 10;
	bases[1] = (uint32_t)(md_vdp_reg[4] & 0x07) << 13;
	bases[2] = (uint32_t)(md_vdp_reg[3] & 0x3E) << 10;

	for (j = 0; j < 3 && !text_ok; j++) {
		int shape = 1;
		int any = 0;

		for (i = 0; i < text_len; i++) {
			uint16_t a = plane_entry(bases[j], 12 + (uint32_t)i, 12) & 0x07FF;
			size_t k;

			if (a != 0)
				any = 1;

			for (k = 0; k < text_len; k++) {
				uint16_t b = plane_entry(bases[j], 12 + (uint32_t)k, 12) & 0x07FF;
				int same_char = text[i] == text[k];
				if (same_char != (a == b)) {
					shape = 0;
					break;
				}
			}
			if (!shape)
				break;
		}

		if (shape && any) {
			text_ok = 1;
			text_which = (int)j;
		}
	}

	check(text_ok, "the font tilemap matches the string's repeat pattern (%s)",
	      text_which >= 0 ? base_names[text_which] : "not found");

	dump_rom("spike", "samples/spike");
	dump_line("until Main_frame 4 %d 90", last_frame_value);
	dump_line("value Main_live 0 4 %d", (int32_t)md_read_ram32(live_addr));
	dump_line("value Main_sum 0 4 %d", (int32_t)md_read_ram32(sum_addr));
	dump_line("cram 0 %d", md_cram[0]);
	if (text_which >= 0) {
		for (i = 0; i < text_len; i++) {
			uint32_t w = md_plane_width();
			uint32_t a = (bases[text_which] + ((12 * w) + 12 + (uint32_t)i) * 2) & 0xFFFE;
			dump_line("vram %u %u", a, (unsigned)((md_vram[a] << 8) | md_vram[a | 1]));
		}
	}
}

typedef struct {
	const char *name;
	int32_t     expected;
} probe_t;

#define PROBE_ANY  0x7FFFFFFF
#define COUNT(a)   (sizeof(a) / sizeof((a)[0]))

static const probe_t conformance_expected[] = {
	{ "add/sub/mul",            (7 + 5) * 3 - 11 },
	{ "int division",           1000 / 7 },
	{ "modulo",                 1000 % 7 },
	{ "negative division",      -1000 / 7 },
	{ "negative modulo",        -1000 % 7 },
	{ "shift left",             1 << 20 },
	{ "arithmetic shift right", -1048576 >> 8 },
	{ "unsigned shift right",   (int32_t)(((uint32_t)-1048576) >> 8) },
	{ "bitwise and",            0x0F0F0F0F & 0x00FFFF00 },
	{ "bitwise or",             0x0F0F0F0F | 0x00FFFF00 },
	{ "bitwise xor",            0x0F0F0F0F ^ 0x00FFFF00 },
	{ "bitwise not",            ~0x12345678 },
	{ "precedence",             2 + 3 * 4 - 6 / 2 },
	{ "comparison chain",       1 },
	{ "short-circuit",          1 },
	{ "if/else chain",          30 },
	{ "while accumulate",       5050 },
	{ "do-while",               10 },
	{ "nested loop",            2025 },
	{ "break/continue",         2550 },
	{ "switch",                 300 },
	{ "recursion fib(20)",      6765 },
	{ "static mutation",        4950 },
	{ "int min literal",        -2147483647 - 1 },
	{ "unary negate",           -42 },
	{ "increment semantics",    34 },
	{ "instance dispatch",      5 + 10 + 10 + 1 },
	{ "class field chain",      4321 },
	{ "pool free and reuse",    1000 + 200 + 33 + 22 },
	{ "pool exhaustion",        10 + 4 },
	{ "Int8 truncation",        (int8_t)200 },
	{ "UInt8 truncation",       (uint8_t)300 },
	{ "Int16 truncation",       (int16_t)40000 },
	{ "UInt16 truncation",      (uint16_t)70000 },
	{ "UInt32 shift",           (int32_t)(((uint32_t)-2) >> 1) },
	{ "vector fill and sum",    (1+2+3+4+5+6+7+8) + 8 },
	{ "fixed point",            15 * 100 + 1 },
	{ "enum state machine",     111112 },
	{ "enum payload",           42 },
	{ "simple enum switch",     2 },
	{ "enum abstract switch",   20 },
	{ "literals live in ROM",   1 + 2 + 4 },
	{ "ROM table read",         31415926 },
	{ "text length and char",   5 * 100 + 'H' },
	{ "integer formatting",     5 * 1000 + 420 },
	{ "virtual dispatch",       9 + 20 },
	{ "final class direct",     17 * 100 + 17 },
	{ "inherited field",        6 * 3 + 1 },
	{ "interface dispatch",     8 * 100 + 6 },
	{ "bounds guard",           2 * 10 + 8 },
	{ "bitwise precedence",     (4 | 6) & 3 },
	{ "compare precedence",     7 },
	{ "rom constant fold",      4 * 10 + 9 + 7 },
};

#define CONFORMANCE_COUNT (sizeof(conformance_expected) / sizeof(conformance_expected[0]))

static void suite_conformance(const char *rom, const char *sym)
{
	uint32_t probe_addr = 0;
	uint32_t count_addr = 0;
	uint32_t done_addr = 0;
	int f;
	int done = 0;
	uint32_t reported;
	size_t i;

	suite("conformance: phase 0 language subset");

	if (!boot(rom, sym))
		return;

	if (!sym_lookup("hx_probe", &probe_addr) ||
	    !sym_lookup("hx_probe_count", &count_addr) ||
	    !sym_lookup("hx_probe_done", &done_addr)) {
		check(0, "probe symbols found");
		return;
	}
	check(1, "probe symbols found (hx_probe at 0x%06X)", probe_addr);

	for (f = 0; f < 60 && !done; f++) {
		md_run_frame();
		done = (int)md_read_ram16(done_addr);
	}

	check(done, "conformance rom signalled completion");
	if (!done) {
		md_dump_context();
		return;
	}

	reported = md_read_ram16(count_addr);
	check(reported == CONFORMANCE_COUNT, "reported %u probes, expected %u",
	      reported, (unsigned)CONFORMANCE_COUNT);

	for (i = 0; i < CONFORMANCE_COUNT && i < reported; i++) {
		int32_t got = (int32_t)md_read_ram32(probe_addr + (uint32_t)i * 4);
		int32_t want = conformance_expected[i].expected;
		check(got == want, "%-24s got %-12d want %d",
		      conformance_expected[i].name, got, want);
	}

	dump_rom("conformance", "samples/conformance");
	dump_line("until hx_probe_done 2 1 60");
	dump_line("value hx_probe_count 0 2 %u", reported);
	for (i = 0; i < reported; i++)
		dump_line("value hx_probe %u 4 %d", (unsigned)i * 4,
		          (int32_t)md_read_ram32(probe_addr + (uint32_t)i * 4));
}

/*
 * A probe ROM: boot it, hold whatever buttons the test wants, run until it says it is done,
 * check what it reported, and write the same numbers out for hx68k-emu to be held to.
 */
static void suite_probe_rom(const char *label, const char *name, const char *dir, const char *rom,
                            const char *sym, const probe_t *expect, size_t count, uint16_t buttons)
{
	uint32_t probe_addr = 0;
	uint32_t done_addr = 0;
	int f;
	int done = 0;
	size_t i;

	suite(label);

	if (!boot(rom, sym))
		return;

	if (!sym_lookup("hx_probe", &probe_addr) || !sym_lookup("hx_probe_done", &done_addr)) {
		check(0, "probe symbols found");
		return;
	}

	md_buttons[0] = (uint8_t)buttons;

	for (f = 0; f < 60 && !done; f++) {
		md_run_frame();
		done = (int)md_read_ram16(done_addr);
	}

	check(done, "rom signalled completion");
	if (!done) {
		md_dump_context();
		return;
	}

	dump_rom(name, dir);
	dump_line("until hx_probe_done 2 1 60");
	dump_line("buttons 0 %u", buttons);

	for (i = 0; i < count; i++) {
		int32_t got = (int32_t)md_read_ram32(probe_addr + (uint32_t)i * 4);

		if (expect[i].expected != PROBE_ANY)
			check(got == expect[i].expected, "%-28s got %-8d want %d",
				expect[i].name, got, expect[i].expected);
		else
			check(1, "%-28s got %d", expect[i].name, got);

		dump_line("value hx_probe %u 4 %d", (unsigned)i * 4, got);
	}

	dump_line("cram 0 %d", md_cram[0]);
}

static const probe_t hardware_expected[] = {
	{ "colour 0 read back over the fifth write behind it", 0x0E80 | 0xF111 },
	{ "a word through VRAM",        0x1234 },
	{ "the pad reports start and right", 0x88 },
};

/* Built with -D md-pal, so its header names Europe alone and both emulators read the standard
 * off it the same way: the status register's bit 0 and bit 6 of the version register. */
static const probe_t pal_expected[] = {
	{ "the status register says PAL", 1 },
	{ "and so does the version register", 1 },
};

static const probe_t bare_expected[] = {
	/* a ROM whose link carries no SGDK symbol. The first two are the startup itself: a static
	   with an initial value proves sdk/boot/sega.s copied .data out of ROM into work RAM, and a
	   vector that was never written proves it cleared the rest. The others prove the VDP came up
	   from cold with no VDP_init anywhere */
	{ "an initialised static survived the boot", 0x1234 },
	{ "and the rest of RAM was cleared", 0 },
	{ "a colour set through the native palette", 0x0EEE },
	{ "a cell set through the native tilemap", 1 },
	{ "a pattern uploaded without DMA", 0x1111 },
	{ "the plane is 64 cells wide", 64 },
	{ "and a vertical interrupt reached Haxe four times", 1 },
	/* the native maths, with no table behind any of it. fix16 carries six fractional bits, so
	   16 is 1024 and its root is 4, which is 256. log2 of 1000 is 9 taking the floor, the next
	   power of two above 1000 is 1024, and the approximated distance of 30 by 40 is the 50 it
	   should be */
	{ "a fixed point square root",  256 },
	{ "a floored log2",             9 },
	{ "the next power of two",      1024 },
	{ "an approximated distance",   50 },
	/* the sine table is generated by a macro at compile time rather than carried, and holds one
	   quarter turn at a degree a step scaled by 64. Sine of 90 is the whole 64, sine of 30 is
	   half of it, sine of 210 is that negated, and cosine of 0 is sine of 90 */
	{ "a generated sine at its peak", 64 },
	{ "a generated sine at thirty",  32 },
	{ "and past half a turn, negated", -32 },
	{ "a cosine is a quarter turn on", 64 },
	/* backup RAM, which the cartridge header declares at 0x200000 through 0x20FFFF on odd bytes.
	   md.Sram addresses it by offset, so offset n is the byte at 0x200001 + n * 2. The read only
	   mode has to refuse a write, and disabling it has to hand the addresses back to the
	   cartridge, which is past the end of a 128 KB ROM and reads as 0xFF */
	{ "a word written to backup RAM",   0x1234 },
	{ "and the word after it",          0xABCD },
	{ "a byte further in",              0x5A },
	{ "which read only mode would not let go", 0x5A },
	{ "the whole long, read back",      0x1234ABCD },
	{ "and with it disabled, the cartridge again", 0xFF },
};

static const probe_t art_expected[] = {
	/* bits 4 and 8 in each are not the colour: they are what the FIFO slot the next write will
	   use still holds, which a CRAM read exposes in the nine bits CRAM does not store. Which
	   bits those are depends on the last word written to the data port before the read, so the
	   value moves when the ROM's write order does. */
	{ "image palette colour 1",     0x000A | 0x0110 },
	{ "image palette colour 2",     0x0040 | 0x0110 },
	{ "image tilemap entry",        16 },
	{ "sprite list holds the sprite", 80 + 128 },
	{ "the tune is in ROM",         1 },
	{ "the tune converted to XGM",  0x248E },
	/* the binary resource. data/table.dat is 100 bytes of (i * 7) & 0xFF, declared with a size
	   alignment of 16 and a fill of 0xAA, so it occupies 112 bytes and the last twelve are the
	   fill. Every value below is computed from that rule rather than read back from what hxres
	   emitted. */
	{ "the table is word aligned",  0 },
	{ "its first byte",             (0 * 7) & 0xFF },
	{ "its fourth byte",            (3 * 7) & 0xFF },
	{ "its last real byte",         (99 * 7) & 0xFF },
	{ "the first byte of the fill", 0xAA },
	{ "and the last",               0xAA },
	/* the same 112 bytes again, compressed by hxres at build time and expanded on the 68000 by
	   md.Unpack. Both formats have to give the size back and reproduce the bytes exactly, so the
	   values are the ones above rather than anything the unpacker reported. */
	{ "aplib gives the size back",  112 },
	{ "aplib first byte",           (0 * 7) & 0xFF },
	{ "aplib fourth byte",          (3 * 7) & 0xFF },
	{ "aplib last real byte",       (99 * 7) & 0xFF },
	{ "aplib last byte of the fill", 0xAA },
	{ "lz4w gives the size back",   112 },
	{ "lz4w first byte",            (0 * 7) & 0xFF },
	{ "lz4w fourth byte",           (3 * 7) & 0xFF },
	{ "lz4w last real byte",        (99 * 7) & 0xFF },
	{ "lz4w last byte of the fill", 0xAA },
	/* data/crunch.dat, whose aplib parse takes all eleven of the unpacker's paths: literals,
	   both short match lengths, both four bit literal forms, a code pair that repeats the last
	   offset, and a code pair in each of the four offset bands the format's length correction
	   splits at 128, 1280 and 32000. Reaching past 32000 is what sets the file's size. */
	{ "every aplib path gives the size back", 33379 },
	{ "every aplib path reproduces the file", 0x7513 },
	{ "its odd trailing byte",      33 },
	{ "a word from the middle of it", 28017 },
	/* data/spread.dat, whose lz4w parse reaches all 256 entries of the unpacker's dispatch
	   table, every entry point of both literal chains, long matches from 17 words to the 257
	   the format allows, and the ending block that carries a trailing byte. The digest is a
	   rotate and xor over the file's own 5715 words, worked out from the file rather than from
	   anything the unpacker produced. */
	{ "the whole table gives the size back", 11431 },
	{ "the whole table reproduces the file", 0x7DA6 },
	{ "its odd trailing byte",      0x5A },
	{ "a word from the middle of it", 12705 },
	/* md.Font, with SGDK's own 8x8 font compiled by hxres as a tileset and loaded at pattern
	   600. "HX68K" is written on plane B at 1,20 in palette line 1, so a cell is
	   (1 << 13) | (600 + code - 32): H is 72 and lands on 8832, K is 75 and lands on 8835. The
	   cell past the end of the string is untouched, and a cleared cell holds the space glyph,
	   which is the font's first. The last is the crossbar of the H, read out of VRAM: row 3 of
	   that glyph is .######. which packs to 0x0FFF and 0xFFF0 at four bits a pixel. */
	{ "the first letter written",   (1 << 13) | 640 },
	{ "the last letter written",    (1 << 13) | 643 },
	{ "the cell past the end is untouched", 0 },
	{ "a cleared cell holds the space glyph", (1 << 13) | 600 },
	{ "the crossbar of the H, out of VRAM", 0x0FFF },
	/* the native tilemap, on plane B, which SGDK's boot leaves at 0xC000 as 64 by 32 cells.
	   Every value below is worked out from the cell format and the plane geometry rather than
	   read back from what md.Tilemap produced: a cell is
	   priority:1 palette:2 flipV:1 flipH:1 index:11, and a plane address is
	   base + (x + (y << 6)) * 2 */
	{ "a cell written by index",    400 },
	{ "a filled cell",              401 | (1 << 13) | 0x8000 | 0x1000 },
	{ "the last cell of an odd width fill", 401 | (1 << 13) | 0x8000 | 0x1000 },
	{ "an incrementing fill counts across rows", 300 + 4 + 2 },
	{ "the address of a plane B cell", 0xC000 + ((3 + (5 << 6)) * 2) },
	{ "the plane is 64 cells wide", 64 },
	{ "pattern 1 of the tileset landed", 0x1111 },
	{ "and so did pattern 15",      0xFFFF },
	/* the native sprite table, written after the engine's own transfer has landed, so the
	   first entry's y moves from the engine's 80 to 96. A VDP sprite entry is four words:
	   y + 0x80, then size in the high byte with the link in the low seven bits, then the
	   same attribute word a tilemap cell uses, then x + 0x80. Size is
	   ((width - 1) << 2) | (height - 1) */
	{ "the native table replaced the engine's first entry", 96 + 0x80 },
	{ "its size and the link chain put after it", (((2 - 1) << 2) | (2 - 1)) << 8 | 1 },
	{ "its attribute names pattern and palette", 403 | (1 << 13) },
	{ "and its x carries the same offset", 100 + 0x80 },
	{ "a second entry sized three by two",  (((3 - 1) << 2) | (2 - 1)) << 8 },
	{ "flipped, prioritised and on palette 2", 405 | (2 << 13) | 0x8000 | 0x0800 },
	/* the native DMA. A fill of eight bytes of 0x5A leaves the first word 0x5A5A, a transfer
	   of four words puts the first and last where they were asked for, a copy of four bytes
	   carries the fill's own bytes across, and the queue does the same transfer a frame
	   later than the immediate one would have */
	{ "a VRAM fill wrote its byte in both halves", 0x5A5A },
	{ "a transfer put its first word down", 0xA0A1 },
	{ "and its last",               0xA6A7 },
	{ "a VRAM copy carried the fill across", 0x5A5A },
	{ "and the queue ran the same transfer", 0xA0A1 },
	/* the native pad, with up, B and A held. A three-button pad reports its six lines with TH
	   high and swaps A and START in for left and right with TH low, so the eight bits come out
	   up, down, left, right, B, C, A, start. The two middle lines being pulled low while TH is
	   low is the pad saying it is there, which is the only kind this can tell apart: neither
	   emulator counts the TH pulses a six-button pad answers */
	{ "the first update sees the buttons arrive", 0x51 },
	{ "the second still has them held", 0x51 },
	{ "but does not report them as pressed again", 0 },
	{ "the port has a pad in it",   0x0D },
	{ "and it is a three-button one", 0x00 },
};

static const probe_t events_expected[] = {	{ "three handlers dispatched",  10 - 5 + 105 },
	{ "three handlers registered",  3 },
	{ "the interrupt handler ran",  1 },
	{ "vertical interrupts seen",   PROBE_ANY },
	{ "a function passed and called", 42 },
};

static const probe_t sdk_expected[] = {	{ "md.Vdp.setBackgroundColour", 2 },
	{ "md.Palette.colour reads back", 0x0246 },
	{ "md.Tilemap.setCell landed",  0x0021 },
	{ "md.Tilemap.fill landed",     0x0055 },
	{ "md.Dma.transferFrom landed", 0xA4A5 },
	{ "md.Joy.read agrees with the port", 0x88 },
	{ "md.Joy.portType is a pad",   0x0D },
	{ "md.Joy.padType is three-button", 0x00 },
	{ "md.System.isNtsc",           1 },
	{ "md.Maths.sqrt of 16",        4 << 6 },
};
static int file_exists(const char *p)
{
	FILE *f = fopen(p, "rb");
	if (!f)
		return 0;
	fclose(f);
	return 1;
}

int main(int argc, char **argv)
{
	const char *root = argc > 1 ? argv[1] : "..";
	char rom[512], sym[512];
	int i;

	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--trace") == 0)
			md_trace = 1;
	}

	snprintf(rom, sizeof(rom), "%s/tests/.observables.txt", root);
	g_dump = fopen(rom, "w");

	snprintf(rom, sizeof(rom), "%s/samples/spike/rom/out/release/rom.bin", root);
	snprintf(sym, sizeof(sym), "%s/samples/spike/rom/out/release/symbol.txt", root);
	suite_spike(rom, sym);

	snprintf(rom, sizeof(rom), "%s/samples/conformance/rom/out/release/rom.bin", root);
	snprintf(sym, sizeof(sym), "%s/samples/conformance/rom/out/release/symbol.txt", root);
	if (file_exists(rom))
		suite_conformance(rom, sym);
	else
		printf("\nconformance: skipped (rom not built)\n");

	snprintf(rom, sizeof(rom), "%s/samples/hardware/rom/out/release/rom.bin", root);
	snprintf(sym, sizeof(sym), "%s/samples/hardware/rom/out/release/symbol.txt", root);
	if (file_exists(rom)) {
		suite_probe_rom("hardware: md.hw with no SGDK call in it", "hardware", "samples/hardware",
			rom, sym, hardware_expected, COUNT(hardware_expected), 0x88);
		check(md_cram[0] == 0x0E80, "colour 0 landed in CRAM (got 0x%04X)", md_cram[0]);
	} else {
		printf("\nhardware: skipped (rom not built)\n");
	}

	snprintf(rom, sizeof(rom), "%s/samples/pal/rom/out/release/rom.bin", root);
	snprintf(sym, sizeof(sym), "%s/samples/pal/rom/out/release/symbol.txt", root);
	if (file_exists(rom))
		suite_probe_rom("pal: a cartridge built for the 50 Hz machine", "pal", "samples/pal",
			rom, sym, pal_expected, COUNT(pal_expected), 0);
	else
		printf("\npal: skipped (rom not built)\n");

	snprintf(rom, sizeof(rom), "%s/samples/art/rom/out/release/rom.bin", root);
	snprintf(sym, sizeof(sym), "%s/samples/art/rom/out/release/symbol.txt", root);
	if (file_exists(rom))
		suite_probe_rom("art: every resource through hxres, with no rescomp", "art", "samples/art",
			rom, sym, art_expected, COUNT(art_expected), 0x51);
	else
		printf("\nart: skipped (rom not built)\n");

	snprintf(rom, sizeof(rom), "%s/samples/bare/rom/out/release/rom.bin", root);
	snprintf(sym, sizeof(sym), "%s/samples/bare/rom/out/release/symbol.txt", root);
	if (file_exists(rom))
		suite_probe_rom("bare: a ROM that boots without SGDK", "bare", "samples/bare",
			rom, sym, bare_expected, COUNT(bare_expected), 0);
	else
		printf("\nbare: skipped (rom not built)\n");

	snprintf(rom, sizeof(rom), "%s/samples/events/rom/out/release/rom.bin", root);
	snprintf(sym, sizeof(sym), "%s/samples/events/rom/out/release/symbol.txt", root);
	if (file_exists(rom))
		suite_probe_rom("events: function references and callbacks", "events", "samples/events",
			rom, sym, events_expected, COUNT(events_expected), 0);
	else
		printf("\nevents: skipped (rom not built)\n");

	snprintf(rom, sizeof(rom), "%s/samples/sdk/rom/out/release/rom.bin", root);
	snprintf(sym, sizeof(sym), "%s/samples/sdk/rom/out/release/symbol.txt", root);
	if (file_exists(rom))
		suite_probe_rom("sdk: the native SDK, end to end", "sdk", "samples/sdk",
			rom, sym, sdk_expected, COUNT(sdk_expected), 0x88);
	else
		printf("\nsdk: skipped (rom not built)\n");

	if (g_dump)
		fclose(g_dump);

	printf("\n%d checks, %d failures\n", g_checks, g_fails);
	return g_fails ? 1 : 0;
}

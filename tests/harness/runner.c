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
 * What the oracle saw, written out so hx68k-emu can be held to the same numbers
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

	check(text_ok, "drawText tilemap matches the string's repeat pattern (%s)",
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
	{ "colour 0 read back over the last VRAM write", 0x1E90 },
	{ "a word through VRAM",        0x1234 },
	{ "the pad reports start and right", 0x88 },
};

static const probe_t art_expected[] = {
	{ "image palette colour 1",     0x000A },
	{ "image palette colour 2",     0x0040 },
	{ "image tilemap entry",        16 },
	{ "sprite list holds the sprite", 80 + 128 },
	{ "the tune is in ROM",         1 },
	{ "the tune converted to XGM",  0x248E },
};

static const probe_t events_expected[] = {	{ "three handlers dispatched",  10 - 5 + 105 },
	{ "three handlers registered",  3 },
	{ "the interrupt handler ran",  1 },
	{ "vertical interrupts seen",   PROBE_ANY },
	{ "a function passed and called", 42 },
};

static const probe_t sdk_expected[] = {	{ "VDP_setBackgroundColor",     2 },
	{ "PAL_setColor reads back",    0x0246 },
	{ "VDP_setTileMapXY landed",    0x0021 },
	{ "VDP_fillTileMapRect landed", 0x0055 },
	{ "DMA_transfer landed",        0xA4A5 },
	{ "JOY_readJoypad agrees with the port", 0x88 },
	{ "JOY_getPortType is a pad",   0x0D },
	{ "JOY_getJoypadType is three-button", 0x00 },
	{ "SYS_isNTSC",                 1 },
	{ "F16_sqrt of 16",             4 << 6 },
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

	snprintf(rom, sizeof(rom), "%s/samples/art/rom/out/release/rom.bin", root);
	snprintf(sym, sizeof(sym), "%s/samples/art/rom/out/release/symbol.txt", root);
	if (file_exists(rom))
		suite_probe_rom("art: resources through hxres and rescomp", "art", "samples/art",
			rom, sym, art_expected, COUNT(art_expected), 0);
	else
		printf("\nart: skipped (rom not built)\n");

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
		suite_probe_rom("sdk: SGDK through the bindings", "sdk", "samples/sdk",
			rom, sym, sdk_expected, COUNT(sdk_expected), 0x88);
	else
		printf("\nsdk: skipped (rom not built)\n");

	if (g_dump)
		fclose(g_dump);

	printf("\n%d checks, %d failures\n", g_checks, g_fails);
	return g_fails ? 1 : 0;
}

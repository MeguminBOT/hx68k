#include <genesis.h>

#include "native.h"

/*
 * The reference implementation: the same two workloads a C programmer would write
 * for SGDK, at the widths they would write them at. The probe channel is the same
 * one the conformance sample uses, plus a marker the emulator can watch the CPU
 * enter, which is what bounds each measurement.
 */

#define CELLS    256
#define ENTITIES 64

typedef struct native_entity {
	s16                   value;
	s16                   rate;
	struct native_entity *next;
} native_entity;

volatile s32 hx_probe[16];
volatile u16 hx_probe_count = 0;
volatile u16 hx_probe_done = 0;
volatile u16 hx_mark_count = 0;

static volatile s32 hx_seed_value = 1;

static s16            native_cells[CELLS];
static s32            native_wide_cells[CELLS];
static native_entity  native_pool[ENTITIES];
static native_entity *native_head;

s32 hx_seed(void)
{
	return hx_seed_value;
}

void hx_report(s32 value)
{
	if (hx_probe_count < 16)
		hx_probe[hx_probe_count++] = value;
}

void hx_done(void)
{
	hx_probe_done = 1;
}

/* noinline keeps a real jsr here, so the marker has an address to be entered at */
__attribute__((noinline)) void hx_mark(void)
{
	hx_mark_count++;
}

void native_fill(void)
{
	s16 i;

	for (i = 0; i < CELLS; i++) {
		native_cells[i] = (s16)((i * 7 + 13) & 0x3FF);
		native_wide_cells[i] = (i * 7 + 13) & 0x3FF;
	}
}

void native_build(void)
{
	s16 i;

	native_head = &native_pool[0];

	for (i = 0; i < ENTITIES; i++) {
		native_pool[i].value = (s16)(i * 3 + 1);
		native_pool[i].rate  = (s16)(i + 2);
		native_pool[i].next  = (i + 1 < ENTITIES) ? &native_pool[i + 1] : NULL;
	}
}

s32 native_array_pass(s16 seed)
{
	s32 total = 0;
	s16 i;

	for (i = 0; i < CELLS; i++) {
		s16 value = native_cells[i];

		value = (s16)(value + i - seed);
		if (value > 1000)
			value = (s16)(value - 1000);

		native_cells[i] = value;
		total += value;
	}

	return total;
}

s32 native_wide_pass(s32 seed)
{
	s32 total = 0;
	s32 i;

	for (i = 0; i < CELLS; i++) {
		s32 value = native_wide_cells[i];

		value = value + i - seed;
		if (value > 1000)
			value = value - 1000;

		native_wide_cells[i] = value;
		total += value;
	}

	return total;
}

s32 native_object_pass(s16 seed)
{
	native_entity *entity = native_head;
	s32 total = 0;

	while (entity != NULL) {
		s16 next = (s16)(entity->value + entity->rate * seed);

		if (next > 4000)
			next = (s16)(next - 4000);

		entity->value = next;
		total += entity->value;
		entity = entity->next;
	}

	return total;
}

u32 native_aplib_unpack(u32 from, u32 into)
{
	return aplib_unpack((u8 *)from, (u8 *)into);
}

u32 native_lz4w_unpack(u32 from, u32 into)
{
	return lz4w_unpack((const u8 *)from, (u8 *)into);
}

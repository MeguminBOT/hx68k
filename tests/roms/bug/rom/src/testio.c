#include "hx.h"

/*
 * Probe channel for the headless harness, which reads these symbols straight out
 * of emulated RAM. hx_seed is volatile so the optimizer cannot constant-fold the
 * loop and recursion tests away.
 */

volatile s32 hx_probe[64];
volatile u16 hx_probe_count = 0;
volatile u16 hx_probe_done = 0;

static volatile s32 hx_seed_value = 1;

s32 hx_seed(void)
{
	return hx_seed_value;
}

void hx_report(s32 value)
{
	if (hx_probe_count < 64)
		hx_probe[hx_probe_count++] = value;
}

void hx_done(void)
{
	hx_probe_done = 1;
}

#ifndef TESTIO_H
#define TESTIO_H

#include <genesis.h>

extern volatile s32 hx_probe[64];
extern volatile u16 hx_probe_count;
extern volatile u16 hx_probe_done;

s32  hx_seed(void);
void hx_report(s32 value);
void hx_done(void);

#endif

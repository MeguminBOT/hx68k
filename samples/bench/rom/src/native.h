#ifndef NATIVE_H
#define NATIVE_H

#include <genesis.h>

extern volatile s32 hx_probe[16];
extern volatile u16 hx_probe_count;
extern volatile u16 hx_probe_done;
extern volatile u16 hx_mark_count;

s32  hx_seed(void);
void hx_report(s32 value);
void hx_done(void);
void hx_mark(void);

void native_fill(void);
void native_build(void);
s32  native_array_pass(s16 seed);
s32  native_wide_pass(s32 seed);
s32  native_object_pass(s16 seed);

#endif

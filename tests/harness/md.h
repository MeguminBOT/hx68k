#ifndef MD_H
#define MD_H

#include <stdint.h>
#include <stddef.h>

#define MD_RAM_SIZE   0x10000
#define MD_VRAM_SIZE  0x10000
#define MD_CRAM_SIZE  64
#define MD_VSRAM_SIZE 40
#define MD_Z80_SIZE   0x2000

#define MD_LINES_PER_FRAME 262
#define MD_CYCLES_PER_LINE 488
#define MD_VBLANK_LINE     224

enum {
	MD_W_VRAM = 0,
	MD_W_CRAM,
	MD_W_VSRAM,
	MD_W_REG
};

typedef struct {
	uint8_t  kind;
	uint16_t addr;
	uint16_t value;
	uint32_t frame;
} md_write_t;

#define MD_LOG_MAX 65536

extern uint8_t  md_rom[0x400000];
extern size_t   md_rom_size;
extern int      md_pal;
extern uint8_t  md_ram[MD_RAM_SIZE];
extern uint8_t  md_vram[MD_VRAM_SIZE];
extern uint16_t md_cram[MD_CRAM_SIZE];
extern uint16_t md_vsram[MD_VSRAM_SIZE];
extern uint8_t  md_vdp_reg[32];
extern uint8_t  md_buttons[3];

extern md_write_t md_log[MD_LOG_MAX];
extern size_t     md_log_count;

extern uint32_t md_frame;
extern uint32_t md_line;

extern int      md_trace;
extern uint32_t md_pc_ring[256];
extern size_t   md_pc_ring_pos;

int  md_load_rom(const char *path);
void md_reset(void);
void md_run_frame(void);

uint32_t md_read_ram8(uint32_t addr);
uint32_t md_read_ram16(uint32_t addr);
uint32_t md_read_ram32(uint32_t addr);

uint32_t md_plane_a_base(void);
uint32_t md_plane_width(void);
uint16_t md_plane_a_entry(uint32_t col, uint32_t row);

int md_pc_was_hit(uint32_t addr);
void md_watch_pc(uint32_t addr);
void md_dump_context(void);

int  sym_load(const char *path);
int  sym_lookup(const char *name, uint32_t *out);
const char *sym_nearest(uint32_t addr, uint32_t *offset);

#endif

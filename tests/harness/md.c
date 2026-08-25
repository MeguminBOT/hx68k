#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "md.h"
#include "m68k.h"

uint8_t  md_rom[0x400000];
size_t   md_rom_size;
uint8_t  md_ram[MD_RAM_SIZE];
uint8_t  md_vram[MD_VRAM_SIZE];
uint16_t md_cram[MD_CRAM_SIZE];
uint16_t md_vsram[MD_VSRAM_SIZE];
uint8_t  md_vdp_reg[32];
uint8_t  md_buttons[3];

md_write_t md_log[MD_LOG_MAX];
size_t     md_log_count;

uint32_t md_frame;
uint32_t md_line;

int      md_trace;
uint32_t md_pc_ring[256];
size_t   md_pc_ring_pos;

static uint8_t  z80_ram[MD_Z80_SIZE];
static uint8_t  pad_control[3];
static uint8_t  pad_data[3];
static int      z80_busreq;
static int      in_vblank;
static int      vint_pending;
static int      hint_counter;

static uint32_t ctrl_addr;
static uint32_t ctrl_code;
static int      ctrl_pending;
static int      dma_fill_pending;

static uint32_t watch_pc[16];
static int      watch_pc_count;
static int      watch_pc_hit[16];

static void log_write(uint8_t kind, uint16_t addr, uint16_t value)
{
	if (md_log_count < MD_LOG_MAX) {
		md_log[md_log_count].kind  = kind;
		md_log[md_log_count].addr  = addr;
		md_log[md_log_count].value = value;
		md_log[md_log_count].frame = md_frame;
		md_log_count++;
	}
}

static void vram_write_word(uint32_t a, uint16_t v)
{
	a &= 0xFFFE;
	md_vram[a]     = (uint8_t)(v >> 8);
	md_vram[a | 1] = (uint8_t)(v & 0xFF);
}

static uint16_t vdp_latch;

static uint16_t vram_read_word(uint32_t a)
{
	a &= 0xFFFE;
	return (uint16_t)((md_vram[a] << 8) | md_vram[a | 1]);
}

static void vdp_store(uint16_t value)
{
	uint32_t a = ctrl_addr;

	switch (ctrl_code & 0x0F) {
	case 0x01:
		vdp_latch = value;
		vram_write_word(a, value);
		log_write(MD_W_VRAM, (uint16_t)(a & 0xFFFF), value);
		break;
	case 0x03:
		md_cram[(a >> 1) & (MD_CRAM_SIZE - 1)] = value & 0x0EEE;
		log_write(MD_W_CRAM, (uint16_t)(a & 0x7F), value);
		break;
	case 0x05:
		md_vsram[(a >> 1) % MD_VSRAM_SIZE] = value & 0x07FF;
		log_write(MD_W_VSRAM, (uint16_t)(a & 0x7F), value);
		break;
	default:
		break;
	}

	ctrl_addr = (ctrl_addr + md_vdp_reg[15]) & 0xFFFF;
}

static uint16_t vdp_fetch(void)
{
	uint16_t v = 0;

	switch (ctrl_code & 0x0F) {
	case 0x00: v = vram_read_word(ctrl_addr); break;
	case 0x08:
		v = (uint16_t)((md_cram[(ctrl_addr >> 1) & (MD_CRAM_SIZE - 1)] & 0x0EEE)
			| (vdp_latch & 0xF111));
		break;
	case 0x04:
		v = (uint16_t)((md_vsram[(ctrl_addr >> 1) % MD_VSRAM_SIZE] & 0x07FF)
			| (vdp_latch & 0xF800));
		break;
	default: break;
	}

	ctrl_addr = (ctrl_addr + md_vdp_reg[15]) & 0xFFFF;
	return v;
}

static uint32_t read16_bus(uint32_t addr);

static void vdp_dma(void)
{
	uint32_t len  = (uint32_t)(md_vdp_reg[19] | (md_vdp_reg[20] << 8));
	uint32_t mode = (uint32_t)(md_vdp_reg[23] >> 6);
	uint32_t src;
	uint32_t i;

	if (len == 0)
		len = 0x10000;

	if (mode == 2) {
		dma_fill_pending = 1;
		return;
	}

	/* bit 6 of register 23 is part of the source address, and dropping it lands a
	   transfer from work RAM half a megabyte short of where it was meant to read */
	src = (uint32_t)(md_vdp_reg[21] | (md_vdp_reg[22] << 8) |
	                 ((md_vdp_reg[23] & 0x7F) << 16)) << 1;

	if (mode == 3) {
		for (i = 0; i < len; i++) {
			uint32_t s = (src + i) & 0xFFFF;
			uint32_t d = (ctrl_addr + i * md_vdp_reg[15]) & 0xFFFF;
			md_vram[d] = md_vram[s];
		}
		ctrl_addr = (ctrl_addr + len * md_vdp_reg[15]) & 0xFFFF;
	} else {
		for (i = 0; i < len; i++) {
			vdp_store((uint16_t)read16_bus(src));
			src += 2;
		}
	}

	md_vdp_reg[19] = 0;
	md_vdp_reg[20] = 0;
}

static void vdp_write_ctrl(uint16_t value)
{
	if (!ctrl_pending && (value & 0xC000) == 0x8000) {
		uint8_t reg = (uint8_t)((value >> 8) & 0x1F);
		md_vdp_reg[reg] = (uint8_t)(value & 0xFF);
		log_write(MD_W_REG, reg, (uint16_t)(value & 0xFF));
		return;
	}

	if (!ctrl_pending) {
		ctrl_addr = (ctrl_addr & 0xC000) | (value & 0x3FFF);
		ctrl_code = (ctrl_code & 0x3C) | ((value >> 14) & 0x03);
		ctrl_pending = 1;
	} else {
		ctrl_addr = (ctrl_addr & 0x3FFF) | ((value & 0x03) << 14);
		ctrl_code = (ctrl_code & 0x03) | ((value >> 2) & 0x3C);
		ctrl_pending = 0;
		if (ctrl_code & 0x20)
			vdp_dma();
	}
}

static void vdp_write_data(uint16_t value)
{
	ctrl_pending = 0;

	if (dma_fill_pending) {
		uint32_t len = (uint32_t)(md_vdp_reg[19] | (md_vdp_reg[20] << 8));
		uint8_t fill = (uint8_t)(value >> 8);
		uint32_t i;

		dma_fill_pending = 0;
		if (len == 0)
			len = 0x10000;

		vdp_store(value);
		for (i = 1; i < len; i++) {
			md_vram[(ctrl_addr ^ 1) & 0xFFFF] = fill;
			ctrl_addr = (ctrl_addr + md_vdp_reg[15]) & 0xFFFF;
		}

		md_vdp_reg[19] = 0;
		md_vdp_reg[20] = 0;
		return;
	}

	vdp_store(value);
}

static uint16_t vdp_read_status(void)
{
	uint16_t s = 0x3400 | 0x0200; /* unused bits + FIFO empty */

	ctrl_pending = 0;

	if (in_vblank)
		s |= 0x0008;
	if (md_line >= MD_VBLANK_LINE)
		s |= 0x0004;
	if (vint_pending)
		s |= 0x0080;

	return s;
}

static uint16_t vdp_read_hv(void)
{
	uint32_t v = md_line & 0xFF;
	return (uint16_t)((v << 8) | 0x00);
}

/*
 * A three-button pad. TH high puts the directions with B and C on the port, TH low puts
 * up, down, A and start on it with the two middle bits low, which is how the pad names
 * itself. Every line is active low, and a line the port drives reads back what was
 * written to it.
 */
static uint32_t pad_read(int port)
{
	uint8_t control = pad_control[port];
	/* TH is only driven when the port owns it; left as an input it sits high on its pull-up */
	int     high    = (control & 0x40) ? (pad_data[port] & 0x40) != 0 : 1;
	/* TH low leaves the two middle bits low whatever is held, which is the pad's own name */
	uint8_t released = (uint8_t)~md_buttons[port];
	uint8_t lines    = high ? (uint8_t)(released & 0x3F)
	                        : (uint8_t)((released & 0x03) | (((released >> 6) & 0x03) << 4));

	return (uint32_t)((((lines | 0x40) & (uint8_t)~control)
	                  | (pad_data[port] & control)) & 0x7F);
}

static uint32_t io_read(uint32_t addr)
{
	uint32_t offset = addr & 0x1F;

	if (offset <= 0x01)
		return 0xA0; /* overseas, NTSC, no expansion */
	if (offset >= 0x02 && offset <= 0x07)
		return pad_read((int)((offset >> 1) - 1));
	if (offset >= 0x08 && offset <= 0x0D)
		return pad_control[(offset >> 1) - 4];

	return 0x00;
}

static void io_write(uint32_t addr, uint32_t value)
{
	uint32_t offset = addr & 0x1F;

	if (offset >= 0x02 && offset <= 0x07)
		pad_data[(offset >> 1) - 1] = (uint8_t)value;
	else if (offset >= 0x08 && offset <= 0x0D)
		pad_control[(offset >> 1) - 4] = (uint8_t)value;
}

static uint32_t read8_bus(uint32_t addr)
{
	addr &= 0xFFFFFF;

	if (addr < 0x400000)
		return addr < md_rom_size ? md_rom[addr] : 0xFF;

	if (addr >= 0xE00000)
		return md_ram[addr & (MD_RAM_SIZE - 1)];

	if (addr >= 0xA00000 && addr < 0xA02000)
		return z80_ram[addr & (MD_Z80_SIZE - 1)];

	if (addr >= 0xA04000 && addr < 0xA04004)
		return 0x00; /* YM2612 not busy */

	if (addr >= 0xA10000 && addr < 0xA10020)
		return io_read(addr);

	/* bit 8 set means the Z80 still owns the bus; cleared means the 68k has it */
	if (addr >= 0xA11100 && addr < 0xA11102)
		return z80_busreq ? 0x00 : 0x01;

	if (addr >= 0xC00000 && addr < 0xC00020) {
		uint32_t port = addr & 0x1F;
		if (port < 0x04)
			return (uint32_t)(vdp_fetch() >> ((addr & 1) ? 0 : 8)) & 0xFF;
		if (port < 0x08)
			return (uint32_t)(vdp_read_status() >> ((addr & 1) ? 0 : 8)) & 0xFF;
		if (port < 0x10)
			return (uint32_t)(vdp_read_hv() >> ((addr & 1) ? 0 : 8)) & 0xFF;
		return 0x00;
	}

	return 0xFF;
}

static uint32_t read16_bus(uint32_t addr)
{
	addr &= 0xFFFFFE;

	if (addr < 0x400000) {
		if (addr + 1 < md_rom_size)
			return (uint32_t)((md_rom[addr] << 8) | md_rom[addr + 1]);
		return 0xFFFF;
	}

	if (addr >= 0xE00000) {
		uint32_t a = addr & (MD_RAM_SIZE - 1);
		return (uint32_t)((md_ram[a] << 8) | md_ram[(a + 1) & (MD_RAM_SIZE - 1)]);
	}

	if (addr >= 0xA11100 && addr < 0xA11102)
		return z80_busreq ? 0x0000 : 0x0100;

	if (addr >= 0xC00000 && addr < 0xC00020) {
		uint32_t port = addr & 0x1F;
		if (port < 0x04)
			return vdp_fetch();
		if (port < 0x08)
			return vdp_read_status();
		if (port < 0x10)
			return vdp_read_hv();
		return 0x0000;
	}

	return (read8_bus(addr) << 8) | read8_bus(addr + 1);
}

static void write8_bus(uint32_t addr, uint32_t value)
{
	addr  &= 0xFFFFFF;
	value &= 0xFF;

	if (addr >= 0xE00000) {
		md_ram[addr & (MD_RAM_SIZE - 1)] = (uint8_t)value;
		return;
	}

	if (addr >= 0xA00000 && addr < 0xA02000) {
		z80_ram[addr & (MD_Z80_SIZE - 1)] = (uint8_t)value;
		return;
	}

	if (addr >= 0xA11100 && addr < 0xA11102) {
		z80_busreq = (value & 0x01) ? 1 : 0;
		return;
	}

	if (addr >= 0xA10000 && addr < 0xA10020) {
		io_write(addr, value);
		return;
	}

	if (addr >= 0xC00000 && addr < 0xC00020) {
		uint32_t port = addr & 0x1F;
		if (port < 0x04)
			vdp_write_data((uint16_t)((value << 8) | value));
		else if (port < 0x08)
			vdp_write_ctrl((uint16_t)((value << 8) | value));
		return;
	}
}

static void write16_bus(uint32_t addr, uint32_t value)
{
	addr  &= 0xFFFFFE;
	value &= 0xFFFF;

	if (addr >= 0xE00000) {
		uint32_t a = addr & (MD_RAM_SIZE - 1);
		md_ram[a]                             = (uint8_t)(value >> 8);
		md_ram[(a + 1) & (MD_RAM_SIZE - 1)]   = (uint8_t)(value & 0xFF);
		return;
	}

	if (addr >= 0xA11100 && addr < 0xA11102) {
		z80_busreq = (value & 0x0100) ? 1 : 0;
		return;
	}

	if (addr >= 0xC00000 && addr < 0xC00020) {
		uint32_t port = addr & 0x1F;
		if (port < 0x04)
			vdp_write_data((uint16_t)value);
		else if (port < 0x08)
			vdp_write_ctrl((uint16_t)value);
		return;
	}

	write8_bus(addr, value >> 8);
	write8_bus(addr + 1, value & 0xFF);
}

unsigned int m68k_read_memory_8(unsigned int address)  { return read8_bus(address); }
unsigned int m68k_read_memory_16(unsigned int address) { return read16_bus(address); }

unsigned int m68k_read_memory_32(unsigned int address)
{
	return (read16_bus(address) << 16) | read16_bus(address + 2);
}

unsigned int m68k_read_immediate_16(unsigned int address) { return read16_bus(address); }
unsigned int m68k_read_immediate_32(unsigned int address) { return m68k_read_memory_32(address); }
unsigned int m68k_read_pcrelative_8(unsigned int address)  { return read8_bus(address); }
unsigned int m68k_read_pcrelative_16(unsigned int address) { return read16_bus(address); }
unsigned int m68k_read_pcrelative_32(unsigned int address) { return m68k_read_memory_32(address); }

unsigned int m68k_read_disassembler_8(unsigned int address)  { return read8_bus(address); }
unsigned int m68k_read_disassembler_16(unsigned int address) { return read16_bus(address); }
unsigned int m68k_read_disassembler_32(unsigned int address) { return m68k_read_memory_32(address); }

void m68k_write_memory_8(unsigned int address, unsigned int value)  { write8_bus(address, value); }
void m68k_write_memory_16(unsigned int address, unsigned int value) { write16_bus(address, value); }

void m68k_write_memory_32(unsigned int address, unsigned int value)
{
	write16_bus(address, value >> 16);
	write16_bus(address + 2, value & 0xFFFF);
}

static void instr_hook(unsigned int pc)
{
	int i;

	md_pc_ring[md_pc_ring_pos & 255] = pc;
	md_pc_ring_pos++;

	for (i = 0; i < watch_pc_count; i++) {
		if (watch_pc[i] == pc)
			watch_pc_hit[i] = 1;
	}

	if (md_trace) {
		char buf[256];
		m68k_disassemble(buf, pc, M68K_CPU_TYPE_68000);
		printf("    %06X  %s\n", pc, buf);
	}
}

int md_load_rom(const char *path)
{
	FILE *f = fopen(path, "rb");
	size_t n;

	if (!f)
		return 0;

	memset(md_rom, 0xFF, sizeof(md_rom));
	n = fread(md_rom, 1, sizeof(md_rom), f);
	fclose(f);

	md_rom_size = n;
	return n > 0x200;
}

void md_reset(void)
{
	memset(md_ram, 0, sizeof(md_ram));
	memset(md_vram, 0, sizeof(md_vram));
	memset(md_cram, 0, sizeof(md_cram));
	memset(md_vsram, 0, sizeof(md_vsram));
	memset(md_vdp_reg, 0, sizeof(md_vdp_reg));
	vdp_latch = 0;
	memset(z80_ram, 0, sizeof(z80_ram));
	memset(pad_control, 0, sizeof(pad_control));
	memset(pad_data, 0, sizeof(pad_data));

	md_log_count = 0;
	md_frame = 0;
	md_line = 0;
	md_pc_ring_pos = 0;

	z80_busreq = 0;
	in_vblank = 0;
	vint_pending = 0;
	hint_counter = 0;
	ctrl_addr = 0;
	ctrl_code = 0;
	ctrl_pending = 0;
	dma_fill_pending = 0;

	md_vdp_reg[15] = 2;

	m68k_init();
	m68k_set_cpu_type(M68K_CPU_TYPE_68000);
	m68k_set_instr_hook_callback(instr_hook);
	m68k_pulse_reset();
}

void md_run_frame(void)
{
	uint32_t line;

	for (line = 0; line < MD_LINES_PER_FRAME; line++) {
		md_line = line;
		in_vblank = (line >= MD_VBLANK_LINE);

		if (line <= MD_VBLANK_LINE) {
			if (hint_counter <= 0) {
				hint_counter = md_vdp_reg[10];
				if (md_vdp_reg[0] & 0x10)
					m68k_set_irq(4);
			} else {
				hint_counter--;
			}
		} else {
			hint_counter = md_vdp_reg[10];
		}

		if (line == MD_VBLANK_LINE) {
			vint_pending = 1;
			if (md_vdp_reg[1] & 0x20)
				m68k_set_irq(6);
		}

		m68k_execute(MD_CYCLES_PER_LINE);

		if (line == MD_VBLANK_LINE) {
			m68k_set_irq(0);
			vint_pending = 0;
		}
	}

	md_frame++;
}

uint32_t md_read_ram8(uint32_t addr)
{
	return md_ram[addr & (MD_RAM_SIZE - 1)];
}

uint32_t md_read_ram16(uint32_t addr)
{
	uint32_t a = addr & (MD_RAM_SIZE - 1);
	return (uint32_t)((md_ram[a] << 8) | md_ram[(a + 1) & (MD_RAM_SIZE - 1)]);
}

uint32_t md_read_ram32(uint32_t addr)
{
	return (md_read_ram16(addr) << 16) | md_read_ram16(addr + 2);
}

uint32_t md_plane_a_base(void)
{
	return (uint32_t)(md_vdp_reg[2] & 0x38) << 10;
}

uint32_t md_plane_width(void)
{
	switch (md_vdp_reg[16] & 0x03) {
	case 0:  return 32;
	case 1:  return 64;
	default: return 128;
	}
}

uint16_t md_plane_a_entry(uint32_t col, uint32_t row)
{
	uint32_t w = md_plane_width();
	uint32_t a = md_plane_a_base() + ((row * w) + col) * 2;
	return vram_read_word(a & 0xFFFF);
}

void md_watch_pc(uint32_t addr)
{
	if (watch_pc_count < 16) {
		watch_pc[watch_pc_count] = addr & 0xFFFFFF;
		watch_pc_hit[watch_pc_count] = 0;
		watch_pc_count++;
	}
}

int md_pc_was_hit(uint32_t addr)
{
	int i;
	for (i = 0; i < watch_pc_count; i++) {
		if (watch_pc[i] == (addr & 0xFFFFFF))
			return watch_pc_hit[i];
	}
	return 0;
}

void md_dump_context(void)
{
	uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
	uint32_t off = 0;
	const char *name = sym_nearest(pc, &off);
	size_t i;
	size_t n = md_pc_ring_pos < 16 ? md_pc_ring_pos : 16;

	printf("    pc=%06X", pc);
	if (name)
		printf(" (%s+0x%X)", name, off);
	printf("  frame=%u line=%u\n", md_frame, md_line);

	printf("    recent pc:");
	for (i = n; i > 0; i--)
		printf(" %06X", md_pc_ring[(md_pc_ring_pos - i) & 255]);
	printf("\n");
}

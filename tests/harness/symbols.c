#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "md.h"

#define SYM_MAX 8192

typedef struct {
	uint32_t addr;
	char     name[80];
} sym_t;

static sym_t syms[SYM_MAX];
static int   sym_count;

static int sym_cmp(const void *a, const void *b)
{
	const sym_t *x = (const sym_t *)a;
	const sym_t *y = (const sym_t *)b;
	if (x->addr < y->addr) return -1;
	if (x->addr > y->addr) return 1;
	return 0;
}

int sym_load(const char *path)
{
	FILE *f = fopen(path, "r");
	char line[512];

	if (!f)
		return 0;

	sym_count = 0;

	while (fgets(line, sizeof(line), f)) {
		unsigned long addr;
		char type;
		char name[80];

		if (sscanf(line, "%lx %c %79s", &addr, &type, name) != 3)
			continue;
		if (sym_count >= SYM_MAX)
			break;

		syms[sym_count].addr = (uint32_t)(addr & 0xFFFFFF);
		strncpy(syms[sym_count].name, name, sizeof(syms[sym_count].name) - 1);
		syms[sym_count].name[sizeof(syms[sym_count].name) - 1] = '\0';
		sym_count++;
	}

	fclose(f);
	qsort(syms, (size_t)sym_count, sizeof(sym_t), sym_cmp);
	return sym_count > 0;
}

int sym_lookup(const char *name, uint32_t *out)
{
	int i;
	for (i = 0; i < sym_count; i++) {
		if (strcmp(syms[i].name, name) == 0) {
			*out = syms[i].addr;
			return 1;
		}
	}
	return 0;
}

const char *sym_nearest(uint32_t addr, uint32_t *offset)
{
	int i;
	const sym_t *best = NULL;

	addr &= 0xFFFFFF;

	for (i = 0; i < sym_count; i++) {
		if (syms[i].addr <= addr && (!best || syms[i].addr > best->addr))
			best = &syms[i];
	}

	if (!best)
		return NULL;

	if (offset)
		*offset = addr - best->addr;

	return best->name;
}

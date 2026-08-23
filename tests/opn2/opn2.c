/*
 * A reference the FM chip in hx68k is measured against, and nothing more.
 *
 * This is a separate program. Nuked OPN2 is LGPL and hx68k is not, so its code is never linked
 * into the emulator: it is built here, run here, and only the samples it produces cross over. That
 * is the same arrangement the Musashi harness has with the 68000 core.
 *
 * A script is a list of writes, one a line:
 *
 *     <samples to run first> <port 0..3> <value>
 *
 * and what comes out is signed sixteen bit samples, two channels interleaved.
 *
 *     opn2 <samples>                 one script on standard input, samples on standard output
 *     opn2 <samples> <jobs>          many, where each line of <jobs> is "<script> <output>"
 *
 * The second form exists because the suite is hundreds of fixtures and starting a process for each
 * of them costs far more than rendering them does.
 *
 * One sample is twenty four clocks summed and divided by three. The part multiplexes its six
 * channels across those twenty four slots, each channel landing in three of them, so summing is
 * what the hardware does and the divide is what takes the multiplexer's gain back out.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif
#include "ym3438.h"

#define PER_SAMPLE 24

static void emit(ym3438_t *chip, FILE *out) {
	Bit16s buffer[2];
	long left = 0, right = 0;
	Bit16s pair[2];
	int i;

	for (i = 0; i < PER_SAMPLE; i++) {
		OPN2_Clock(chip, buffer);
		left += buffer[0];
		right += buffer[1];
	}

	/* a channel lands in three of the twenty four slots, so the sum carries a gain of three */
	left /= 3;
	right /= 3;

	if (left > 32767) left = 32767;
	if (left < -32768) left = -32768;
	if (right > 32767) right = 32767;
	if (right < -32768) right = -32768;

	pair[0] = (Bit16s)left;
	pair[1] = (Bit16s)right;
	fwrite(pair, sizeof(Bit16s), 2, out);
}

static void render(FILE *script, FILE *out, long total) {
	ym3438_t chip;
	long produced = 0;
	char line[256];

	OPN2_Reset(&chip);

	while (fgets(line, sizeof(line), script)) {
		long wait, i;
		unsigned port, value;
		if (sscanf(line, "%ld %u %u", &wait, &port, &value) != 3) continue;

		for (i = 0; i < wait && produced < total; i++) {
			emit(&chip, out);
			produced++;
		}

		OPN2_Write(&chip, port, (Bit8u)value);
	}

	while (produced < total) {
		emit(&chip, out);
		produced++;
	}
}

static int batch(const char *jobs, long total) {
	FILE *list = fopen(jobs, "r");
	char line[1024];
	int done = 0;

	if (!list) {
		fprintf(stderr, "cannot read %s\n", jobs);
		return 1;
	}

	while (fgets(line, sizeof(line), list)) {
		char *split = strchr(line, ' ');
		FILE *script, *out;

		if (!split) continue;
		*split = '\0';
		split++;
		split[strcspn(split, "\r\n")] = '\0';

		script = fopen(line, "r");
		if (!script) {
			fprintf(stderr, "cannot read %s\n", line);
			fclose(list);
			return 1;
		}

		out = fopen(split, "wb");
		if (!out) {
			fprintf(stderr, "cannot write %s\n", split);
			fclose(script);
			fclose(list);
			return 1;
		}

		render(script, out, total);
		fclose(script);
		fclose(out);
		done++;
	}

	fclose(list);
	fprintf(stderr, "%d rendered\n", done);
	return 0;
}

int main(int argc, char **argv) {
	long total = argc > 1 ? atol(argv[1]) : 44100;

	OPN2_SetChipType(ym3438_mode_readmode);

	if (argc > 2) return batch(argv[2], total);

#ifdef _WIN32
	/* without this every 0x0A byte of a sample leaves as 0x0D 0x0A and the whole stream shifts */
	_setmode(_fileno(stdout), _O_BINARY);
#endif

	render(stdin, stdout, total);
	return 0;
}

#ifndef HX68K_AUDIO_H
#define HX68K_AUDIO_H

#ifdef __cplusplus
extern "C" {
#endif

int host_audio_start(int rate);

void host_audio_stop(void);

int host_audio_push(const short *interleaved, int frames);

int host_audio_queued(void);

int host_audio_starved(void);

void host_audio_clear(void);

#ifdef __cplusplus
}
#endif

#endif

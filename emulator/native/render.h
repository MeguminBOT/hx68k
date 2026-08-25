#ifndef HX68K_RENDER_H
#define HX68K_RENDER_H

#include <SDL3/SDL.h>

#ifdef __cplusplus
extern "C" {
#endif

int host_sdl_init(void);
void host_sdl_quit(void);

SDL_Window *host_window_create(const char *title, int width, int height);
void host_window_destroy(SDL_Window *window);
unsigned int host_window_id(SDL_Window *window);
void host_window_set_title(SDL_Window *window, const char *title);
int host_window_width(SDL_Window *window);
int host_window_height(SDL_Window *window);
int host_window_pixel_width(SDL_Window *window);
int host_window_pixel_height(SDL_Window *window);
void host_window_set_size(SDL_Window *window, int width, int height);
void host_window_set_minimum_size(SDL_Window *window, int width, int height);
float host_window_display_scale(SDL_Window *window);
void host_text_input_start(SDL_Window *window);
void host_text_input_stop(SDL_Window *window);

SDL_Renderer *host_renderer_create(SDL_Window *window, int vsync);

float host_display_refresh(SDL_Window *window);

const char *host_renderer_name(SDL_Renderer *renderer);
int host_renderer_vsync(SDL_Renderer *renderer);
void host_renderer_destroy(SDL_Renderer *renderer);
void host_render_clear(SDL_Renderer *renderer, float r, float g, float b, float a);
void host_render_present(SDL_Renderer *renderer);
void host_set_clip(SDL_Renderer *renderer, int x, int y, int width, int height);
void host_clear_clip(SDL_Renderer *renderer);

SDL_Texture *host_texture_create(SDL_Renderer *renderer, int width, int height);
void host_texture_update(SDL_Texture *texture, const unsigned char *rgba, int width, int height);
void host_texture_destroy(SDL_Texture *texture);

void host_render_texture(SDL_Renderer *renderer, SDL_Texture *texture,
	float dstX, float dstY, float dstWidth, float dstHeight);

void host_render_texture_region(SDL_Renderer *renderer, SDL_Texture *texture,
	float srcWidth, float srcHeight, float dstX, float dstY, float dstWidth, float dstHeight);

void host_render_geometry(SDL_Renderer *renderer, SDL_Texture *texture,
	const float *vertices, int vertexCount);

const char *host_open_file_dialog(SDL_Window *window, const char *filterName, const char *pattern);

#ifdef __cplusplus
}
#endif

#endif

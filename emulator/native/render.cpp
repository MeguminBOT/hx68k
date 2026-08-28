#include "render.h"
#include <cstring>

extern "C" int host_sdl_init() {
	return SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD) ? 1 : 0;
}

extern "C" void host_sdl_quit() {
	SDL_Quit();
}

extern "C" SDL_Window *host_window_create(const char *title, int width, int height) {
	return SDL_CreateWindow(title, width, height, SDL_WINDOW_RESIZABLE);
}

extern "C" void host_window_destroy(SDL_Window *window) {
	SDL_DestroyWindow(window);
}

extern "C" unsigned int host_window_id(SDL_Window *window) {
	return SDL_GetWindowID(window);
}

extern "C" void host_window_set_title(SDL_Window *window, const char *title) {
	SDL_SetWindowTitle(window, title);
}

extern "C" int host_window_width(SDL_Window *window) {
	int width = 0;
	SDL_GetWindowSize(window, &width, nullptr);
	return width;
}

extern "C" int host_window_height(SDL_Window *window) {
	int height = 0;
	SDL_GetWindowSize(window, nullptr, &height);
	return height;
}

extern "C" int host_window_pixel_width(SDL_Window *window) {
	int width = 0;
	SDL_GetWindowSizeInPixels(window, &width, nullptr);
	return width;
}

extern "C" int host_window_pixel_height(SDL_Window *window) {
	int height = 0;
	SDL_GetWindowSizeInPixels(window, nullptr, &height);
	return height;
}

extern "C" void host_window_set_size(SDL_Window *window, int width, int height) {
	SDL_SetWindowSize(window, width, height);
}

extern "C" void host_window_set_minimum_size(SDL_Window *window, int width, int height) {
	SDL_SetWindowMinimumSize(window, width, height);
}

extern "C" void host_window_set_fullscreen(SDL_Window *window, int on) {
	SDL_SetWindowFullscreen(window, on != 0);
	SDL_SyncWindow(window);
}

extern "C" float host_window_display_scale(SDL_Window *window) {
	const float scale = SDL_GetWindowDisplayScale(window);
	return scale <= 0.0f ? 1.0f : scale;
}

extern "C" void host_text_input_start(SDL_Window *window) {
	SDL_StartTextInput(window);
}

extern "C" void host_text_input_stop(SDL_Window *window) {
	SDL_StopTextInput(window);
}

extern "C" SDL_Renderer *host_renderer_create(SDL_Window *window, int vsync) {
	SDL_Renderer *renderer = SDL_CreateRenderer(window, nullptr);
	if (renderer != nullptr) SDL_SetRenderVSync(renderer, vsync ? 1 : SDL_RENDERER_VSYNC_DISABLED);
	return renderer;
}

extern "C" float host_display_refresh(SDL_Window *window) {
	const SDL_DisplayMode *mode = SDL_GetCurrentDisplayMode(SDL_GetDisplayForWindow(window));
	return mode == nullptr ? 0.0f : mode->refresh_rate;
}

extern "C" const char *host_renderer_name(SDL_Renderer *renderer) {
	const char *name = SDL_GetRendererName(renderer);
	return name == nullptr ? "unknown" : name;
}

extern "C" int host_renderer_vsync(SDL_Renderer *renderer) {
	int interval = 0;
	if (!SDL_GetRenderVSync(renderer, &interval)) return -1;
	return interval;
}

extern "C" void host_renderer_destroy(SDL_Renderer *renderer) {
	SDL_DestroyRenderer(renderer);
}

extern "C" void host_render_clear(SDL_Renderer *renderer, float r, float g, float b, float a) {
	SDL_SetRenderDrawColorFloat(renderer, r, g, b, a);
	SDL_RenderClear(renderer);
}

extern "C" void host_render_present(SDL_Renderer *renderer) {
	SDL_RenderPresent(renderer);
}

extern "C" void host_set_clip(SDL_Renderer *renderer, int x, int y, int width, int height) {
	const SDL_Rect rect = {x, y, width, height};
	SDL_SetRenderClipRect(renderer, &rect);
}

extern "C" void host_clear_clip(SDL_Renderer *renderer) {
	SDL_SetRenderClipRect(renderer, nullptr);
}

extern "C" SDL_Texture *host_texture_create(SDL_Renderer *renderer, int width, int height) {
	SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32,
		SDL_TEXTUREACCESS_STREAMING, width, height);
	if (texture != nullptr) SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST);
	return texture;
}

extern "C" void host_texture_update(SDL_Texture *texture, const unsigned char *rgba, int width, int height) {
	SDL_UpdateTexture(texture, nullptr, rgba, width * 4);
}

extern "C" void host_texture_destroy(SDL_Texture *texture) {
	SDL_DestroyTexture(texture);
}

extern "C" void host_render_texture(SDL_Renderer *renderer, SDL_Texture *texture,
		float dstX, float dstY, float dstWidth, float dstHeight) {
	const SDL_FRect dst = {dstX, dstY, dstWidth, dstHeight};
	SDL_RenderTexture(renderer, texture, nullptr, &dst);
}

extern "C" void host_render_texture_region(SDL_Renderer *renderer, SDL_Texture *texture,
		float srcWidth, float srcHeight, float dstX, float dstY, float dstWidth, float dstHeight) {
	const SDL_FRect src = {0, 0, srcWidth, srcHeight};
	const SDL_FRect dst = {dstX, dstY, dstWidth, dstHeight};
	SDL_RenderTexture(renderer, texture, &src, &dst);
}

extern "C" void host_render_geometry(SDL_Renderer *renderer, SDL_Texture *texture,
		const float *vertices, int vertexCount) {
	static_assert(sizeof(SDL_Vertex) == sizeof(float) * 8, "SDL_Vertex is no longer eight floats");
	SDL_RenderGeometry(renderer, texture, reinterpret_cast<const SDL_Vertex *>(vertices),
		vertexCount, nullptr, 0);
}

namespace {
	char dialogResult[4096] = {0};
	bool dialogDone = false;
	bool dialogHasResult = false;

	void SDLCALL dialogCallback(void *, const char *const *filelist, int) {
		dialogHasResult = filelist != nullptr && filelist[0] != nullptr;
		if (dialogHasResult) {
			std::strncpy(dialogResult, filelist[0], sizeof(dialogResult) - 1);
			dialogResult[sizeof(dialogResult) - 1] = 0;
		}
		dialogDone = true;
	}
}

extern "C" const char *host_open_file_dialog(SDL_Window *window, const char *filterName, const char *pattern) {
	const SDL_DialogFileFilter filter = {filterName, pattern};
	dialogDone = false;
	dialogHasResult = false;

	SDL_ShowOpenFileDialog(dialogCallback, nullptr, window, &filter, 1, nullptr, false);

	while (!dialogDone) {
		SDL_Event event;
		SDL_WaitEventTimeout(&event, 50);
	}

	return dialogHasResult ? dialogResult : nullptr;
}

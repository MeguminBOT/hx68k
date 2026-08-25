#include "events.h"
#include <SDL3/SDL.h>

extern "C" int host_poll_event(HostEvent *out) {
	SDL_Event event;
	if (!SDL_PollEvent(&event)) return 0;

	out->type = HOST_EVENT_NONE;
	out->windowID = 0;
	out->code = 0;
	out->value = 0;
	out->x = 0;
	out->y = 0;

	switch (event.type) {
		case SDL_EVENT_QUIT:
			out->type = HOST_EVENT_QUIT;
			break;

		case SDL_EVENT_KEY_DOWN:
			out->type = HOST_EVENT_KEY_DOWN;
			out->windowID = event.key.windowID;
			out->code = static_cast<int>(event.key.key);
			out->value = event.key.repeat ? 1 : 0;
			break;

		case SDL_EVENT_KEY_UP:
			out->type = HOST_EVENT_KEY_UP;
			out->windowID = event.key.windowID;
			out->code = static_cast<int>(event.key.key);
			break;

		case SDL_EVENT_MOUSE_MOTION:
			out->type = HOST_EVENT_MOUSE_MOVE;
			out->windowID = event.motion.windowID;
			out->x = event.motion.x;
			out->y = event.motion.y;
			break;

		case SDL_EVENT_MOUSE_BUTTON_DOWN:
			out->type = HOST_EVENT_MOUSE_DOWN;
			out->windowID = event.button.windowID;
			out->code = event.button.button;
			out->x = event.button.x;
			out->y = event.button.y;
			break;

		case SDL_EVENT_MOUSE_BUTTON_UP:
			out->type = HOST_EVENT_MOUSE_UP;
			out->windowID = event.button.windowID;
			out->code = event.button.button;
			out->x = event.button.x;
			out->y = event.button.y;
			break;

		case SDL_EVENT_MOUSE_WHEEL:
			out->type = HOST_EVENT_MOUSE_WHEEL;
			out->windowID = event.wheel.windowID;
			out->y = event.wheel.y;
			break;

		case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
			out->type = HOST_EVENT_WINDOW_CLOSE;
			out->windowID = event.window.windowID;
			break;

		case SDL_EVENT_WINDOW_RESIZED:
			out->type = HOST_EVENT_WINDOW_RESIZED;
			out->windowID = event.window.windowID;
			out->code = event.window.data1;
			out->value = event.window.data2;
			break;

		case SDL_EVENT_WINDOW_FOCUS_LOST:
			out->type = HOST_EVENT_WINDOW_FOCUS_LOST;
			out->windowID = event.window.windowID;
			break;

		case SDL_EVENT_WINDOW_FOCUS_GAINED:
			out->type = HOST_EVENT_WINDOW_FOCUS_GAINED;
			out->windowID = event.window.windowID;
			break;

		default:
			out->type = HOST_EVENT_NONE;
			break;
	}

	return 1;
}

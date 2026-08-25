#include "events.h"
#include <SDL3/SDL.h>

static int host_mods_of(SDL_Keymod mod) {
	int out = HOST_MOD_NONE;
	if (mod & SDL_KMOD_SHIFT) out |= HOST_MOD_SHIFT;
	if (mod & SDL_KMOD_CTRL) out |= HOST_MOD_CTRL;
	if (mod & SDL_KMOD_ALT) out |= HOST_MOD_ALT;
	if (mod & SDL_KMOD_GUI) out |= HOST_MOD_GUI;
	return out;
}

extern "C" const char *host_event_text(const HostEvent *event) {
	return event->text;
}

static SDL_Gamepad *hostPad = nullptr;

extern "C" int host_pad_open(void) {
	if (hostPad != nullptr && SDL_GamepadConnected(hostPad)) return 1;

	if (hostPad != nullptr) {
		SDL_CloseGamepad(hostPad);
		hostPad = nullptr;
	}

	int count = 0;
	SDL_JoystickID *ids = SDL_GetGamepads(&count);
	if (ids == nullptr) return 0;

	if (count > 0) hostPad = SDL_OpenGamepad(ids[0]);
	SDL_free(ids);

	return hostPad != nullptr ? 1 : 0;
}

extern "C" void host_pad_close(void) {
	if (hostPad == nullptr) return;
	SDL_CloseGamepad(hostPad);
	hostPad = nullptr;
}

extern "C" int host_pad_state(void) {
	if (hostPad == nullptr) return 0;

	int out = 0;
	if (SDL_GetGamepadButton(hostPad, SDL_GAMEPAD_BUTTON_DPAD_UP)) out |= HOST_PAD_UP;
	if (SDL_GetGamepadButton(hostPad, SDL_GAMEPAD_BUTTON_DPAD_DOWN)) out |= HOST_PAD_DOWN;
	if (SDL_GetGamepadButton(hostPad, SDL_GAMEPAD_BUTTON_DPAD_LEFT)) out |= HOST_PAD_LEFT;
	if (SDL_GetGamepadButton(hostPad, SDL_GAMEPAD_BUTTON_DPAD_RIGHT)) out |= HOST_PAD_RIGHT;
	if (SDL_GetGamepadButton(hostPad, SDL_GAMEPAD_BUTTON_WEST)) out |= HOST_PAD_A;
	if (SDL_GetGamepadButton(hostPad, SDL_GAMEPAD_BUTTON_SOUTH)) out |= HOST_PAD_B;
	if (SDL_GetGamepadButton(hostPad, SDL_GAMEPAD_BUTTON_EAST)) out |= HOST_PAD_C;
	if (SDL_GetGamepadButton(hostPad, SDL_GAMEPAD_BUTTON_START)) out |= HOST_PAD_START;

	const int dead = 12000;
	const int x = SDL_GetGamepadAxis(hostPad, SDL_GAMEPAD_AXIS_LEFTX);
	const int y = SDL_GetGamepadAxis(hostPad, SDL_GAMEPAD_AXIS_LEFTY);

	if (x < -dead) out |= HOST_PAD_LEFT;
	if (x > dead) out |= HOST_PAD_RIGHT;
	if (y < -dead) out |= HOST_PAD_UP;
	if (y > dead) out |= HOST_PAD_DOWN;

	return out;
}

extern "C" int host_poll_event(HostEvent *out) {
	SDL_Event event;
	if (!SDL_PollEvent(&event)) return 0;

	out->type = HOST_EVENT_NONE;
	out->windowID = 0;
	out->code = 0;
	out->value = 0;
	out->mods = HOST_MOD_NONE;
	out->x = 0;
	out->y = 0;
	out->text[0] = 0;

	switch (event.type) {
		case SDL_EVENT_QUIT:
			out->type = HOST_EVENT_QUIT;
			break;

		case SDL_EVENT_KEY_DOWN:
			out->type = HOST_EVENT_KEY_DOWN;
			out->windowID = event.key.windowID;
			out->code = static_cast<int>(event.key.key);
			out->value = event.key.repeat ? 1 : 0;
			out->mods = host_mods_of(event.key.mod);
			break;

		case SDL_EVENT_KEY_UP:
			out->type = HOST_EVENT_KEY_UP;
			out->windowID = event.key.windowID;
			out->code = static_cast<int>(event.key.key);
			out->mods = host_mods_of(event.key.mod);
			break;

		case SDL_EVENT_TEXT_INPUT: {
			out->type = HOST_EVENT_TEXT;
			out->windowID = event.text.windowID;
			out->mods = host_mods_of(SDL_GetModState());
			if (event.text.text != nullptr) {
				SDL_strlcpy(out->text, event.text.text, HOST_EVENT_TEXT_BYTES);
			}
			break;
		}

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
			out->mods = host_mods_of(SDL_GetModState());
			out->x = event.button.x;
			out->y = event.button.y;
			break;

		case SDL_EVENT_MOUSE_BUTTON_UP:
			out->type = HOST_EVENT_MOUSE_UP;
			out->windowID = event.button.windowID;
			out->code = event.button.button;
			out->mods = host_mods_of(SDL_GetModState());
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

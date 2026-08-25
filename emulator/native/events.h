#ifndef HX68K_EVENTS_H
#define HX68K_EVENTS_H

#ifdef __cplusplus
extern "C" {
#endif

enum {
	HOST_EVENT_NONE = 0,
	HOST_EVENT_QUIT = 1,
	HOST_EVENT_KEY_DOWN = 2,
	HOST_EVENT_KEY_UP = 3,
	HOST_EVENT_MOUSE_MOVE = 4,
	HOST_EVENT_MOUSE_DOWN = 5,
	HOST_EVENT_MOUSE_UP = 6,
	HOST_EVENT_MOUSE_WHEEL = 7,
	HOST_EVENT_WINDOW_CLOSE = 8,
	HOST_EVENT_WINDOW_RESIZED = 9,
	HOST_EVENT_WINDOW_FOCUS_LOST = 10,
	HOST_EVENT_WINDOW_FOCUS_GAINED = 11,
	HOST_EVENT_TEXT = 12
};

enum {
	HOST_MOD_NONE = 0,
	HOST_MOD_SHIFT = 1,
	HOST_MOD_CTRL = 2,
	HOST_MOD_ALT = 4,
	HOST_MOD_GUI = 8
};

#define HOST_EVENT_TEXT_BYTES 32

typedef struct {
	int type;
	unsigned int windowID;
	int code;
	int value;
	int mods;
	float x;
	float y;
	char text[HOST_EVENT_TEXT_BYTES];
} HostEvent;

int host_poll_event(HostEvent *out);
const char *host_event_text(const HostEvent *event);

#ifdef __cplusplus
}
#endif

#endif

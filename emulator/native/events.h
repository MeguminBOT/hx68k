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
	HOST_EVENT_WINDOW_FOCUS_GAINED = 11
};

typedef struct {
	int type;
	unsigned int windowID;
	int code;
	int value;
	float x;
	float y;
} HostEvent;

int host_poll_event(HostEvent *out);

#ifdef __cplusplus
}
#endif

#endif

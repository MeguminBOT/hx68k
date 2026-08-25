#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_WAV
#define MA_NO_FLAC
#define MA_NO_MP3
#define MA_NO_GENERATION
#define MA_NO_ENGINE
#define MA_NO_NODE_GRAPH
#define MA_NO_RESOURCE_MANAGER
#define MA_IMPLEMENTATION
#include "miniaudio.h"

#include "audio.h"
#include <atomic>

namespace {
	constexpr uint32_t CAPACITY = 16384;
	constexpr uint32_t MASK = CAPACITY - 1;

	short ring[CAPACITY * 2];
	std::atomic<uint32_t> head{0};
	std::atomic<uint32_t> tail{0};
	std::atomic<uint32_t> starved{0};

	ma_device device;
	bool started = false;

	void data_callback(ma_device *, void *output, const void *, ma_uint32 frameCount) {
		const uint32_t at = tail.load(std::memory_order_relaxed);
		const uint32_t have = head.load(std::memory_order_acquire) - at;
		const uint32_t take = have < frameCount ? have : frameCount;

		short *out = static_cast<short *>(output);
		for (uint32_t i = 0; i < take; i++) {
			const uint32_t index = (at + i) & MASK;
			out[i * 2] = ring[index * 2];
			out[i * 2 + 1] = ring[index * 2 + 1];
		}
		if (take < frameCount) starved.fetch_add(1, std::memory_order_relaxed);
		for (uint32_t i = take; i < frameCount; i++) {
			out[i * 2] = 0;
			out[i * 2 + 1] = 0;
		}

		tail.store(at + take, std::memory_order_release);
	}
}

extern "C" int host_audio_start(int rate) {
	if (started) return 1;

	ma_device_config config = ma_device_config_init(ma_device_type_playback);
	config.playback.format = ma_format_s16;
	config.playback.channels = 2;
	config.sampleRate = static_cast<ma_uint32>(rate);
	config.dataCallback = data_callback;

	head.store(0, std::memory_order_relaxed);
	tail.store(0, std::memory_order_relaxed);

	if (ma_device_init(nullptr, &config, &device) != MA_SUCCESS) return 0;
	if (ma_device_start(&device) != MA_SUCCESS) {
		ma_device_uninit(&device);
		return 0;
	}

	started = true;
	return 1;
}

extern "C" void host_audio_stop() {
	if (!started) return;
	ma_device_uninit(&device);
	started = false;
}

extern "C" int host_audio_push(const short *interleaved, int frames) {
	if (!started || frames <= 0) return 0;

	const uint32_t at = head.load(std::memory_order_relaxed);
	const uint32_t used = at - tail.load(std::memory_order_acquire);
	const uint32_t room = CAPACITY - used;
	const uint32_t take = room < static_cast<uint32_t>(frames) ? room : static_cast<uint32_t>(frames);

	for (uint32_t i = 0; i < take; i++) {
		const uint32_t index = (at + i) & MASK;
		ring[index * 2] = interleaved[i * 2];
		ring[index * 2 + 1] = interleaved[i * 2 + 1];
	}

	head.store(at + take, std::memory_order_release);
	return static_cast<int>(take);
}

extern "C" int host_audio_queued() {
	if (!started) return 0;
	return static_cast<int>(head.load(std::memory_order_acquire) - tail.load(std::memory_order_acquire));
}

extern "C" int host_audio_starved() {
	return static_cast<int>(starved.load(std::memory_order_relaxed));
}

extern "C" void host_audio_clear() {
	tail.store(head.load(std::memory_order_acquire), std::memory_order_release);
}

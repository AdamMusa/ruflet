#pragma once

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define RUFLET_BRIDGE_EXPORT __declspec(dllexport)
#else
#define RUFLET_BRIDGE_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Return values for the receive functions below.
#define RUFLET_BRIDGE_CLOSED 0
#define RUFLET_BRIDGE_MESSAGE 1
#define RUFLET_BRIDGE_ERROR -1

// Starts a fresh single-client bridge. This is called before the embedded Ruby
// entrypoint boots, allowing Ruby to wait for the renderer without opening a
// socket or requiring the renderer to win a startup race.
RUFLET_BRIDGE_EXPORT void ruflet_bridge_reset(void);
RUFLET_BRIDGE_EXPORT void ruflet_bridge_close(void);
RUFLET_BRIDGE_EXPORT int ruflet_bridge_is_open(void);

RUFLET_BRIDGE_EXPORT int
ruflet_bridge_send_to_ruby(const uint8_t *bytes, size_t length);
RUFLET_BRIDGE_EXPORT int
ruflet_bridge_receive_for_ruby(uint8_t **bytes, size_t *length);

RUFLET_BRIDGE_EXPORT int
ruflet_bridge_send_to_renderer(const uint8_t *bytes, size_t length);
RUFLET_BRIDGE_EXPORT int
ruflet_bridge_receive_for_renderer(uint8_t **bytes, size_t *length);

// Receive functions transfer ownership of their returned buffer to the
// caller. Free it with this function so allocation stays inside the runtime.
RUFLET_BRIDGE_EXPORT void ruflet_bridge_free_message(uint8_t *bytes);

#ifdef __cplusplus
}
#endif

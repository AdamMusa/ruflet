#pragma once

#include <stddef.h>

#if defined(_WIN32)
#define RUFLET_VM_EXPORT __declspec(dllexport)
#else
#define RUFLET_VM_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

RUFLET_VM_EXPORT int
ruflet_vm_start(const char *project_root, const char *entrypoint,
                const char *const *load_paths, size_t load_path_count,
                const char *const *environment_keys,
                const char *const *environment_values, size_t environment_count,
                const char *stop_signal_path, const char *error_file_path);

RUFLET_VM_EXPORT int ruflet_vm_is_running(void);
RUFLET_VM_EXPORT size_t ruflet_vm_copy_error(char *buffer, size_t capacity);
RUFLET_VM_EXPORT void ruflet_vm_stop(void);

#ifdef __cplusplus
}
#endif

/*
 * Cold-start benchmark for the embedded Ruflet VM.
 *
 * Links the same prebuilt archive an application links (macos/Frameworks/
 * libruflet_vm.a) and drives it through the same four entry points the Flutter
 * plugins use, so the numbers here are the runtime's real boot cost rather than
 * a reconstruction of it.
 *
 * Reports two phases:
 *
 *   start_returns  how long ruflet_vm_start() blocks its caller. The VM boots
 *                  on a detached thread, so this is pure call overhead and is
 *                  the part a Flutter app already pays asynchronously.
 *   port_bound     start() -> the Ruby server publishing its port. This is the
 *                  whole Ruby boot: mrb_open, the bootstrap irep, requiring the
 *                  framework, running the app, binding the socket.
 *
 * port_bound is the ceiling on what moving initialization to the platform layer
 * can hide: you cannot overlap more Ruby boot than there is Ruby boot.
 *
 * Usage: bench_vm <project_root> <entrypoint> [iterations]
 *
 * Each iteration runs in a fresh process (see run_bench.sh) because the VM host
 * keeps process-global state and only boots once per process.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "../../ruby_runtime/desktop/ruflet_vm_host.h"

static double now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
}

/* Polls far tighter than the 25ms the Dart template uses, so the measurement
 * reports when the port was actually published rather than when a sleepy loop
 * next looked. */
static int wait_for_port(const char *path, const char *error_path,
                         double deadline_ms, double *bound_at) {
  char buffer[64];
  while (now_ms() < deadline_ms) {
    FILE *file = fopen(path, "r");
    if (file != NULL) {
      const size_t read = fread(buffer, 1, sizeof(buffer) - 1, file);
      fclose(file);
      buffer[read] = '\0';
      const int port = atoi(buffer);
      if (port > 0) {
        *bound_at = now_ms();
        return port;
      }
    }
    FILE *error = fopen(error_path, "r");
    if (error != NULL) {
      const size_t read = fread(buffer, 1, sizeof(buffer) - 1, error);
      fclose(error);
      buffer[read] = '\0';
      if (read > 0) {
        fprintf(stderr, "runtime error: %s\n", buffer);
        return -1;
      }
    }
    usleep(200);
  }
  return -1;
}

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "usage: %s <project_root> <entrypoint>\n", argv[0]);
    return 2;
  }

  const char *root = argv[1];
  const char *entrypoint = argv[2];

  char port_path[1024];
  char error_path[1024];
  char stop_path[1024];
  char assets_path[1024];
  snprintf(port_path, sizeof(port_path), "%s/.bench.port", root);
  snprintf(error_path, sizeof(error_path), "%s/.bench.error", root);
  snprintf(stop_path, sizeof(stop_path), "%s/.bench.stop", root);
  snprintf(assets_path, sizeof(assets_path), "%s/assets", root);
  remove(port_path);
  remove(error_path);

  const char *load_paths[] = {root};
  const char *environment_keys[] = {"RUFLET_PORT", "RUFLET_ASSETS_DIR",
                                    "RUFLET_RUNTIME_PORT_FILE",
                                    "RUFLET_RUNTIME_ERROR_FILE",
                                    "RUFLET_SUPPRESS_SERVER_BANNER"};
  const char *environment_values[] = {"0", assets_path, port_path, error_path,
                                      "1"};

  const double t_call = now_ms();
  const int status = ruflet_vm_start(root, entrypoint, load_paths, 1,
                                     environment_keys, environment_values, 5,
                                     stop_path, error_path);
  const double t_returned = now_ms();

  if (status != 0) {
    fprintf(stderr, "ruflet_vm_start rejected the entrypoint\n");
    return 1;
  }

  double t_bound = 0.0;
  const int port =
      wait_for_port(port_path, error_path, t_call + 30000.0, &t_bound);
  if (port <= 0) {
    fprintf(stderr, "server never published a port\n");
    ruflet_vm_stop();
    return 1;
  }

  /* Machine-readable: consumed by run_bench.sh. */
  printf("start_returns_ms=%.3f port_bound_ms=%.3f port=%d\n",
         t_returned - t_call, t_bound - t_call, port);

  ruflet_vm_stop();
  return 0;
}

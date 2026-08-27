#pragma once

// Platform-side startup for the embedded Ruby VM, shared by the Linux and
// Windows bridges.
//
// Desktop has no hook as early as +load on Apple platforms or an
// androidx.startup provider on Android: the earliest a plugin runs is its
// registration, during engine setup. That is still before Dart's main(), so the
// VM boots while the engine finishes coming up rather than after the
// application has already initialized its extensions and unpacked its project.
// The head start is smaller than on mobile, and desktop cold start was never
// the pressing case, but the API ends up the same on all five platforms.
//
// The packaged Ruby project is read straight out of the bundled data directory.
// Flutter assets are ordinary files there, so nothing has to be copied to a
// writable directory first.
//
// Desktop has no Info.plist or AndroidManifest to carry an opt-in flag, so the
// packaged project is the opt-in: a self-contained build ships one and a
// server-driven build does not, which is exactly the distinction the flag
// encodes on the other platforms. RUFLET_RUNTIME_AUTOSTART=0 turns it off for
// an app that wants to drive startup from Dart anyway.
//
// Header-only, with internal linkage, because each platform compiles exactly
// one bridge translation unit. It mirrors how both bridges already share
// ruflet_vm_host.h.

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <string>
#include <thread>

namespace ruflet_autostart {

inline std::mutex &state_mutex() {
  static std::mutex mutex;
  return mutex;
}

inline std::condition_variable &state_signal() {
  static std::condition_variable signal;
  return signal;
}

inline std::string &server_url() {
  static std::string url;
  return url;
}

inline std::string &failure() {
  static std::string message;
  return message;
}

inline std::atomic<bool> &attempted() {
  static std::atomic<bool> value(false);
  return value;
}

/// Directory holding the executable, which is where Flutter puts `data/`.
std::filesystem::path executable_directory();

inline std::filesystem::path flutter_assets_dir() {
  return executable_directory() / "data" / "flutter_assets";
}

std::filesystem::path packaged_project_root();

inline std::filesystem::path entrypoint_at(
    const std::filesystem::path &root) {
  std::error_code error;
  for (const char *name : {"main.mrb", "main.rb"}) {
    const std::filesystem::path candidate = root / name;
    if (std::filesystem::exists(candidate, error)) {
      return candidate;
    }
  }
  return {};
}

inline bool autostart_enabled() {
  const char *env = std::getenv("RUFLET_RUNTIME_AUTOSTART");
  if (env != nullptr && env[0] == '0') {
    return false;
  }
  return !packaged_project_root().empty();
}

/// The packaged project is the single directory under flutter_assets/assets
/// holding a main.rb. RUFLET_EMBEDDED_PROJECT names it when an app packages
/// more than one.
inline std::filesystem::path packaged_project_root() {
  const std::filesystem::path root = flutter_assets_dir() / "assets";
  std::error_code error;

  const char *configured = std::getenv("RUFLET_EMBEDDED_PROJECT");
  if (configured != nullptr && configured[0] != '\0') {
    const std::filesystem::path candidate = root / configured;
    return !entrypoint_at(candidate).empty() ? candidate : std::filesystem::path();
  }

  std::filesystem::path found;
  for (const auto &entry : std::filesystem::directory_iterator(root, error)) {
    if (!entry.is_directory(error)) {
      continue;
    }
    if (entrypoint_at(entry.path()).empty()) {
      continue;
    }
    if (!found.empty()) {
      return {}; // Ambiguous; the app must name one.
    }
    found = entry.path();
  }
  return found;
}

inline void finish(std::string url, std::string error) {
  {
    std::lock_guard<std::mutex> lock(state_mutex());
    server_url() = std::move(url);
    failure() = std::move(error);
  }
  state_signal().notify_all();
}

/// Signature of ruflet_vm_start. Passed in rather than called directly because
/// Windows resolves the VM out of ruflet_vm.dll at runtime, so there is no such
/// symbol to link against there.
using StartFunction = int (*)(const char *, const char *, const char *const *,
                              size_t, const char *const *, const char *const *,
                              size_t, const char *, const char *);

inline void begin(StartFunction start) {
  std::error_code error;
  const std::filesystem::path root = packaged_project_root();
  if (root.empty()) {
    finish({}, "No packaged Ruby project was found beside the executable. "
               "Build with `ruflet build --self`, or name the project with "
               "RUFLET_EMBEDDED_PROJECT.");
    return;
  }

  // The bundle may be read-only, so the runtime's scratch files live in the
  // system temporary directory rather than beside the sources.
  const std::filesystem::path scratch =
      std::filesystem::temp_directory_path(error) / "ruflet-runtime";
  std::filesystem::create_directories(scratch, error);
  const std::filesystem::path port_path = scratch / "server.port";
  const std::filesystem::path error_path = scratch / "server.error";
  const std::filesystem::path stop_path = scratch / "server.stop";
  std::filesystem::remove(port_path, error);
  std::filesystem::remove(error_path, error);
  std::filesystem::remove(stop_path, error);

  const std::string root_text = root.string();
  const std::string entrypoint = entrypoint_at(root).string();
  const std::string assets_dir = (root / "assets").string();
  const std::string port_text = port_path.string();
  const std::string error_text = error_path.string();
  const std::string stop_text = stop_path.string();

  const char *load_paths[] = {root_text.c_str()};
  const char *environment_keys[] = {
      "RUFLET_PORT", "RUFLET_ASSETS_DIR", "RUFLET_RUNTIME_PORT_FILE",
      "RUFLET_RUNTIME_ERROR_FILE", "RUFLET_SUPPRESS_SERVER_BANNER"};
  const char *environment_values[] = {"0", assets_dir.c_str(),
                                      port_text.c_str(), error_text.c_str(),
                                      "1"};

  if (start(root_text.c_str(), entrypoint.c_str(), load_paths, 1,
            environment_keys, environment_values, 5, stop_text.c_str(),
            error_text.c_str()) != 0) {
    finish({}, "The packaged entrypoint was rejected by the VM; it must be a "
               ".rb or .mrb file inside the project root.");
    return;
  }

  const auto deadline =
      std::chrono::steady_clock::now() + std::chrono::seconds(30);
  while (std::chrono::steady_clock::now() < deadline) {
    std::ifstream port_file(port_path);
    if (port_file) {
      int port = 0;
      port_file >> port;
      if (port > 0) {
        finish("http://127.0.0.1:" + std::to_string(port), {});
        return;
      }
    }
    std::ifstream error_file(error_path);
    if (error_file) {
      std::string reported((std::istreambuf_iterator<char>(error_file)),
                           std::istreambuf_iterator<char>());
      if (!reported.empty()) {
        finish({}, std::move(reported));
        return;
      }
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
  finish({}, "The embedded Ruflet server did not publish a port.");
}

/// Call from the plugin's registration. Starts the VM on a detached thread when
/// the app opted in; registration itself must not block, or the engine waits.
inline void on_register(StartFunction start) {
  if (start == nullptr || !autostart_enabled()) {
    return;
  }
  attempted() = true;
  std::thread(begin, start).detach();
}

/// Blocks until the URL is known. Callers must run this off the platform
/// thread. Returns false and fills `error` when the runtime failed.
inline bool await_url(std::string *url, std::string *error) {
  if (!attempted()) {
    *error =
        "This app does not start the runtime from the platform layer. Build "
        "with `ruflet build --self` so a packaged project ships, or call "
        "start() instead.";
    return false;
  }
  std::unique_lock<std::mutex> lock(state_mutex());
  state_signal().wait(
      lock, [] { return !server_url().empty() || !failure().empty(); });
  if (!server_url().empty()) {
    *url = server_url();
    return true;
  }
  *error = failure();
  return false;
}

/// True when the platform owns the runtime, so a start() call cannot take
/// effect. The VM boots once per process: ruflet_vm_start would see a running
/// VM and return success without adopting any of the arguments.
inline bool owns_runtime() { return attempted(); }

/// Copies the autostarted server's port into `path` once it is known.
///
/// A client generated before serverUrl() existed calls start() and then polls
/// the file it named in RUFLET_RUNTIME_PORT_FILE. Its arguments cannot take
/// effect, but the thing it is waiting for already exists, so hand it over
/// there. That keeps those clients working -- and getting the parallel
/// startup -- without them knowing anything about it.
inline void mirror_port(const std::string &path) {
  if (path.empty()) {
    return;
  }
  std::thread([path]() {
    std::string url;
    std::string error;
    if (!await_url(&url, &error)) {
      return;
    }
    const std::size_t colon = url.rfind(':');
    if (colon == std::string::npos) {
      return;
    }
    std::ofstream out(path, std::ios::trunc);
    if (out) {
      out << url.substr(colon + 1);
    }
  }).detach();
}

} // namespace ruflet_autostart

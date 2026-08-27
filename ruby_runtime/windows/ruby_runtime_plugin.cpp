#include "ruby_runtime_plugin.h"

#include <windows.h>

#include <flutter/standard_method_codec.h>

#include <filesystem>
#include <memory>
#include <string>
#include <thread>
#include <vector>

#include "../desktop/ruflet_desktop_autostart.h"

namespace ruflet_autostart {
// Flutter lays the bundle out relative to the executable, so `data/` is found
// from the module path rather than the working directory, which a desktop
// launcher does not guarantee.
std::filesystem::path executable_directory() {
  std::vector<wchar_t> buffer(32768, L'\0');
  const DWORD length = GetModuleFileNameW(nullptr, buffer.data(),
                                          static_cast<DWORD>(buffer.size()));
  if (length == 0 || length >= buffer.size()) {
    return std::filesystem::current_path();
  }
  return std::filesystem::path(buffer.data()).parent_path();
}
} // namespace ruflet_autostart

namespace ruby_runtime {
namespace {

using StartFunction = int (*)(const char *, const char *, const char *const *,
                              size_t, const char *const *, const char *const *,
                              size_t, const char *, const char *);
using IsRunningFunction = int (*)();
using CopyErrorFunction = size_t (*)(char *, size_t);
using StopFunction = void (*)();
using BridgeSendFunction = int (*)(const uint8_t *, size_t);
using BridgeReceiveFunction = int (*)(uint8_t **, size_t *);
using BridgeCloseFunction = void (*)();
using BridgeFreeFunction = void (*)(uint8_t *);

constexpr int kBridgeClosed = 0;
constexpr int kBridgeMessage = 1;

struct VmApi {
  HMODULE library = nullptr;
  StartFunction start = nullptr;
  IsRunningFunction is_running = nullptr;
  CopyErrorFunction copy_error = nullptr;
  StopFunction stop = nullptr;
  BridgeSendFunction bridge_send = nullptr;
  BridgeReceiveFunction bridge_receive = nullptr;
  BridgeCloseFunction bridge_close = nullptr;
  BridgeFreeFunction bridge_free = nullptr;
};

VmApi &vm_api() {
  static VmApi api;
  if (api.library != nullptr)
    return api;
  std::vector<wchar_t> executable(32768, L'\0');
  const DWORD length = GetModuleFileNameW(
      nullptr, executable.data(), static_cast<DWORD>(executable.size()));
  if (length == 0 || length >= executable.size())
    return api;
  const std::filesystem::path library_path =
      std::filesystem::path(executable.data()).parent_path() / L"ruflet_vm.dll";
  api.library = LoadLibraryW(library_path.c_str());
  if (api.library == nullptr)
    return api;
  api.start = reinterpret_cast<StartFunction>(
      GetProcAddress(api.library, "ruflet_vm_start"));
  api.is_running = reinterpret_cast<IsRunningFunction>(
      GetProcAddress(api.library, "ruflet_vm_is_running"));
  api.copy_error = reinterpret_cast<CopyErrorFunction>(
      GetProcAddress(api.library, "ruflet_vm_copy_error"));
  api.stop = reinterpret_cast<StopFunction>(
      GetProcAddress(api.library, "ruflet_vm_stop"));
  api.bridge_send = reinterpret_cast<BridgeSendFunction>(
      GetProcAddress(api.library, "ruflet_bridge_send_to_ruby"));
  api.bridge_receive = reinterpret_cast<BridgeReceiveFunction>(
      GetProcAddress(api.library, "ruflet_bridge_receive_for_renderer"));
  api.bridge_close = reinterpret_cast<BridgeCloseFunction>(
      GetProcAddress(api.library, "ruflet_bridge_close"));
  api.bridge_free = reinterpret_cast<BridgeFreeFunction>(
      GetProcAddress(api.library, "ruflet_bridge_free_message"));
  return api;
}

const flutter::EncodableValue *lookup(const flutter::EncodableMap &map,
                                      const char *key) {
  const auto found = map.find(flutter::EncodableValue(key));
  return found == map.end() ? nullptr : &found->second;
}

std::string string_argument(const flutter::EncodableMap &map, const char *key) {
  const flutter::EncodableValue *value = lookup(map, key);
  return value == nullptr || !std::holds_alternative<std::string>(*value)
             ? ""
             : std::get<std::string>(*value);
}

std::vector<std::string> string_list_argument(const flutter::EncodableMap &map,
                                              const char *key) {
  std::vector<std::string> result;
  const flutter::EncodableValue *value = lookup(map, key);
  if (value == nullptr ||
      !std::holds_alternative<flutter::EncodableList>(*value)) {
    return result;
  }
  for (const flutter::EncodableValue &entry :
       std::get<flutter::EncodableList>(*value)) {
    if (std::holds_alternative<std::string>(entry)) {
      result.push_back(std::get<std::string>(entry));
    }
  }
  return result;
}

std::vector<const char *> pointers(const std::vector<std::string> &values) {
  std::vector<const char *> result;
  result.reserve(values.size());
  for (const std::string &value : values)
    result.push_back(value.c_str());
  return result;
}

flutter::EncodableValue status() {
  VmApi &api = vm_api();
  std::string error;
  if (api.copy_error != nullptr) {
    const size_t size = api.copy_error(nullptr, 0);
    std::vector<char> buffer(size == 0 ? 1 : size, '\0');
    api.copy_error(buffer.data(), buffer.size());
    error = buffer.data();
  }
  flutter::EncodableMap value;
  value[flutter::EncodableValue("running")] = flutter::EncodableValue(
      api.is_running != nullptr && api.is_running() != 0);
  value[flutter::EncodableValue("error")] = flutter::EncodableValue(error);
  return flutter::EncodableValue(value);
}

} // namespace

void RubyRuntimePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  // Earliest point a Windows plugin runs. Still before Dart's main(), so the VM
  // boots while the engine finishes coming up rather than after the application
  // has initialized. Returns immediately; the VM boots on its own thread.
  ruflet_autostart::on_register(vm_api().start);

  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "ruflet_runtime",
          &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<RubyRuntimePlugin>();
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

RubyRuntimePlugin::RubyRuntimePlugin() = default;
RubyRuntimePlugin::~RubyRuntimePlugin() = default;

void RubyRuntimePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  VmApi &api = vm_api();
  if (api.start == nullptr || api.is_running == nullptr ||
      api.copy_error == nullptr || api.stop == nullptr ||
      api.bridge_send == nullptr || api.bridge_receive == nullptr ||
      api.bridge_close == nullptr || api.bridge_free == nullptr) {
    result->Error("ruflet_runtime_missing",
                  "The packaged ruflet_vm.dll could not be loaded.");
    return;
  }
  if (method_call.method_name() == "serverUrl") {
    // The wait happens on its own thread; the platform thread never blocks on
    // the VM finishing.
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared(
        result.release());
    std::thread([shared]() {
      std::string url;
      std::string error;
      if (ruflet_autostart::await_url(&url, &error)) {
        shared->Success(flutter::EncodableValue(flutter::EncodableMap{
            {flutter::EncodableValue("url"), flutter::EncodableValue(url)}}));
      } else {
        shared->Error(ruflet_autostart::owns_runtime() ? "ruflet_runtime_error"
                                                       : "autostart_disabled",
                      error);
      }
    }).detach();
    return;
  }
  if (method_call.method_name() == "bridgeSend") {
    const std::vector<uint8_t> *bytes =
        std::get_if<std::vector<uint8_t>>(method_call.arguments());
    if (bytes == nullptr) {
      result->Error("ruflet_bridge_bad_message",
                    "bridgeSend requires binary data.");
      return;
    }
    const int bridge_status = api.bridge_send(
        bytes->empty() ? nullptr : bytes->data(), bytes->size());
    if (bridge_status != kBridgeMessage) {
      result->Error("ruflet_bridge_closed",
                    "The Ruflet in-process bridge is closed.");
      return;
    }
    result->Success();
    return;
  }
  if (method_call.method_name() == "bridgeReceive") {
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared(
        result.release());
    std::thread([shared]() {
      VmApi &thread_api = vm_api();
      uint8_t *bytes = nullptr;
      size_t length = 0;
      const int bridge_status = thread_api.bridge_receive(&bytes, &length);
      std::vector<uint8_t> message;
      if (bridge_status == kBridgeMessage && length > 0) {
        message.assign(bytes, bytes + length);
      }
      thread_api.bridge_free(bytes);
      if (bridge_status == kBridgeMessage) {
        shared->Success(flutter::EncodableValue(message));
      } else if (bridge_status == kBridgeClosed) {
        shared->Success();
      } else {
        shared->Error("ruflet_bridge_receive_failed",
                      "Unable to receive from the Ruflet in-process bridge.");
      }
    }).detach();
    return;
  }
  if (method_call.method_name() == "bridgeClose") {
    api.bridge_close();
    result->Success();
    return;
  }
  if (method_call.method_name() == "status") {
    result->Success(status());
    return;
  }
  if (method_call.method_name() == "stop") {
    api.stop();
    result->Success();
    return;
  }
  if (method_call.method_name() != "start") {
    result->NotImplemented();
    return;
  }
  const flutter::EncodableMap *arguments =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (arguments == nullptr) {
    result->Error("invalid_args", "Missing runtime arguments.");
    return;
  }
  // A packaged runtime already owns its port-free endpoint. A legacy start()
  // call cannot replace it with a second transport.
  if (ruflet_autostart::owns_runtime()) {
    result->Error(
        "in_process_runtime_owned",
        "The packaged Ruflet runtime already owns an in-process endpoint. "
        "Use serverUrl() and the binary bridge instead of start().");
    return;
  }
  const std::string root = string_argument(*arguments, "projectRoot");
  const std::string entrypoint = string_argument(*arguments, "entrypoint");
  std::vector<std::string> load_paths =
      string_list_argument(*arguments, "loadPaths");
  std::vector<std::string> environment_keys;
  std::vector<std::string> environment_values;
  const flutter::EncodableValue *environment =
      lookup(*arguments, "environment");
  if (environment != nullptr &&
      std::holds_alternative<flutter::EncodableMap>(*environment)) {
    for (const auto &entry : std::get<flutter::EncodableMap>(*environment)) {
      if (std::holds_alternative<std::string>(entry.first) &&
          std::holds_alternative<std::string>(entry.second)) {
        environment_keys.push_back(std::get<std::string>(entry.first));
        environment_values.push_back(std::get<std::string>(entry.second));
      }
    }
  }
  const std::vector<const char *> load_path_pointers = pointers(load_paths);
  const std::vector<const char *> environment_key_pointers =
      pointers(environment_keys);
  const std::vector<const char *> environment_value_pointers =
      pointers(environment_values);
  const std::string stop_path = string_argument(*arguments, "stopSignalPath");
  const std::string error_path = string_argument(*arguments, "errorFilePath");
  const int start_result = api.start(
      root.c_str(), entrypoint.c_str(), load_path_pointers.data(),
      load_path_pointers.size(), environment_key_pointers.data(),
      environment_value_pointers.data(), environment_key_pointers.size(),
      stop_path.c_str(), error_path.c_str());
  if (start_result != 0) {
    result->Error(
        "invalid_args",
        "start requires a .rb or .mrb entrypoint inside projectRoot.");
    return;
  }
  result->Success(status());
}

} // namespace ruby_runtime

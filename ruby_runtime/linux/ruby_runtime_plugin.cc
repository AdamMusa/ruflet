#include "include/ruby_runtime/ruby_runtime_plugin.h"

#include <flutter_linux/flutter_linux.h>

#include <climits>
#include <cstring>
#include <memory>
#include <string>
#include <thread>
#include <unistd.h>
#include <vector>

#include "../desktop/ruflet_desktop_autostart.h"
#include "../desktop/ruflet_in_process_bridge.h"
#include "../desktop/ruflet_vm_host.h"

namespace ruflet_autostart {
// Flutter lays the bundle out relative to the executable, so `data/` is found
// through /proc/self/exe rather than the working directory, which a desktop
// launcher does not guarantee.
std::filesystem::path executable_directory() {
  char buffer[PATH_MAX];
  const ssize_t length = readlink("/proc/self/exe", buffer, sizeof(buffer) - 1);
  if (length <= 0) {
    return std::filesystem::current_path();
  }
  buffer[length] = '\0';
  return std::filesystem::path(buffer).parent_path();
}
} // namespace ruflet_autostart

#define RUBY_RUNTIME_PLUGIN(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), ruby_runtime_plugin_get_type(),           \
                              RubyRuntimePlugin))

struct _RubyRuntimePlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(RubyRuntimePlugin, ruby_runtime_plugin, g_object_get_type())

namespace {

FlValue *lookup(FlValue *map, const char *key) {
  return map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP
             ? nullptr
             : fl_value_lookup_string(map, key);
}
std::string string_argument(FlValue *map, const char *key) {
  FlValue *value = lookup(map, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(value)
             : "";
}

std::vector<std::string> string_list_argument(FlValue *map, const char *key) {
  std::vector<std::string> values;
  FlValue *list = lookup(map, key);
  if (list == nullptr || fl_value_get_type(list) != FL_VALUE_TYPE_LIST) {
    return values;
  }
  const size_t length = fl_value_get_length(list);
  values.reserve(length);
  for (size_t index = 0; index < length; ++index) {
    FlValue *value = fl_value_get_list_value(list, index);
    if (fl_value_get_type(value) == FL_VALUE_TYPE_STRING) {
      values.emplace_back(fl_value_get_string(value));
    }
  }
  return values;
}

void environment_argument(FlValue *arguments, std::vector<std::string> *keys,
                          std::vector<std::string> *values) {
  FlValue *map = lookup(arguments, "environment");
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP)
    return;
  const size_t length = fl_value_get_length(map);
  keys->reserve(length);
  values->reserve(length);
  for (size_t index = 0; index < length; ++index) {
    FlValue *key = fl_value_get_map_key(map, index);
    FlValue *value = fl_value_get_map_value(map, index);
    if (fl_value_get_type(key) == FL_VALUE_TYPE_STRING &&
        fl_value_get_type(value) == FL_VALUE_TYPE_STRING) {
      keys->emplace_back(fl_value_get_string(key));
      values->emplace_back(fl_value_get_string(value));
    }
  }
}

std::vector<const char *> pointers(const std::vector<std::string> &values) {
  std::vector<const char *> result;
  result.reserve(values.size());
  for (const std::string &value : values)
    result.push_back(value.c_str());
  return result;
}

FlMethodResponse *status_response() {
  const size_t size = ruflet_vm_copy_error(nullptr, 0);
  std::vector<char> buffer(size == 0 ? 1 : size, '\0');
  ruflet_vm_copy_error(buffer.data(), buffer.size());
  g_autoptr(FlValue) status = fl_value_new_map();
  fl_value_set_string_take(status, "running",
                           fl_value_new_bool(ruflet_vm_is_running() != 0));
  fl_value_set_string_take(status, "error", fl_value_new_string(buffer.data()));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(status));
}

FlMethodResponse *start(FlValue *arguments) {
  // A packaged runtime already owns its port-free endpoint. A legacy start()
  // call cannot replace it with a second transport.
  if (ruflet_autostart::owns_runtime()) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "in_process_runtime_owned",
        "The packaged Ruflet runtime already owns an in-process endpoint. "
        "Use serverUrl() and the binary bridge instead of start().",
        nullptr));
  }

  const std::string root = string_argument(arguments, "projectRoot");
  const std::string entrypoint = string_argument(arguments, "entrypoint");
  std::vector<std::string> load_paths =
      string_list_argument(arguments, "loadPaths");
  std::vector<std::string> environment_keys;
  std::vector<std::string> environment_values;
  environment_argument(arguments, &environment_keys, &environment_values);
  std::vector<const char *> load_path_pointers = pointers(load_paths);
  std::vector<const char *> environment_key_pointers =
      pointers(environment_keys);
  std::vector<const char *> environment_value_pointers =
      pointers(environment_values);
  const std::string stop_path = string_argument(arguments, "stopSignalPath");
  const std::string error_path = string_argument(arguments, "errorFilePath");

  const int result = ruflet_vm_start(
      root.c_str(), entrypoint.c_str(), load_path_pointers.data(),
      load_path_pointers.size(), environment_key_pointers.data(),
      environment_value_pointers.data(), environment_key_pointers.size(),
      stop_path.c_str(), error_path.c_str());
  if (result != 0) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "invalid_args",
        "start requires a .rb or .mrb entrypoint inside projectRoot.",
        nullptr));
  }
  return status_response();
}

FlMethodResponse *bridge_send(FlValue *arguments) {
  if (arguments == nullptr ||
      fl_value_get_type(arguments) != FL_VALUE_TYPE_UINT8_LIST) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "ruflet_bridge_bad_message", "bridgeSend requires binary data.",
        nullptr));
  }
  const int status = ruflet_bridge_send_to_ruby(
      fl_value_get_uint8_list(arguments), fl_value_get_length(arguments));
  if (status != RUFLET_BRIDGE_MESSAGE) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "ruflet_bridge_closed", "The Ruflet in-process bridge is closed.",
        nullptr));
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

// Carries a resolved URL back to the main context. The wait happens on a worker
// thread so the platform thread never blocks on the VM finishing, but the reply
// itself is posted through g_idle_add: GLib objects belong to the main context
// and responding from the worker would be a cross-thread call into it.
struct PendingUrl {
  FlMethodCall *method_call;
  std::string url;
  std::string error;
  bool ok;
};

struct PendingBridgeMessage {
  FlMethodCall *method_call;
  std::vector<uint8_t> bytes;
  int status;
};

gboolean respond_with_url(gpointer data) {
  std::unique_ptr<PendingUrl> pending(static_cast<PendingUrl *>(data));
  g_autoptr(FlMethodResponse) response = nullptr;
  if (pending->ok) {
    g_autoptr(FlValue) value = fl_value_new_map();
    fl_value_set_string_take(value, "url",
                             fl_value_new_string(pending->url.c_str()));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        ruflet_autostart::owns_runtime() ? "ruflet_runtime_error"
                                         : "autostart_disabled",
        pending->error.c_str(), nullptr));
  }
  fl_method_call_respond(pending->method_call, response, nullptr);
  g_object_unref(pending->method_call);
  return G_SOURCE_REMOVE;
}

void resolve_server_url(FlMethodCall *method_call) {
  g_object_ref(method_call);
  std::thread([method_call]() {
    auto pending = std::make_unique<PendingUrl>();
    pending->method_call = method_call;
    pending->ok = ruflet_autostart::await_url(&pending->url, &pending->error);
    g_idle_add(respond_with_url, pending.release());
  }).detach();
}

gboolean respond_with_bridge_message(gpointer data) {
  std::unique_ptr<PendingBridgeMessage> pending(
      static_cast<PendingBridgeMessage *>(data));
  g_autoptr(FlMethodResponse) response = nullptr;
  if (pending->status == RUFLET_BRIDGE_MESSAGE) {
    const uint8_t *bytes =
        pending->bytes.empty() ? nullptr : pending->bytes.data();
    g_autoptr(FlValue) value =
        fl_value_new_uint8_list(bytes, pending->bytes.size());
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  } else if (pending->status == RUFLET_BRIDGE_CLOSED) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "ruflet_bridge_receive_failed",
        "Unable to receive from the Ruflet in-process bridge.", nullptr));
  }
  fl_method_call_respond(pending->method_call, response, nullptr);
  g_object_unref(pending->method_call);
  return G_SOURCE_REMOVE;
}

void receive_bridge_message(FlMethodCall *method_call) {
  g_object_ref(method_call);
  std::thread([method_call]() {
    auto pending = std::make_unique<PendingBridgeMessage>();
    pending->method_call = method_call;
    uint8_t *bytes = nullptr;
    size_t length = 0;
    pending->status = ruflet_bridge_receive_for_renderer(&bytes, &length);
    if (pending->status == RUFLET_BRIDGE_MESSAGE && length > 0) {
      pending->bytes.assign(bytes, bytes + length);
    }
    ruflet_bridge_free_message(bytes);
    g_idle_add(respond_with_bridge_message, pending.release());
  }).detach();
}

void handle_method_call(RubyRuntimePlugin *, FlMethodCall *method_call) {
  const gchar *method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, "serverUrl") == 0) {
    resolve_server_url(method_call);
    return; // Responded from the worker thread.
  } else if (strcmp(method, "start") == 0) {
    response = start(fl_method_call_get_args(method_call));
  } else if (strcmp(method, "bridgeSend") == 0) {
    response = bridge_send(fl_method_call_get_args(method_call));
  } else if (strcmp(method, "bridgeReceive") == 0) {
    receive_bridge_message(method_call);
    return;
  } else if (strcmp(method, "bridgeClose") == 0) {
    ruflet_bridge_close();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "status") == 0) {
    response = status_response();
  } else if (strcmp(method, "stop") == 0) {
    ruflet_vm_stop();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

} // namespace

static void ruby_runtime_plugin_class_init(RubyRuntimePluginClass *) {}
static void ruby_runtime_plugin_init(RubyRuntimePlugin *) {}

static void method_call_cb(FlMethodChannel *, FlMethodCall *method_call,
                           gpointer user_data) {
  handle_method_call(RUBY_RUNTIME_PLUGIN(user_data), method_call);
}

void ruby_runtime_plugin_register_with_registrar(FlPluginRegistrar *registrar) {
  // Earliest point a Linux plugin runs. Still before Dart's main(), so the VM
  // boots while the engine finishes coming up rather than after the application
  // has initialized. Returns immediately; the VM boots on its own thread.
  ruflet_autostart::on_register(&ruflet_vm_start);

  RubyRuntimePlugin *plugin = RUBY_RUNTIME_PLUGIN(
      g_object_new(ruby_runtime_plugin_get_type(), nullptr));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "ruflet_runtime", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);
  g_object_unref(plugin);
}

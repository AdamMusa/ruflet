#include "include/ruby_runtime/ruby_runtime_plugin.h"

#include <flutter_linux/flutter_linux.h>

#include <cstring>
#include <string>
#include <vector>

#include "../desktop/ruflet_vm_host.h"

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

void handle_method_call(RubyRuntimePlugin *, FlMethodCall *method_call) {
  const gchar *method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, "start") == 0) {
    response = start(fl_method_call_get_args(method_call));
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

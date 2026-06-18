#include "include/ruby_runtime/ruby_runtime_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <glib/gstdio.h>
#include <gtk/gtk.h>

#include <cstdlib>
#include <fstream>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>

#include <mruby.h>
#include <mruby/compile.h>
#include <mruby/string.h>

#include "embedded_ruflet_runtime.h"

// This Linux plugin is a faithful port of the macOS plugin
// (macos/Classes/RubyRuntimeMacosPlugin.m). It embeds mruby and exposes the
// full "ruby_runtime" method channel surface so the Dart side never trips a
// MissingPluginException / notImplemented: every method the platform interface
// can call (eval, runFile, reset, startFileServer, stopFileServer,
// isFileServerRunning, serverPort, lastFileServerError) is handled here.

#define RUBY_RUNTIME_LINUX_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), ruby_runtime_linux_plugin_get_type(), \
                              RubyRuntimeLinuxPlugin))

struct _RubyRuntimeLinuxPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(RubyRuntimeLinuxPlugin, ruby_runtime_linux_plugin,
              g_object_get_type())

namespace {

// mruby is process-global and single-threaded; mirror the macOS plugin's
// static state and serialize access with a mutex.
mrb_state* g_mrb = nullptr;
std::mutex g_mutex;
bool g_server_running = false;
bool g_runtime_loaded = false;
std::string g_stop_signal_path;
std::string g_port_file_path;
std::string g_last_server_error;

// Embed a value inside a single-quoted Ruby string literal: only '\\' and '\''
// are escapes inside Ruby single quotes.
std::string escape_ruby_single_quotes(const std::string& text) {
  std::string out;
  out.reserve(text.size());
  for (char c : text) {
    if (c == '\\' || c == '\'') {
      out.push_back('\\');
    }
    out.push_back(c);
  }
  return out;
}

mrb_state* ensure_mrb() {
  if (g_mrb == nullptr) {
    g_mrb = mrb_open();
  }
  return g_mrb;
}

std::string exception_to_string(mrb_state* mrb) {
  if (mrb == nullptr || mrb->exc == nullptr) {
    return "unknown mruby error";
  }

  mrb_value exc = mrb_obj_value(mrb->exc);
  const char* klass = mrb_obj_classname(mrb, exc);
  std::string backtrace_text;

  mrb_value backtrace = mrb_funcall(mrb, exc, "backtrace", 0);
  if (mrb->exc == nullptr && !mrb_nil_p(backtrace)) {
    mrb_value rendered = mrb_inspect(mrb, backtrace);
    if (mrb->exc == nullptr) {
      const char* c = mrb_string_value_cstr(mrb, &rendered);
      if (c != nullptr) {
        backtrace_text = c;
      }
    }
  }
  if (mrb->exc != nullptr) {
    mrb->exc = nullptr;
  }

  std::string k = klass == nullptr ? "Exception" : klass;

  mrb_value text = mrb_funcall(mrb, exc, "to_s", 0);
  if (mrb->exc != nullptr) {
    mrb->exc = nullptr;
    return k + ": <failed to render exception message>";
  }

  const char* msg = mrb_string_value_cstr(mrb, &text);
  mrb->exc = nullptr;

  std::string m = msg == nullptr ? "<empty>" : msg;
  if (!backtrace_text.empty()) {
    return k + ": " + m + "\n" + backtrace_text;
  }
  return k + ": " + m;
}

bool preload_embedded_runtime(mrb_state* mrb, std::string* error) {
  if (g_runtime_loaded) {
    return true;
  }
  if (mrb == nullptr) {
    if (error != nullptr) {
      *error = "mruby runtime is not initialized";
    }
    return false;
  }

  mrbc_context* context = mrbc_context_new(mrb);
  if (context == nullptr) {
    if (error != nullptr) {
      *error = "failed to create preload compile context";
    }
    return false;
  }

  mrbc_filename(mrb, context, "/__ruflet__/embedded_runtime.rb");
  mrb_load_string_cxt(mrb, kEmbeddedRufletRuntime, context);
  mrbc_context_free(mrb, context);

  if (mrb->exc != nullptr) {
    if (error != nullptr) {
      *error = exception_to_string(mrb);
    }
    return false;
  }

  g_runtime_loaded = true;
  return true;
}

// Returns the evaluated value rendered as a string, or sets *error and returns
// false on failure. Caller must hold g_mutex.
bool eval_source(const std::string& source, const std::string& filename,
                 std::string* out, std::string* error) {
  mrb_state* mrb = ensure_mrb();
  if (mrb == nullptr) {
    if (error != nullptr) {
      *error = "failed to initialize mruby runtime";
    }
    return false;
  }
  if (!preload_embedded_runtime(mrb, error)) {
    return false;
  }

  mrbc_context* context = mrbc_context_new(mrb);
  if (context == nullptr) {
    if (error != nullptr) {
      *error = "failed to create mruby compile context";
    }
    return false;
  }

  if (!filename.empty()) {
    mrbc_filename(mrb, context, filename.c_str());
  }

  mrb_value result = mrb_load_string_cxt(mrb, source.c_str(), context);
  mrbc_context_free(mrb, context);

  if (mrb->exc != nullptr) {
    if (error != nullptr) {
      *error = exception_to_string(mrb);
    }
    return false;
  }

  mrb_value display = result;
  if (!mrb_string_p(result)) {
    display = mrb_inspect(mrb, result);
    if (mrb->exc != nullptr) {
      if (error != nullptr) {
        *error = exception_to_string(mrb);
      }
      return false;
    }
  }

  const char* value = mrb_string_value_cstr(mrb, &display);
  if (out != nullptr) {
    *out = value == nullptr ? "" : value;
  }
  return true;
}

bool read_file(const std::string& path, std::string* out, std::string* error) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) {
    if (error != nullptr) {
      *error = "unable to read Ruby file: " + path;
    }
    return false;
  }
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  if (out != nullptr) {
    *out = buffer.str();
  }
  return true;
}

// Returns the port reported through RUFLET_PORT_FILE, or 0 when the server has
// not bound a port yet.
long read_server_port() {
  if (g_port_file_path.empty()) {
    return 0;
  }
  std::string contents;
  if (!read_file(g_port_file_path, &contents, nullptr)) {
    return 0;
  }
  long port = 0;
  try {
    port = std::stol(contents);
  } catch (...) {
    return 0;
  }
  if (port <= 0 || port > 65535) {
    return 0;
  }
  return port;
}

void request_stop_server() {
  if (g_stop_signal_path.empty()) {
    return;
  }
  std::ofstream stream(g_stop_signal_path, std::ios::binary | std::ios::trunc);
  if (stream) {
    stream << "stop";
  }
}

const gchar* lookup_string_arg(FlValue* args, const char* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return nullptr;
  }
  return fl_value_get_string(value);
}

FlMethodResponse* respond_error(const char* message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new("mruby_error", message, nullptr));
}

FlMethodResponse* respond_invalid_args(const char* message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new("invalid_args", message, nullptr));
}

FlMethodResponse* handle_eval(FlValue* args) {
  const gchar* code = lookup_string_arg(args, "code");
  if (code == nullptr || *code == '\0') {
    return respond_invalid_args("Missing 'code' argument.");
  }

  std::string value;
  std::string error;
  bool ok;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    ok = eval_source(code, "", &value, &error);
  }
  if (!ok) {
    return respond_error(error.c_str());
  }
  g_autoptr(FlValue) result = fl_value_new_string(value.c_str());
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_run_file(FlValue* args) {
  const gchar* path = lookup_string_arg(args, "path");
  if (path == nullptr || *path == '\0') {
    return respond_invalid_args("Missing 'path' argument.");
  }

  std::string source;
  std::string error;
  if (!read_file(path, &source, &error)) {
    return respond_error(error.c_str());
  }

  std::string value;
  bool ok;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    ok = eval_source(source, path, &value, &error);
  }
  if (!ok) {
    return respond_error(error.c_str());
  }
  g_autoptr(FlValue) result = fl_value_new_string(value.c_str());
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_reset() {
  if (g_server_running) {
    request_stop_server();
    g_autoptr(FlValue) result = fl_value_new_null();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_mrb != nullptr) {
      mrb_close(g_mrb);
      g_mrb = nullptr;
    }
    g_runtime_loaded = false;
    g_last_server_error.clear();
    g_port_file_path.clear();
  }
  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_start_file_server(FlValue* args) {
  const gchar* path_arg = lookup_string_arg(args, "path");
  if (path_arg == nullptr || *path_arg == '\0') {
    return respond_invalid_args("Missing 'path' argument.");
  }
  if (g_server_running) {
    g_autoptr(FlValue) result = fl_value_new_null();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  std::string path = path_arg;

  const gchar* stop_arg = lookup_string_arg(args, "stopSignalPath");
  std::string stop_path =
      (stop_arg != nullptr && *stop_arg != '\0') ? stop_arg : path + ".stop";

  std::string app_root = path;
  std::string::size_type slash = app_root.find_last_of('/');
  app_root = slash == std::string::npos ? "" : app_root.substr(0, slash);
  std::string port_file_path =
      (app_root.empty() ? std::string() : app_root + "/") + "server.port";

  g_remove(stop_path.c_str());
  g_remove(port_file_path.c_str());
  g_stop_signal_path = stop_path;
  g_port_file_path = port_file_path;

  std::string source;
  std::string error;
  if (!read_file(path, &source, &error)) {
    g_last_server_error = error;
    return respond_error(error.c_str());
  }

  // The embedded VM's ENV is isolated from the process environment, so
  // configuration must be seeded through the Ruby prelude. The server binds any
  // free port and reports the bound port through RUFLET_PORT_FILE.
  std::string prelude;
  prelude += "$__ruflet_app_root = '" + escape_ruby_single_quotes(app_root) + "'\n";
  prelude += "ENV['RUFLET_PROD_STOP_FILE'] = '" +
             escape_ruby_single_quotes(stop_path) +
             "' if Object.const_defined?(:ENV)\n";
  prelude += "ENV['RUFLET_PORT_FILE'] = '" +
             escape_ruby_single_quotes(port_file_path) +
             "' if Object.const_defined?(:ENV)\n";
  std::string full_source = prelude + source;

  g_last_server_error.clear();
  g_server_running = true;

  std::thread([full_source, path, stop_path, port_file_path]() {
    g_setenv("RUFLET_PROD_STOP_FILE", stop_path.c_str(), TRUE);
    g_setenv("RUFLET_PORT_FILE", port_file_path.c_str(), TRUE);

    std::lock_guard<std::mutex> lock(g_mutex);
    std::string value;
    std::string error;
    bool ok = eval_source(full_source, path, &value, &error);
    if (ok && value.rfind(":", 0) == 0) {
      std::string safe_path = escape_ruby_single_quotes(path);
      std::string bootstrap =
          "app_root = File.expand_path(File.dirname('" + safe_path + "')); "
          "manifest_path = File.join(app_root, 'manifest.json'); "
          "manifest = RufletProd::JsonParser.parse(File.read(manifest_path)); "
          "RufletProd::Server.new(host: '0.0.0.0', port: 8550, "
          "manifest: manifest).start";
      ok = eval_source(bootstrap, path, &value, &error);
    }
    if (!ok) {
      g_last_server_error = error;
      g_warning("[ruby_runtime] startFileServer crash: %s", error.c_str());
    } else {
      g_last_server_error = "server script exited: " + value;
      g_warning("[ruby_runtime] %s", g_last_server_error.c_str());
    }
    g_server_running = false;
  }).detach();

  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_stop_file_server() {
  request_stop_server();
  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_is_file_server_running() {
  g_autoptr(FlValue) result = fl_value_new_bool(g_server_running);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_server_port() {
  g_autoptr(FlValue) result = fl_value_new_int(read_server_port());
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_last_file_server_error() {
  g_autoptr(FlValue) result = fl_value_new_string(g_last_server_error.c_str());
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                    gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(method, "eval") == 0) {
    response = handle_eval(args);
  } else if (g_strcmp0(method, "runFile") == 0) {
    response = handle_run_file(args);
  } else if (g_strcmp0(method, "reset") == 0) {
    response = handle_reset();
  } else if (g_strcmp0(method, "startFileServer") == 0) {
    response = handle_start_file_server(args);
  } else if (g_strcmp0(method, "stopFileServer") == 0) {
    response = handle_stop_file_server();
  } else if (g_strcmp0(method, "isFileServerRunning") == 0) {
    response = handle_is_file_server_running();
  } else if (g_strcmp0(method, "serverPort") == 0) {
    response = handle_server_port();
  } else if (g_strcmp0(method, "lastFileServerError") == 0) {
    response = handle_last_file_server_error();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send method call response: %s", error->message);
  }
}

}  // namespace

static void ruby_runtime_linux_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(ruby_runtime_linux_plugin_parent_class)->dispose(object);
}

static void ruby_runtime_linux_plugin_class_init(
    RubyRuntimeLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = ruby_runtime_linux_plugin_dispose;
}

static void ruby_runtime_linux_plugin_init(RubyRuntimeLinuxPlugin* self) {}

void ruby_runtime_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  RubyRuntimeLinuxPlugin* plugin = RUBY_RUNTIME_LINUX_PLUGIN(
      g_object_new(ruby_runtime_linux_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "ruby_runtime",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}

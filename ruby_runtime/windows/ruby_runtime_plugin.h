#ifndef FLUTTER_PLUGIN_RUBY_RUNTIME_PLUGIN_H_
#define FLUTTER_PLUGIN_RUBY_RUNTIME_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace ruby_runtime {

class RubyRuntimePlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);
  RubyRuntimePlugin();
  ~RubyRuntimePlugin() override;

  RubyRuntimePlugin(const RubyRuntimePlugin &) = delete;
  RubyRuntimePlugin &operator=(const RubyRuntimePlugin &) = delete;

private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

} // namespace ruby_runtime

#endif // FLUTTER_PLUGIN_RUBY_RUNTIME_PLUGIN_H_

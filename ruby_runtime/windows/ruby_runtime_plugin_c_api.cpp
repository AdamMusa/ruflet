#include "include/ruby_runtime/ruby_runtime_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ruby_runtime_plugin.h"

void RubyRuntimePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ruby_runtime::RubyRuntimePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

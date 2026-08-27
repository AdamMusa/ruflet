# frozen_string_literal: true

require "minitest/autorun"

class CrossPlatformAutostartSourceTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  ANDROID_AUTOSTART = File.read(
    File.join(ROOT, "android/src/main/kotlin/com/izeesoft/ruby_runtime/RufletRuntimeAutostart.kt"))
  ANDROID_INITIALIZER = File.read(
    File.join(ROOT, "android/src/main/kotlin/com/izeesoft/ruby_runtime/RufletRuntimeInitializer.kt"))
  ANDROID_MANIFEST = File.read(File.join(ROOT, "android/src/main/AndroidManifest.xml"))
  DESKTOP_AUTOSTART = File.read(File.join(ROOT, "desktop/ruflet_desktop_autostart.h"))
  LINUX_PLUGIN = File.read(File.join(ROOT, "linux/ruby_runtime_plugin.cc"))
  WINDOWS_PLUGIN = File.read(File.join(ROOT, "windows/ruby_runtime_plugin.cpp"))

  def test_android_starts_before_application_and_reuses_extracted_project
    assert_includes ANDROID_INITIALIZER, "androidx.startup.Initializer"
    assert_includes ANDROID_MANIFEST, "androidx.startup.InitializationProvider"
    assert_includes ANDROID_AUTOSTART, "lastUpdateTime"
    assert_includes ANDROID_AUTOSTART, "stamp.readText() == installed"
    assert_includes ANDROID_AUTOSTART, 'listOf("main.mrb", "main.rb")'
  end

  def test_desktop_starts_during_plugin_registration_without_copying_assets
    [LINUX_PLUGIN, WINDOWS_PLUGIN].each do |source|
      assert_includes source, "ruflet_autostart::on_register"
      assert_includes source, 'method_name() == "serverUrl"' if source == WINDOWS_PLUGIN
    end
    assert_includes DESKTOP_AUTOSTART, '"data" / "flutter_assets"'
    assert_includes DESKTOP_AUTOSTART, '{"main.mrb", "main.rb"}'
    refute_includes DESKTOP_AUTOSTART, "copy_file"
  end

  def test_startup_waits_run_off_platform_threads
    assert_includes ANDROID_AUTOSTART, 'Thread({ begin(appContext) }, "ruflet-runtime-autostart")'
    assert_includes DESKTOP_AUTOSTART, "std::thread(begin, start).detach()"
    assert_includes LINUX_PLUGIN, "std::thread([method_call]()"
    assert_includes WINDOWS_PLUGIN, "std::thread([shared]()"
  end
end

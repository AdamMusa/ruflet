# frozen_string_literal: true

require_relative "test_helper"

class RufletCliTemplatesTest < Minitest::Test
  def test_main_template_boots_app
    assert_includes Ruflet::CLI::MAIN_TEMPLATE, 'Ruflet.run do |page|'
    assert_includes Ruflet::CLI::MAIN_TEMPLATE, 'require "ruflet"'
  end

  def test_gemfile_template_includes_runtime_dependencies
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet_core"'
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet_server"'
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, %(gem "ruflet", ">= #{Ruflet::VERSION}")
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, %(gem "ruflet_core", ">= #{Ruflet::VERSION}")
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, %(gem "ruflet_server", ">= #{Ruflet::VERSION}")
  end

  def test_main_template_uses_bootstrapped_app_title
    assert_includes format(Ruflet::CLI::MAIN_TEMPLATE, app_title: "Demo App"), 'page.title = "Demo App"'
  end

  def test_self_contained_template_starts_runtime_without_preflight_eval
    template = File.read(File.expand_path("../../../templates/ruflet_flutter_template/lib/main.self.dart", __dir__))

    refute_includes template, "RubyRuntime.eval"
    assert_includes template, "RubyRuntime.startFileServer"
  end

  def test_self_contained_template_polls_discovered_server_port
    template = File.read(File.expand_path("../../../templates/ruflet_flutter_template/lib/main.self.dart", __dir__))

    assert_includes template, "RubyRuntime.serverPort()"
    assert_includes template, "_discoverServerPort"
  end

  def test_flutter_templates_do_not_probe_backend_health
    %w[main.self.dart main.server.dart].each do |name|
      template = File.read(File.expand_path("../../../templates/ruflet_flutter_template/lib/#{name}", __dir__))

      refute_includes template, "connection_probe"
      refute_includes template, "canConnectToPageUrl"
      refute_includes template, "/health"
    end
  end

  def test_ruby_runtime_plugins_report_bound_port_instead_of_strict_port
    root = File.expand_path("../../..", __dir__)

    %w[
      ruby_runtime/macos/Classes/RubyRuntimeMacosPlugin.m
      ruby_runtime/ios/Classes/MrubyRuntimePlugin.m
      ruby_runtime/android/src/main/cpp/ruby_runtime_jni.cpp
    ].each do |path|
      source = File.read(File.join(root, path))

      assert_includes source, "RUFLET_PORT_FILE", "#{path} should seed the port file path"
      refute_includes source, "RUFLET_STRICT_PORT", "#{path} should no longer force strict port binding"
    end
  end

  def test_flutter_templates_register_ruflet_file_picker_service_override
    %w[main.self.dart main.server.dart].each do |name|
      template = File.read(File.expand_path("../../../templates/ruflet_flutter_template/lib/#{name}", __dir__))

      assert_includes template, "import 'ruflet_file_picker_service.dart';"
      assert_includes template, "RufletFilePickerExtension(),"
    end
  end

  def test_macos_template_allows_user_selected_files_for_desktop_file_picker
    %w[DebugProfile Release].each do |name|
      entitlements = File.read(File.expand_path("../../../templates/ruflet_flutter_template/macos/Runner/#{name}.entitlements", __dir__))

      assert_includes entitlements, "com.apple.security.files.user-selected.read-write"
    end
  end

  def test_full_ruflet_client_declares_audio_recorder_permissions
    client_root = File.expand_path("../../../ruflet_client", __dir__)

    assert_includes File.read(File.join(client_root, "android/app/src/main/AndroidManifest.xml")), "android.permission.RECORD_AUDIO"
    assert_includes File.read(File.join(client_root, "ios/Runner/Info.plist")), "NSMicrophoneUsageDescription"
    assert_includes File.read(File.join(client_root, "macos/Runner/Info.plist")), "NSMicrophoneUsageDescription"

    %w[DebugProfile Release].each do |name|
      entitlements = File.read(File.join(client_root, "macos/Runner/#{name}.entitlements"))

      assert_includes entitlements, "com.apple.security.device.audio-input"
    end
  end

  def test_full_ruflet_client_declares_barometer_motion_usage_description
    client_root = File.expand_path("../../../ruflet_client", __dir__)

    assert_includes File.read(File.join(client_root, "ios/Runner/Info.plist")), "NSMotionUsageDescription"
  end

  def test_full_ruflet_client_declares_geolocator_permissions
    client_root = File.expand_path("../../../ruflet_client", __dir__)

    android_manifest = File.read(File.join(client_root, "android/app/src/main/AndroidManifest.xml"))
    assert_includes android_manifest, "android.permission.ACCESS_FINE_LOCATION"
    assert_includes android_manifest, "android.permission.ACCESS_COARSE_LOCATION"
    assert_includes File.read(File.join(client_root, "ios/Runner/Info.plist")), "NSLocationWhenInUseUsageDescription"
    assert_includes File.read(File.join(client_root, "macos/Runner/Info.plist")), "NSLocationUsageDescription"

    %w[DebugProfile Release].each do |name|
      entitlements = File.read(File.join(client_root, "macos/Runner/#{name}.entitlements"))

      assert_includes entitlements, "com.apple.security.personal-information.location"
    end
  end

  def test_full_ruflet_client_declares_desktop_file_picker_entitlements
    client_root = File.expand_path("../../../ruflet_client", __dir__)

    %w[DebugProfile Release].each do |name|
      entitlements = File.read(File.join(client_root, "macos/Runner/#{name}.entitlements"))

      assert_includes entitlements, "com.apple.security.files.user-selected.read-write"
    end
  end

  def test_full_ruflet_client_registers_audio_recorder_extension
    client_root = File.expand_path("../../../ruflet_client", __dir__)

    %w[main.dart bootstrap.dart].each do |name|
      source = File.read(File.join(client_root, "lib", name))

      assert_includes source, "package:flet_audio_recorder/flet_audio_recorder.dart"
      assert_includes source, "flet_audio_recorder.Extension(),"
    end
  end

  def test_embedded_runtime_shims_hash_dig
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    assert_includes runtime, "class Hash"
    assert_includes runtime, "def dig(key, *keys)"
  end

  def test_embedded_runtime_installs_missing_kernel_methods_with_metaprogramming
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    assert_includes runtime, "ruflet_compatibility_methods = {"
    assert_includes runtime, "__dir__: proc do"
    assert_includes runtime, "define_method(name, &implementation) unless method_defined?(name)"
  end

  def test_embedded_runtime_installs_missing_cgi_query_methods_with_metaprogramming
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    assert_includes runtime, "unescape: proc do |text|"
    assert_includes runtime, "parse: proc do |query|"
    assert_includes runtime, "define_method(name, &implementation) unless respond_to?(name)"
  end

  def test_embedded_runtime_bundle_is_generated_from_current_ruflet_sources
    root = File.expand_path("../../..", __dir__)
    command = [
      RbConfig.ruby,
      File.join(root, "tools/build_embedded_runtime.rb"),
      "--check"
    ]

    assert system(*command), "embedded runtime bundle is stale; run tools/build_embedded_runtime.rb"
  end

  def test_embedded_runtime_avoids_fiber_backed_each_with_index_enumerator
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    assert_includes runtime, "class RufletSimpleEnumerator"
    assert_includes runtime, "def each_with_index"
    assert_includes runtime, "RufletSimpleEnumerator.new(self)"
    refute_includes runtime, "@receiver.send"
  end

  def test_embedded_runtime_converts_generated_method_names_to_symbols
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    assert_includes runtime, "EMBEDDED_INSTANCE_METHODS.map { |name| name.to_sym }"
  end

  def test_embedded_runtime_exposes_window_control_methods
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    %w[wait_until_ready_to_show to_front center close destroy start_dragging start_resizing].each do |method_name|
      assert_includes runtime, "def #{method_name}(", "missing WindowControl##{method_name}"
    end
  end

  def test_embedded_runtime_exposes_page_service_helpers
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    %w[
      shared_preferences wakelock flashlight screen_brightness audio
      audio_recorder browser_context_menu window tester
      accelerometer gyroscope user_accelerometer magnetometer barometer
      shake_detector semantics_service screenshot battery connectivity
      clipboard file_picker url_launcher storage_paths share camera
      haptic_feedback geolocator permission_handler secure_storage
    ].each do |helper|
      assert_includes runtime, "def #{helper}(**props)", "missing page.#{helper}"
      assert_includes runtime, "service(:#{helper}, **props)"
    end
  end

  def test_embedded_runtime_matches_all_page_service_helpers
    root = File.expand_path("../../..", __dir__)
    page_source = File.read(File.join(root, "packages/ruflet_core/lib/ruflet_ui/ruflet/page.rb"))
    runtime = File.read(File.join(root, "ruby_runtime/shared/embedded_ruflet_runtime.rb"))

    page_source.scan(/^    def (\w+)\(\*\*props\)\n(.*?)^    end/m).each do |helper, body|
      next unless body.include?("service(:")

      assert_includes runtime, "def #{helper}(**props)", "missing page.#{helper}"
    end
  end

  def test_ruby_runtime_builds_and_initializes_mruby_metaprog
    root = File.expand_path("../../..", __dir__)
    metaprog_source = "mruby-metaprog/src/metaprog.c"

    %w[ios macos].each do |platform|
      assert_path_exists File.join(root, "ruby_runtime/#{platform}/mruby_src/mrbgems/#{metaprog_source}")
    end

    assert_includes File.read(File.join(root, "ruby_runtime/android/src/main/cpp/CMakeLists.txt")), metaprog_source
    assert_includes File.read(File.join(root, "ruby_runtime/ios/ruby_runtime.podspec")), metaprog_source
    assert_includes File.read(File.join(root, "ruby_runtime/macos/ruby_runtime.podspec")), metaprog_source

    %w[
      ruby_runtime/shared/mruby_gems_init.c
      ruby_runtime/ios/Classes/mruby_gems_init.c
      ruby_runtime/macos/Classes/mruby_gems_init.c
    ].each do |path|
      source = File.read(File.join(root, path))
      assert_includes source, "void mrb_mruby_metaprog_gem_init(mrb_state *mrb);"
      assert_includes source, "mrb_mruby_metaprog_gem_init(mrb);"
    end
  end

  def test_embedded_runtime_matches_service_helper_signatures
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    assert_includes runtime, "def share_text(\n      text = nil,"
    assert_includes runtime, "def share_uri(\n      uri = nil,"
    assert_includes runtime, "def share_files(\n      files = nil,"
    assert_includes runtime, "def compact_service_args(hash)"
    assert_includes runtime, "def normalize_share_file(file)"
    assert_includes runtime, "compact_service_args(\n          \"dialog_title\" => dialog_title"
  end

  def test_embedded_file_picker_uses_persistent_page_service
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    assert_includes runtime, "picker = service(:file_picker)"
    refute_includes runtime, "picker = build_widget(:file_picker)"
  end

  def test_embedded_runtime_has_sleep_shim_for_threaded_samples
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    assert_includes runtime, "def sleep(seconds = nil)"
    assert_includes runtime, "::IO.select(nil, nil, nil, duration)"
  end

  def test_embedded_runtime_does_not_start_timeout_thread_with_fake_thread
    runtime = File.read(File.expand_path("../../../ruby_runtime/shared/embedded_ruflet_runtime.rb", __dir__))

    assert_includes runtime, "RUFLET_EMBEDDED_FAKE_THREAD = true"
    assert_includes runtime, "def embedded_async_timeout_available?"
    assert_includes runtime, "if embedded_async_timeout_available? && !timeout.nil?"
  end
end

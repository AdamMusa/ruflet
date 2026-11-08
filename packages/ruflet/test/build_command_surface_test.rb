# frozen_string_literal: true

require_relative "test_helper"
require "digest"

# Pins what code outside build_command.rb reaches through BuildCommand, so
# moving its implementation into cli/build/ cannot drop or reshape a method or
# constant that tests, the Rails tasks or the other commands use.
class RufletCliBuildCommandSurfaceTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  # name, visibility, parameters (kind:name), as BuildCommand defined them
  # before the split.
  METHODS = <<~TABLE.lines.map { |line| line.strip.split(/\s+/, 3) }.freeze
    command_build                                public  req:args
    command_install                              public  req:args
    android_main_activity_paths                  private req:client_dir
    android_signing_properties                   private -
    announce_asset_configuration                 private req:asset_flags
    apple_build_path                             private req:existing_path
    apple_info_plist_paths                       private req:client_dir
    apply_android_activity_base                  private req:client_dir req:extension_keys
    apply_android_metadata                       private req:client_dir req:metadata
    apply_android_service_permissions            private req:client_dir req:entries
    apply_android_signing_config                 private req:client_dir req:platform key:verbose
    apply_apple_service_usage_descriptions       private req:path req:entries req:usage_keys req:managed_keys
    apply_build_config                           private req:client_dir opt:config
    apply_ios_metadata                           private req:client_dir req:metadata
    apply_ios_service_usage_descriptions         private req:client_dir req:entries
    apply_ios_signing_team                       private req:client_dir req:config
    apply_linux_metadata                         private req:client_dir req:metadata
    apply_macos_metadata                         private req:client_dir req:metadata
    apply_macos_service_permissions              private req:client_dir req:entries
    apply_mobile_package_name                    private req:client_dir req:metadata keyreq:platform keyreq:tools key:verbose
    apply_native_service_permissions             private req:client_dir req:config
    apply_pubspec_metadata                       private req:client_dir req:metadata
    apply_service_extension_config               private req:client_dir opt:config key:self_contained
    apply_web_metadata                           private req:client_dir req:metadata
    apply_windows_metadata                       private req:client_dir req:metadata
    bootstrap_flutter_client_template            private -
    build_client_metadata                        private req:config req:client_dir
    build_log                                    private req:verbose req:message
    build_note                                   private req:message
    build_tool_env                               private req:env req:platform opt:client_dir
    clear_flutter_build_state                    private req:client_dir key:verbose
    clear_stale_platform_outputs                 private req:client_dir req:platform key:verbose
    client_entrypoint_paths                      private req:client_dir
    configure_android_runtime                    private req:client_dir keyreq:platform keyreq:self_contained key:verbose
    configure_client_runtime_mode                private req:client_dir keyreq:self_contained key:verbose
    configure_full_runtime_distribution          private req:config req:platform key:verbose
    configure_ios_scene_delegate                 private req:client_dir
    configure_native_apple_runtime               private req:client_dir keyreq:platform keyreq:self_contained key:config key:verbose
    configure_platform_autostart                 private req:client_dir req:platform key:verbose
    configured_backend_url                       private req:config
    configured_extension_keys                    private req:config
    configured_service_entries                   private req:config
    configured_service_entries_with_requirements private req:config
    copy_full_runtime_gem_files                  private req:source req:destination req:files keyreq:full_name
    detect_flutter_client_dir                    private -
    discover_registered_external_extension_names private req:client_dir
    embedded_mrbc_path                           private -
    embedded_runtime_profile                     private -
    ensure_cocoapods_install                     private req:client_dir req:platform_dir req:env key:verbose
    ensure_flutter_client_dir                    private key:verbose
    ensure_flutter_platform_artifacts            private req:client_dir req:platform req:env req:flutter key:verbose
    ensure_native_build_dependencies             private req:client_dir req:platform req:env key:verbose
    ensure_pubspec_block                         private req:path req:block
    ensure_ruflet_build_assets                   private key:force key:verbose
    explicit_local_ruby_runtime_path             private -
    export_platform_build_outputs                private req:client_dir req:platform key:verbose
    exports_for                                  private req:platform
    external_extension_dependency                private req:source
    external_extension_entries                   private req:config
    extract_option_value!                        private req:args rest:flags
    file_uri_for                                 private req:path
    first_defined                                private req:hash rest:keys
    first_present                                private rest:values
    flutter_build_command                        private req:platform
    flutter_precache_flags                       private req:platform
    flutter_target_entrypoint                    private req:client_dir keyreq:self_contained
    full_runtime_device_only?                    private -
    hidden_flutter_client_dir                    private opt:root
    html_escape                                  private req:value
    humanize_name                                private req:name
    include_project_asset_file?                  private req:relative
    indent_pubspec_sequences                     private req:content
    inferred_install_platform                    private -
    insert_missing_extension                     private req:content req:extension_line
    insert_missing_import                        private req:content req:import_line
    install_apple_pod_shim                       private req:client_dir req:env
    install_platform_for_device                  private req:device_id
    install_sync_platforms                       private req:platform
    install_tool_env                             private req:env req:client_dir
    ios_app_signed?                              private req:app_path
    ios_device_build_needs_codesign_flag?        private req:platform req:build_args
    ios_signing_team                             private req:config
    ios_simulator_device_id?                     private req:device_id
    key_defined?                                 private req:hash req:key
    load_client_pubspec                          private req:client_dir
    load_ruflet_config                           private -
    managed_extension_state_path                 private req:client_dir
    managed_external_extension_names             private req:client_dir
    normalize_apple_bundle_identifier            private req:value
    normalize_bundle_identifier                  private req:value
    normalize_bundle_prefix                      private req:value
    normalize_extension_key                      private req:value
    normalize_package_name                       private req:value
    normalized_runtime_platform                  private req:platform
    package_full_runtime_gems                    private req:project_root req:destination_root req:client_dir key:verbose
    path_from_file_uri                           private req:uri
    platform_build_config                        private req:config req:platform
    precompile_lite_runtime_project              private req:destination_root key:verbose
    prepare_flutter_client                       private req:client_dir keyreq:platform keyreq:tools keyreq:config key:self_contained key:verbose
    project_android_key_properties_path          private -
    project_asset_relative_paths                 private -
    prune_client_main                            private req:path req:selected_aliases
    prune_client_pubspec                         private req:path req:selected_packages
    prune_external_extension_registrations       private req:path req:package_names
    prune_full_runtime_bundle_cache              private req:bundle_path
    read_text_file                               private req:path
    refresh_hidden_flutter_client_template       private req:client_dir key:verbose
    refresh_managed_client_template_files        private req:client_dir key:platform key:verbose
    remove_local_ruby_runtime_override           private req:client_dir key:verbose
    remove_native_apple_renderer_integration     private req:client_dir keyreq:platform key:verbose
    remove_plist_dictionary_boolean              private req:path req:dictionary_key req:key
    remove_plist_value                           private req:path req:key
    remove_self_contained_project_assets         private req:client_dir key:verbose
    replace_in_file                              private req:path req:pattern req:replacement
    replace_plist_value                          private req:path req:key req:value
    resolve_working_pod_executable               private -
    restore_flutter_apple_host                   private req:client_dir req:platform key:verbose
    ruby_runtime_dependency                      private opt:current_dependency
    run_external_command                         private req:env rest:cmd keyreq:chdir key:unbundled
    run_full_runtime_gem_packager                private req:bundle_env keyreq:gemfile keyreq:lockfile keyreq:bundle_path keyreq:project_root
    secret_project_asset?                        private req:relative
    self_contained_project_asset_dirs            private opt:client_dir
    self_contained_project_name                  private -
    self_contained_project_path?                 private req:relative
    set_android_meta_data                        private req:manifest req:name req:value
    set_plist_value                              private req:plist req:key req:type req:value
    skip_project_asset_directory?                private req:relative
    source_checkout_ruby_runtime_path            private -
    stage_ios_simulator_ruby_runtime             private req:client_dir req:build_args key:verbose
    strip_native_apple_xcode_project             private req:client_dir req:platform
    sync_built_outputs_for_install               private req:client_dir key:platform key:verbose
    sync_client_extension_dependencies           private req:path req:selected_packages
    sync_client_main_extensions                  private req:path req:selected_aliases
    sync_client_metadata                         private req:client_dir opt:config key:verbose
    sync_client_package_directories              private req:client_dir req:selected_packages
    sync_client_pubspec_for_runtime_mode         private req:client_dir keyreq:self_contained
    sync_external_extension_dependencies         private req:pubspec_path req:entries key:managed_names
    sync_external_extension_registrations        private req:path req:entries
    sync_self_contained_project_assets           private req:client_dir key:verbose
    template_client_entrypoint_path              private req:name
    template_client_pubspec_dependencies         private -
    unbundled_command_env                        private req:env
    update_pubspec_nested_value                  private req:path req:block req:section req:key req:value
    update_pubspec_value                         private req:path req:block req:key req:value key:multiple
    upsert_android_metadata                      private req:path req:name req:value
    upsert_plist_boolean                         private req:path req:key req:value
    upsert_plist_dictionary_boolean              private req:path req:dictionary_key req:key req:value
    upsert_plist_string                          private req:path req:key req:value
    user_build_root                              private opt:root
    valid_flutter_client_root?                   private req:path
    validate_flutter_extension_selection         private req:client_dir
    validate_full_runtime_in_process_transport   private req:bundle_path
    validate_install_artifacts                   private req:client_dir keyreq:platform keyreq:device_id
    validate_ios_simulator_install_artifacts     private req:client_dir
    validate_local_ruflet_packages               private req:client_dir
    validate_mobile_app_identity                 private req:metadata keyreq:platform
    validate_template_ruflet_source_integrity    private req:template_root key:verbose
    vendor_full_runtime_path_gems                private req:bundle_env keyreq:bundle_path keyreq:project_root
    verify_android_generated_assets              private req:client_dir req:asset_flags req:platform key:verbose
    windows_string_escape                        private req:value
    write_embedded_runtime_manifest              private req:project_root req:destination_root keyreq:profile keyreq:platform
    write_managed_external_extension_names       private req:client_dir req:names
    write_pubspec_yaml                           private req:path req:data
    write_text_file                              private req:path req:content
    xcode_escape                                 private req:value
    xml_escape                                   private req:value
  TABLE

  # name, first 16 hex digits of SHA-256(Marshal.dump(value))
  CONSTANTS = <<~TABLE.lines.map(&:split).freeze
    ANDROID_SERVICE_PERMISSIONS        75eb9dd525fbd95d
    ANDROID_SIGNING_KEYS               ad2f68af921c403c
    CLIENT_EXTENSION_MAP               72c3a63ad1c67cdf
    EMBEDDED_RUNTIME_PROFILES          9b478592feb77393
    EXTENSION_REQUIRED_SERVICES        6764ae5bc3246057
    FRAGMENT_ACTIVITY_EXTENSIONS       6ddb7d00e7da6d66
    FULL_RUNTIME_BUNDLE_SCHEMA         9e50e62240c04e0b
    FULL_RUNTIME_MANIFEST              c9201d2a4b36dd71
    IOS_SERVICE_USAGE_KEYS             8dc84b464f241dbe
    MACOS_SERVICE_ENTITLEMENTS         ba646837c9d48112
    MACOS_SERVICE_USAGE_KEYS           eb9481eda35f0d35
    MANAGED_ANDROID_PERMISSIONS        60bb9b1601c6ee46
    MANAGED_EXTENSION_STATE_PATH       6e6f4cbaf6d8a6c2
    MANAGED_IOS_USAGE_KEYS             65a5c45b30cf8640
    MANAGED_MACOS_SERVICE_ENTITLEMENTS 9925a27cb3bb6c18
    MANAGED_MACOS_USAGE_KEYS           d18283b50d11c284
    PLATFORM_ASSET_SUPPORT             dc0d652efaa28f7d
    PROTECTED_SERVICE_EXTENSIONS       832b66602deffcc9
    PUBLISHED_RUBY_RUNTIME_CONSTRAINT  463c15fc9e0a3584
    RUFLET_SOURCE_IGNORED_DIRECTORIES  f82bb4aee6c1982e
    RUFLET_SOURCE_IGNORED_FILES        312fd2b8ec99c6e0
    RUFLET_SOURCE_INTEGRITY_PATH       b265cb8ad334198f
    RUNTIME_RESOLVED_BACKEND_PLATFORMS 89ff4aa03d1973f3
    SECRET_ASSET_BASENAMES             d43911ff653e5abe
    SECRET_ASSET_EXTENSIONS            95d9dd0c0ba39467
    SELF_CONTAINED_PROJECT_DIRECTORIES 88674f0e58bb3d92
    SELF_CONTAINED_PROJECT_ENTRYPOINT  410689a89cce8718
  TABLE

  def build_command
    Ruflet::CLI::BuildCommand
  end

  def test_every_method_keeps_its_visibility_and_parameters
    METHODS.each do |name, visibility, parameters|
      if visibility == "public"
        assert build_command.public_method_defined?(name), "#{name} must stay public"
      else
        assert build_command.private_method_defined?(name), "#{name} must stay private"
      end
      assert_equal parameters, signature(build_command.instance_method(name)), "#{name} parameters"
    end
  end

  def test_every_method_is_implemented_by_the_build_command
    METHODS.each do |name, _visibility, _parameters|
      owner = build_command.instance_method(name).owner
      assert build_implementation?(owner), "#{name} resolves to #{owner}, outside the build command"
    end
  end

  def test_the_cli_and_includers_resolve_the_same_implementation
    METHODS.each do |name, _visibility, _parameters|
      expected = build_command.instance_method(name).owner
      assert Ruflet::CLI.respond_to?(name, true), "Ruflet::CLI must respond to #{name}"
      assert_equal expected, Ruflet::CLI.singleton_class.instance_method(name).owner, "Ruflet::CLI.#{name}"
      assert_equal expected, DummyBuilder.instance_method(name).owner, "#{name} through include"
    end
    assert Ruflet::CLI.respond_to?(:command_build)
    assert Ruflet::CLI.respond_to?(:command_install)
  end

  def test_every_constant_keeps_its_value
    CONSTANTS.each do |name, digest|
      assert build_command.const_defined?(name), "BuildCommand::#{name} must stay reachable"
      value = build_command.const_get(name)
      assert_equal digest, Digest::SHA256.hexdigest(Marshal.dump(value))[0, 16], "BuildCommand::#{name} value"
      assert_same value, DummyBuilder.const_get(name), "#{name} through include"
    end
  end

  def test_source_checkout_runtime_is_the_repository_ruby_runtime
    expected = File.expand_path("../../../ruby_runtime", __dir__)
    skip "not running from a source checkout" unless File.file?(File.join(expected, "pubspec.yaml"))

    assert_equal expected, DummyBuilder.new.send(:source_checkout_ruby_runtime_path)
  end

  private

  def signature(method)
    parameters = method.parameters
    return "-" if parameters.empty?

    parameters.map { |kind, name| name ? "#{kind}:#{name}" : kind.to_s }.join(" ")
  end

  def build_implementation?(owner)
    owner == Ruflet::CLI::BuildCommand || owner.name.to_s.start_with?("Ruflet::CLI::Build::")
  end
end

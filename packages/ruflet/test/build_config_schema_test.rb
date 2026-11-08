# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "yaml"

# The schema lists every ruflet.yaml and services.yaml key Ruflet reads, so
# `ruflet check` (CLI-22) can report the ones it does not know. These tests
# keep it complete: every key the build reads, every key Ruflet itself writes
# into a project, and every key the compatibility fixtures use is registered.
class RufletCliBuildConfigSchemaTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  FIXTURES = File.expand_path("compat/fixtures", __dir__)
  RAILS_LIB = File.expand_path("../../ruflet_rails/lib", __dir__)

  # A config Hash that logs the dotted path of every key it is asked for.
  class RecordingHash < Hash
    def self.wrap(value, path, log)
      value.is_a?(Hash) ? new(value, path, log) : value
    end

    def initialize(source, path, log)
      super()
      @path = path
      @log = log
      source.each { |key, value| store(key, self.class.wrap(value, path + [key.to_s], log)) }
    end

    def [](key)
      record(key)
      super
    end

    def key?(key)
      record(key)
      super
    end

    def fetch(key, *args, &block)
      record(key)
      super
    end

    def dig(key, *rest)
      record(key)
      super
    end

    private

    def record(key)
      @log << (@path + [key.to_s]).join(".")
    end
  end

  def schema
    Ruflet::CLI::Build::ConfigSchema
  end

  def test_register_needs_a_known_parent_map_and_a_known_type_and_file
    registry = schema::Registry.new
    registry.register("app", type: :map, feature: :test)
    registry.register("app.name", type: :string, feature: :test)

    assert registry.known?("app")
    assert registry.known?("app.name")
    refute registry.known?("app.other")
    refute registry.known?("app.name", file: "services.yaml")
    assert_raises(ArgumentError) { registry.register("build.splash", type: :path, feature: :test) }
    assert_raises(ArgumentError) { registry.register("app.name.first", type: :string, feature: :test) }
    assert_raises(ArgumentError) { registry.register("app.size", type: :float, feature: :test) }
    assert_raises(ArgumentError) { registry.register("app.size", type: :integer, feature: :test, files: ["app.yaml"]) }
    assert_raises(ArgumentError) { registry.register("app.Size", type: :integer, feature: :test) }
  end

  def test_repeating_a_key_is_harmless_but_changing_its_type_is_not
    registry = schema::Registry.new
    first = registry.register("services", type: :list, feature: :services)

    assert_same first, registry.register("services", type: :list, feature: :other)
    assert_raises(ArgumentError) { registry.register("services", type: :map, feature: :other) }
    assert_equal [first], registry.keys
    assert_equal :services, registry.lookup("services").feature
  end

  def test_platform_keys_accept_every_section_spelling
    registry = schema::Registry.new
    %w[build assets].each { |root| registry.register(root, type: :map, feature: :test) }
    %w[ios macos].each do |platform|
      [nil, "build", "assets"].each do |root|
        registry.register([root, platform].compact.join("."), type: :map, feature: :test)
      end
    end
    registry.register_platform("team_id", platforms: %w[ios], type: :string, feature: :signing)

    assert registry.known?("ios.team_id")
    assert registry.known?("build.ios.team_id")
    assert registry.known?("assets.ios.team_id")
    refute registry.known?("macos.team_id")
  end

  def test_keys_can_be_listed_per_file_and_feature
    services_yaml = schema.keys(file: "services.yaml").map(&:path)

    assert_includes services_yaml, "services"
    assert_includes services_yaml, "app.package_name"
    refute_includes services_yaml, "extensions"
    assert_includes schema.keys(feature: :extensions).map(&:path), "extensions"
    assert(schema.keys.all?(&:frozen?))
  end

  def test_every_key_the_build_reads_is_registered
    log = []
    builder = DummyBuilder.new
    builder.define_singleton_method(:platform_build_config) do |config, platform|
      RecordingHash.new(super(config, platform), [platform.to_s], log)
    end
    record = ->(config) { RecordingHash.new(config, [], log) }
    empty_sections = { "build" => {}, "assets" => {}, "app" => {}, "windows" => { "theme_color" => "#FFFFFF" } }

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(client_dir, "assets"))
      File.write(File.join(client_dir, "pubspec.yaml"), "name: client\n")
      File.write(File.join(client_dir, "assets", "splash.png"), "png")
      File.write(File.join(client_dir, "assets", "icon.png"), "png")
      %w[ios macos].each do |platform|
        plist = File.join(client_dir, platform, "Runner", "Info.plist")
        FileUtils.mkdir_p(File.dirname(plist))
        File.write(plist, "<plist>\n<dict>\n</dict>\n</plist>\n")
      end
      network = { "ios" => { "local_network" => true }, "macos" => { "local_network" => true } }
      original_env = %w[RUFLET_FULL_RUNTIME_PATH RUFLET_CONFIG].to_h { |name| [name, ENV.delete(name)] }

      Dir.chdir(dir) do
        capture_io do
          builder.send(:configured_backend_url, record.call(empty_sections))
          builder.send(:build_client_metadata, record.call(empty_sections), client_dir)
          builder.send(:ios_signing_team, record.call(empty_sections))
          builder.send(:apply_build_config, client_dir, record.call(empty_sections))
          %w[ios macos].each do |platform|
            builder.send(:configure_native_apple_runtime, client_dir,
              platform: platform, self_contained: false, config: record.call(network))
          end
          builder.send(:configure_full_runtime_distribution, record.call(empty_sections), "ios")
          builder.send(:configured_service_entries_with_requirements, record.call(empty_sections))
          builder.send(:configured_extension_keys, record.call(empty_sections))
          builder.send(:external_extension_entries, record.call(empty_sections))
        end
      end
    ensure
      original_env&.each { |name, value| ENV[name] = value if value }
    end

    read = log.uniq.sort
    assert_operator read.size, :>, 150, "the probe should reach the asset, identity and platform readers"
    assert_empty read.reject { |path| schema.known?(path) }, "keys the build reads but the schema does not list"
  end

  def test_every_key_ruflet_writes_into_a_project_is_registered
    Dir.mktmpdir do |dir|
      Ruflet::CLI.send(:write_default_ruflet_config, dir, "my_app")
      assert_registered(YAML.safe_load(File.read(File.join(dir, "ruflet.yaml"))), "ruflet.yaml")
      assert_registered(YAML.safe_load(File.read(File.join(dir, "services.yaml"))), "services.yaml")
    end

    skip "ruflet_rails is not beside this package" unless File.directory?(RAILS_LIB)

    require File.join(RAILS_LIB, "ruflet/rails/install_support")
    require File.join(RAILS_LIB, "ruflet/rails/configuration")
    assert_registered(YAML.safe_load(Ruflet::Rails::InstallSupport.default_ruflet_yaml(app_name: "shop")), "ruflet.yaml")
    rails = Ruflet::Rails::Configuration.new
    Ruflet::Rails::Configuration.public_instance_methods(false).grep(/\A[a-z_]+=\z/).each { |setter| rails.public_send(setter, "x") }
    rails.services = ["camera"]
    rails.extensions = ["charts"]
    assert_registered(rails.to_ruflet_yaml_hash, "ruflet.yaml")
  end

  def test_every_key_the_compatibility_fixtures_use_is_registered
    files = Dir.glob(File.join(FIXTURES, "**", "{ruflet,services}.yaml"))
    refute_empty files

    files.each do |path|
      assert_registered(YAML.safe_load(File.read(path)), File.basename(path), path)
    end
  end

  private

  def assert_registered(data, file, label = file, prefix = [])
    data.each do |key, value|
      path = (prefix + [key.to_s]).join(".")
      entry = schema.lookup(path, file: file)
      assert entry, "#{label}: #{path} is not in the config schema"
      assert_registered(value, file, label, prefix + [key.to_s]) if value.is_a?(Hash) && entry.type == :map
    end
  end
end

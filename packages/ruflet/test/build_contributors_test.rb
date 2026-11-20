# frozen_string_literal: true

require_relative "test_helper"

class RufletCliBuildContributorsTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  # The order prepare_flutter_client has always written the client's
  # configuration in. Later features insert themselves with before:/after:.
  BUILT_IN = %i[
    template_refresh
    apple_host
    app_identity
    protected_services
    signing
    runtime_mode
    extensions
    assets
  ].freeze

  def contributors
    Ruflet::CLI::Build::Contributors
  end

  def test_built_in_contributors_run_in_the_original_order
    assert_equal BUILT_IN, contributors.names
  end

  def test_every_handler_is_a_private_build_method
    contributors.entries.each do |entry|
      assert Ruflet::CLI::BuildCommand.private_method_defined?(entry.handler), entry.handler.to_s
      assert Ruflet::CLI.respond_to?(entry.handler, true), entry.handler.to_s
      refute Ruflet::CLI.respond_to?(entry.handler), "#{entry.handler} must stay private"
    end
  end

  def test_the_global_list_cannot_be_edited_through_entries
    assert_raises(FrozenError) { contributors.entries << :anything }
    assert_equal BUILT_IN, contributors.names
  end

  def test_register_appends_or_places_relative_to_an_existing_contributor
    registry = contributors::Registry.new
    registry.register(:first, :contribute_first)
    registry.register(:last, :contribute_last)
    registry.register(:middle, :contribute_middle, after: :first)
    registry.register(:start, :contribute_start, before: :first)

    assert_equal %i[start first middle last], registry.names
    assert_equal :contribute_middle, registry.entries[2].handler
  end

  def test_register_rejects_conflicts_and_ignores_an_identical_repeat
    registry = contributors::Registry.new
    registry.register(:assets, :contribute_assets)

    assert_same registry.entries.first, registry.register("assets", "contribute_assets")
    assert_equal %i[assets], registry.names
    assert_raises(ArgumentError) { registry.register(:assets, :contribute_other) }
    assert_raises(ArgumentError) { registry.register(:overlay, :contribute_overlay, after: :missing) }
    assert_raises(ArgumentError) { registry.register(:overlay, :contribute_overlay, before: :assets, after: :assets) }
    assert_equal %i[assets], registry.names
  end

  def test_prepare_runs_each_contributor_with_the_build_and_stops_at_the_first_refusal
    builder = DummyBuilder.new
    calls = []
    commands = []
    builds = []
    BUILT_IN.each do |name|
      builder.define_singleton_method(:"contribute_#{name}") do |build|
        calls << name
        builds << build
        name != :runtime_mode
      end
    end
    builder.define_singleton_method(:system) { |*args, **_kwargs| commands << args; true }

    Dir.mktmpdir do |dir|
      ok = builder.send(
        :prepare_flutter_client, dir,
        platform: "apk", tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: { "app" => {} }, self_contained: true, verbose: false
      )

      refute ok
      assert_equal %i[template_refresh apple_host app_identity protected_services signing runtime_mode], calls
      assert_empty commands, "no tool runs after a contributor stops the build"
      assert_equal 1, builds.uniq.size, "every contributor shares one build context"
      build = builds.first
      assert_equal dir, build.client_dir
      assert_equal "apk", build.platform
      assert_equal({ "app" => {} }, build.config)
      assert build.self_contained
      refute build.verbose
    end
  end

  def test_a_registered_contributor_runs_at_its_place_and_shares_the_build_state
    builder = DummyBuilder.new
    registry = contributors::Registry.new
    contributors.entries.each { |entry| registry.register(entry.name, entry.handler) }
    registry.register(:feature, :contribute_feature, after: :assets)
    builder.define_singleton_method(:build_contributors) { registry.entries }

    calls = []
    BUILT_IN.each do |name|
      builder.define_singleton_method(:"contribute_#{name}") do |build|
        calls << name
        build.asset_flags = { has_icon: false, has_splash: false } if name == :assets
        true
      end
    end
    seen = nil
    builder.define_singleton_method(:contribute_feature) do |build|
      calls << :feature
      seen = build.asset_flags
      false
    end

    Dir.mktmpdir do |dir|
      refute builder.send(
        :prepare_flutter_client, dir,
        platform: "web", tools: { env: {} }, config: {}, self_contained: false, verbose: false
      )
    end

    assert_equal BUILT_IN + [:feature], calls
    assert_equal({ has_icon: false, has_splash: false }, seen)
  end

  # No golden sees the next two, so they are pinned here. A client with no
  # template to refresh from keeps building; only a failed refresh stops it.
  def test_template_refresh_stops_the_build_only_when_the_refresh_fails
    builder = DummyBuilder.new
    build = Ruflet::CLI::Build::Context.new(client_dir: "/client", platform: "apk", verbose: false)

    { nil => true, true => true, false => false }.each do |refreshed, continues|
      builder.define_singleton_method(:refresh_managed_client_template_files) { |*_args, **_kwargs| refreshed }
      assert_equal continues, builder.send(:contribute_template_refresh, build), "refresh returned #{refreshed.inspect}"
    end
  end

  # prepare_flutter_client has always recorded the runtime mode in
  # @ruflet_self_contained_build, which apply_service_extension_config takes
  # as its default.
  def test_extensions_records_whether_the_build_is_self_contained
    builder = DummyBuilder.new
    seen = []
    builder.define_singleton_method(:apply_service_extension_config) do |_client_dir, _config = {}, self_contained: @ruflet_self_contained_build|
      seen << self_contained
      %w[camera]
    end

    [true, false].each do |self_contained|
      build = Ruflet::CLI::Build::Context.new(
        client_dir: "/client", platform: "apk", config: {}, self_contained: self_contained, verbose: false
      )
      assert builder.send(:contribute_extensions, build)
      assert_equal self_contained, builder.instance_variable_get(:@ruflet_self_contained_build)
      assert_equal %w[camera], build.extension_keys
    end
    assert_equal [true, false], seen
  end
end

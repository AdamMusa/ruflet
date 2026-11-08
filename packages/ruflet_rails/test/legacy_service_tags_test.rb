# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"

# Transformer::SERVICE_TAGS and ::SERVICE_TYPES, which ruflet_rails 0.0.23
# shipped and #50 removed, are back as deprecated constants built from the
# registry Transformer.service_tag? reads.
class RufletLegacyServiceTagsTest < Minitest::Test
  Transformer = Ruflet::Rails::HtmlDsl::Transformer

  # Transformer::SERVICE_TAGS as ruflet_rails 0.0.23 shipped it, in its order.
  V0_0_23_SERVICE_TAGS = %w[
    audio audio-recorder barometer battery clipboard connectivity
    file-picker flashlight geolocator gyroscope accelerometer magnetometer
    haptic-feedback permission-handler screen-brightness secure-storage
    shake-detector share shared-preferences storage-paths url-launcher
    user-accelerometer wakelock semantics-service
  ].freeze

  PACKAGE_LIBS = %w[ruflet_core ruflet_server ruflet ruflet_rails].map do |package|
    File.expand_path("../../#{package}/lib", __dir__)
  end.freeze

  class RecordingHandlers
    def navigate(*) = nil
    def action(**) = nil
    def submit_form(*) = nil
    def field_changed(*) = nil
    def service(*) = nil
  end

  def legacy_constants
    # Minitest turns deprecation warnings on; these tests check values.
    previous = Warning[:deprecated]
    Warning[:deprecated] = false
    [Transformer::SERVICE_TAGS, Transformer::SERVICE_TYPES]
  ensure
    Warning[:deprecated] = previous
  end

  def registry_names
    factory = Ruflet::UI::ControlFactory
    (factory::CLASS_MAP.keys + factory::EXTENSION_CLASS_MAP.keys).map(&:to_s).uniq
  end

  # Runs `script` in a fresh Ruby with only the package lib directories on the
  # load path, so nothing (ruflet_core included) is loaded until it asks.
  def run_ruby(script)
    includes = PACKAGE_LIBS.flat_map { |lib| ["-I", lib] }
    out, err, status = Open3.capture3(RbConfig.ruby, *includes, "-e", script)
    assert status.success?, "child Ruby failed:\n#{err}"
    JSON.parse(out.lines.last)
  end

  def test_constants_keep_the_0_0_23_shape_order_and_entries
    tags, types = legacy_constants

    assert_kind_of Array, tags
    assert_predicate tags, :frozen?
    assert tags.all?(&:frozen?)
    assert_kind_of Set, types
    assert_predicate types, :frozen?
    assert types.all?(&:frozen?)

    # Every 0.0.23 entry, in 0.0.23's order, then the services added since.
    assert_equal V0_0_23_SERVICE_TAGS, tags.first(V0_0_23_SERVICE_TAGS.length)
    added = tags.drop(V0_0_23_SERVICE_TAGS.length)
    %w[browser-context-menu interstitial-ad window].each { |tag| assert_includes added, tag }

    # SERVICE_TYPES starts with SERVICE_TAGS, underscored and in that order,
    # as 0.0.23's did; lookups written against it keep their answers.
    assert_equal tags.map { |tag| tag.tr("-", "_") }, types.to_a.first(tags.length)
    assert_includes types, "battery"
    assert_includes types, "audio_recorder"
  end

  def test_service_tags_name_each_service_once
    tags, = legacy_constants

    # The compact registry spellings (filepicker, audiorecorder) are not
    # listed next to file-picker and audio-recorder.
    assert_equal tags.length, tags.map { |tag| tag.delete("-") }.uniq.length
    %w[filepicker audiorecorder hapticfeedback interstitialad].each { |tag| refute_includes tags, tag }

    # And no service is left out: every registered name service_tag? accepts
    # is one of the listed tags, or a compact spelling of one.
    accepted = registry_names.select { |name| Transformer.service_tag?(name.tr("_", "-")) }
    assert_equal accepted.map { |name| name.delete("_") }.uniq.sort,
                 tags.map { |tag| tag.delete("-") }.sort
  end

  def test_constants_agree_with_service_tag
    tags, types = legacy_constants

    # SERVICE_TYPES is what 0.0.23's transformer checked a tag against, so it
    # answers like service_tag? for every registered name, compact ones too.
    registry_names.each do |name|
      assert_equal Transformer.service_tag?(name.tr("_", "-")), types.include?(name),
                   "SERVICE_TYPES.include?(#{name.inspect}) disagrees with service_tag?"
    end
    assert_includes types, "filepicker"
    %w[camera video picker date-picker column text].each do |tag|
      refute_includes tags, tag
      refute_includes types, tag.tr("-", "_")
    end

    tags.each do |tag|
      result = Transformer.new(handlers: RecordingHandlers.new).transform("<#{tag}></#{tag}>")
      assert_equal 1, result.services.length, "<#{tag}> should mount as a service"
      assert_empty result.controls, "<#{tag}> should not render inline"
    end
  end

  def test_constants_warn_only_when_deprecation_warnings_are_on
    previous = Warning[:deprecated]

    # Ruby's default: existing apps reading the constants see no new output.
    Warning[:deprecated] = false
    assert_output(nil, "") { [Transformer::SERVICE_TAGS, Transformer::SERVICE_TYPES] }

    Warning[:deprecated] = true
    _, err = capture_io { [Transformer::SERVICE_TAGS, Transformer::SERVICE_TYPES] }
    assert_match(/Transformer::SERVICE_TAGS is deprecated/, err)
    assert_match(/Transformer::SERVICE_TYPES is deprecated/, err)
  ensure
    Warning[:deprecated] = previous
  end

  # The first read is the one that runs the autoload. It warns once, like any
  # later read, and only when deprecation warnings are on.
  def test_first_read_warns_once_per_constant
    script = lambda do |deprecated, first, second|
      <<~RUBY
        require "json"
        require "ruflet_rails"
        warnings = []
        Warning.singleton_class.prepend(Module.new do
          define_method(:warn) { |message, *, **| warnings << message if message.include?("SERVICE_T") }
        end)
        Warning[:deprecated] = #{deprecated}
        transformer = Ruflet::Rails::HtmlDsl::Transformer
        transformer.const_get(:#{first})
        first = warnings.length
        transformer.const_get(:#{second})
        puts JSON.generate("first" => first, "second" => warnings.length - first)
      RUBY
    end

    # Whichever constant is read first runs the autoload for both.
    assert_equal({ "first" => 1, "second" => 1 }, run_ruby(script.call(true, "SERVICE_TAGS", "SERVICE_TYPES")))
    assert_equal({ "first" => 1, "second" => 1 }, run_ruby(script.call(true, "SERVICE_TYPES", "SERVICE_TAGS")))
    assert_equal({ "first" => 0, "second" => 0 }, run_ruby(script.call(false, "SERVICE_TAGS", "SERVICE_TYPES")))
  end

  # 0.0.23's transformer.rb loaded without ruflet_core, so the HTML DSL could
  # be required before it. The constants must not change that.
  def test_html_dsl_still_loads_before_ruflet_core
    result = run_ruby(<<~RUBY)
      require "json"
      require "ruflet/rails/html_dsl"
      core_loaded = !defined?(::Ruflet::UI::ControlFactory).nil?
      transformer = Ruflet::Rails::HtmlDsl::Transformer
      declared = [transformer.const_defined?(:SERVICE_TAGS), transformer.const_defined?(:SERVICE_TYPES),
                  (transformer.constants & %i[SERVICE_TAGS SERVICE_TYPES]).sort]
      require "ruflet_rails"
      handlers = Object.new
      def handlers.method_missing(*) = nil
      def handlers.respond_to_missing?(*) = true
      page = transformer.new(handlers: handlers).transform("<battery></battery><column><text>hi</text></column>")
      puts JSON.generate("core_loaded" => core_loaded, "declared" => declared,
                         "services" => page.services.map(&:type), "controls" => page.controls.map(&:type))
    RUBY

    assert_equal false, result["core_loaded"]
    assert_equal [true, true, %w[SERVICE_TAGS SERVICE_TYPES]], result["declared"]
    assert_equal %w[battery], result["services"]
    assert_equal %w[column], result["controls"]
  end

  # On 0.0.23 the constants could be read with only transformer.rb loaded.
  def test_constants_can_be_read_with_only_the_transformer_loaded
    result = run_ruby(<<~RUBY)
      require "json"
      require "ruflet/rails/html_dsl/transformer"
      core_loaded = !defined?(::Ruflet::UI::ControlFactory).nil?
      transformer = Ruflet::Rails::HtmlDsl::Transformer
      puts JSON.generate("core_loaded" => core_loaded, "tags" => transformer::SERVICE_TAGS,
                         "battery" => transformer::SERVICE_TYPES.include?("battery"))
    RUBY

    assert_equal false, result["core_loaded"]
    assert_equal V0_0_23_SERVICE_TAGS, result["tags"].first(V0_0_23_SERVICE_TAGS.length)
    assert_equal true, result["battery"]
  end

  # The lists are built when first read, so a service extension registered
  # after ruflet_rails loads (from a Rails initializer, say) is in them.
  def test_constants_list_a_service_extension_registered_after_load
    result = run_ruby(<<~RUBY)
      require "json"
      require "ruflet_rails"
      tester = Class.new(Ruflet::Control) do
        const_set(:WIRE, "Tester")
        def initialize(id: nil, **props) = super(type: "my_tester", id: id, **props)
      end
      Ruflet::Extensions.register_control(:my_tester, control_class: tester)
      transformer = Ruflet::Rails::HtmlDsl::Transformer
      puts JSON.generate("service_tag" => transformer.service_tag?("my-tester"),
                         "tags" => transformer::SERVICE_TAGS,
                         "type" => transformer::SERVICE_TYPES.include?("my_tester"))
    RUBY

    assert_equal true, result["service_tag"]
    assert_equal "my-tester", result["tags"].last
    assert_equal V0_0_23_SERVICE_TAGS, result["tags"].first(V0_0_23_SERVICE_TAGS.length)
    assert_equal true, result["type"]
  end
end

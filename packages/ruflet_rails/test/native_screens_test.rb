# frozen_string_literal: true

require_relative "test_helper"

# Screens resolve to controller actions by convention, so a native app needs no
# route per screen.
class RufletNativeScreensTest < Minitest::Test
  # Stands in for an ActionController class: only action_methods and .action
  # are used.
  class FakeController
    def self.action_methods = @action_methods ||= Set.new
    def self.actions(*names) = names.each { |n| action_methods << n.to_s }
    def self.action(name) = ->(env) { [200, {}, ["#{self}##{name}"]] }
  end

  class NativeController < FakeController
    actions "home", "counter", "counter_increment", "counter_decrement", "device", "form", "form_submit"
  end

  class WhatsappController < FakeController
    actions "index", "show", "status"
  end

  class ReportsController < FakeController
    actions "show"
  end

  class DetailOnlyController < FakeController
    actions "detail"
  end

  def setup
    # The resolver looks constants up by name off Object, the way Rails
    # resolves a top-level controller.
    {
      NativeController: NativeController, WhatsappController: WhatsappController,
      ReportsController: ReportsController, DetailOnlyController: DetailOnlyController
    }.each { |name, klass| Object.const_set(name, klass) unless Object.const_defined?(name) }
  end

  def resolve(path) = Ruflet::Rails::NativeScreens.resolve(path)

  def test_the_folder_root_resolves_to_home
    screen = resolve("/native")

    assert_equal NativeController, screen[:controller]
    assert_equal "home", screen[:action]
    assert_empty screen[:params]
  end

  def test_the_folder_root_falls_back_to_index_then_show
    assert_equal "index", resolve("/whatsapp")[:action]
    assert_equal "show", resolve("/reports")[:action]
  end

  def test_a_single_segment_resolves_to_the_matching_action
    screen = resolve("/native/counter")

    assert_equal "counter", screen[:action]
    assert_empty screen[:params]
  end

  # The case a routing table normally exists to express: an action that lives
  # under another one's path.
  def test_extra_segments_are_tried_as_part_of_the_action_name_first
    assert_equal "counter_increment", resolve("/native/counter/increment")[:action]
    assert_equal "counter_decrement", resolve("/native/counter/decrement")[:action]
    assert_equal "form_submit", resolve("/native/form/submit")[:action]
  end

  # The other case: a parameterised screen.
  def test_an_unmatched_trailing_segment_becomes_a_param
    screen = resolve("/native/device/camera")

    assert_equal "device", screen[:action]
    assert_equal ["camera"], screen[:params]
  end

  def test_the_longest_matching_action_wins_over_a_param
    # #counter_increment exists, so "increment" must not be read as a param.
    screen = resolve("/native/counter/increment")

    assert_equal "counter_increment", screen[:action]
    assert_empty screen[:params]
  end

  def test_an_unknown_feature_folder_does_not_resolve
    assert_nil resolve("/nope")
    assert_nil resolve("/nope/counter")
  end

  def test_an_unknown_action_does_not_resolve
    assert_nil resolve("/native/missing")
  end

  # A folder whose controller has no home/index/show has no root screen, even
  # though the controller itself resolves.
  def test_a_folder_with_no_index_action_does_not_resolve
    assert_equal DetailOnlyController, Ruflet::Rails::NativeScreens.controller_for("detail_only")
    assert_equal "detail", resolve("/detail_only/detail")[:action]
    assert_nil resolve("/detail_only")
  end

  # Rails' own Request is not loaded here (the gem's tests run without Rails),
  # and native_request? only ever asks for the header.

end

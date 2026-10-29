# frozen_string_literal: true

require_relative "test_helper"

class RufletEndReachedCompatibilityTest < Minitest::Test
  PAYLOAD = { "pixels" => 610.0, "max_scroll_extent" => 690.0, "viewport_dimension" => 400.0 }.freeze

  def setup
    @messages = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @messages << [action, payload] }
    )
  end

  def test_scrollables_serialize_end_reached_keywords
    [
      [Ruflet.list_view([Ruflet.text("One")], on_end_reached: ->(_e) {}, end_reached_threshold: 120), "ListView"],
      [Ruflet.grid_view([Ruflet.text("One")], on_end_reached: ->(_e) {}, end_reached_threshold: 120), "GridView"],
      [Ruflet.column([Ruflet.text("One")], scroll: "auto", on_end_reached: ->(_e) {}, end_reached_threshold: 120), "Column"],
      [Ruflet.row([Ruflet.text("One")], scroll: "auto", on_end_reached: ->(_e) {}, end_reached_threshold: 120), "Row"]
    ].each do |control, wire|
      patch = control.to_patch

      assert_equal wire, patch["_c"]
      assert_equal true, patch["on_end_reached"], wire
      assert_equal 120, patch["end_reached_threshold"], wire
      assert control.has_handler?(:end_reached), wire
    end
  end

  def test_end_reached_is_off_by_default
    [Ruflet.list_view, Ruflet.grid_view, Ruflet.column, Ruflet.row].each do |control|
      patch = control.to_patch

      refute patch.key?("on_end_reached"), control.type
      refute patch.key?("end_reached_threshold"), control.type
    end
  end

  def test_unknown_end_reached_keyword_is_rejected
    assert_raises(ArgumentError) { Ruflet.list_view(end_reach_threshold: 10) }
  end

  def test_end_reached_handler_receives_scroll_metrics_without_side_effects
    received = []
    list = Ruflet.list_view(
      [Ruflet.text("One")],
      on_end_reached: ->(event) { received << [event.name, event.data, event.typed_data.class, event.value] }
    )
    @page.add(list)
    props_before = list.props.dup
    @messages.clear

    @page.dispatch_event(target: list.wire_id, name: "end_reached", data: PAYLOAD)

    assert_equal [["end_reached", PAYLOAD, Ruflet::Events::GenericEvent, nil]], received
    assert_equal 690.0, received.first[1]["max_scroll_extent"]
    assert_equal props_before, list.props, "end_reached is not a value event; nothing is applied"
    assert_empty @messages, "no end_refresh or patch is sent for end_reached"
  end

  def test_infinite_scroll_appends_a_page
    list = nil
    list = Ruflet.list_view(
      (1..3).map { |i| Ruflet.text("Item #{i}") },
      on_end_reached: ->(event) do
        start = list.children.length + 1
        (start...(start + 3)).each { |i| list.children << Ruflet.text("Item #{i}") }
        event.page.update
      end
    )
    @page.add(list)
    @page.update
    @messages.clear

    @page.dispatch_event(target: list.wire_id, name: "end_reached", data: PAYLOAD)

    assert_equal 6, list.children.length
    patch = @messages.find { |action, _| action == Ruflet::Protocol::ACTIONS[:patch_control] }
    refute_nil patch, "page.update sends the appended items"
  end
end

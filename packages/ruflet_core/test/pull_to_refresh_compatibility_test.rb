# frozen_string_literal: true

require_relative "test_helper"

class RufletPullToRefreshCompatibilityTest < Minitest::Test
  REFRESH_PROPS = {
    refresh_bgcolor: "#EEEEEE",
    refresh_color: "#FF0000",
    refresh_displacement: 64,
    refresh_timeout: 5000,
    refresh_trigger_distance: 120
  }.freeze

  def setup
    @messages = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @messages << [action, payload] }
    )
  end

  def invokes
    @messages.select { |action, _payload| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }.map(&:last)
  end

  def test_refreshable_controls_serialize_refresh_keywords
    [
      [Ruflet.list_view([Ruflet.text("One")], on_refresh: ->(_e) {}, **REFRESH_PROPS), "ListView"],
      [Ruflet.grid_view([Ruflet.text("One")], on_refresh: ->(_e) {}, **REFRESH_PROPS), "GridView"],
      [Ruflet.column([Ruflet.text("One")], on_refresh: ->(_e) {}, **REFRESH_PROPS), "Column"]
    ].each do |control, wire|
      patch = control.to_patch

      assert_equal wire, patch["_c"]
      assert_equal true, patch["on_refresh"], wire
      assert control.has_handler?(:refresh), wire
      assert_equal "#eeeeee", patch["refresh_bgcolor"], wire
      assert_equal "#ff0000", patch["refresh_color"], wire
      assert_equal 64, patch["refresh_displacement"], wire
      assert_equal 5000, patch["refresh_timeout"], wire
      assert_equal 120, patch["refresh_trigger_distance"], wire
    end
  end

  def test_refresh_is_off_by_default
    [Ruflet.list_view, Ruflet.grid_view, Ruflet.column].each do |control|
      patch = control.to_patch

      refute patch.key?("on_refresh"), control.type
      REFRESH_PROPS.each_key { |key| refute patch.key?(key.to_s), "#{control.type} #{key}" }
      refute control.has_handler?(:refresh)
    end
  end

  def test_row_and_unknown_refresh_keywords_are_rejected
    assert_raises(ArgumentError) { Ruflet.row(on_refresh: ->(_e) {}) }
    assert_raises(ArgumentError) { Ruflet.list_view(refresh_colour: "#fff") }
  end

  def test_refresh_handler_runs_before_end_refresh_is_invoked
    list = nil
    observed = []
    list = Ruflet.list_view(
      [Ruflet.text("Old")],
      on_refresh: ->(event) do
        observed << [event.name, event.value, event.typed_data.class]
        list.children.replace([Ruflet.text("New")])
        event.page.update(list, controls: list.children)
      end
    )
    @page.add(list)
    @messages.clear

    @page.dispatch_event(target: list.wire_id, name: "refresh", data: nil)

    assert_equal [["refresh", nil, Ruflet::Events::GenericEvent]], observed
    actions = @messages.map(&:first)
    patch_index = actions.index(Ruflet::Protocol::ACTIONS[:patch_control])
    refute_nil patch_index, "the handler's update is sent"
    assert_equal Ruflet::Protocol::ACTIONS[:invoke_control_method], actions.last
    assert_operator patch_index, :<, actions.length - 1
    assert_equal "end_refresh", invokes.last["name"]
    assert_equal list.wire_id, invokes.last["control_id"]
    assert_nil invokes.last["args"]
    assert_equal 1, invokes.length
  end

  def test_end_refresh_is_sent_even_when_the_handler_raises
    column = Ruflet.column([Ruflet.text("One")], on_refresh: ->(_event) { raise "backend down" })
    @page.add(column)
    @messages.clear

    error = assert_raises(RuntimeError) do
      @page.dispatch_event(target: column.wire_id, name: "refresh", data: nil)
    end

    assert_equal "backend down", error.message
    assert_equal ["end_refresh"], invokes.map { |payload| payload["name"] }
    assert_equal column.wire_id, invokes.first["control_id"]
  end

  def test_end_refresh_is_sent_for_a_refresh_without_handler
    grid = Ruflet.grid_view([Ruflet.text("One")])
    @page.add(grid)
    @messages.clear

    @page.dispatch_event(target: grid.wire_id, name: "refresh", data: nil)

    assert_equal ["end_refresh"], invokes.map { |payload| payload["name"] }
  end

  def test_other_events_do_not_end_refresh
    events = []
    list = Ruflet.list_view(
      [Ruflet.text("One")],
      on_refresh: ->(_e) { events << :refresh },
      on_scroll: ->(_e) { events << :scroll },
      on_size_change: ->(_e) { events << :size_change }
    )
    @page.add(list)
    @messages.clear

    @page.dispatch_event(target: list.wire_id, name: "scroll", data: { "pixels" => 10 })
    @page.dispatch_event(target: list.wire_id, name: "size_change", data: { "width" => 1 })

    assert_equal [:scroll, :size_change], events
    assert_empty invokes
    assert_empty @messages
  end

  def test_raising_non_refresh_handler_sends_nothing
    list = Ruflet.list_view([Ruflet.text("One")], on_scroll: ->(_e) { raise "boom" })
    @page.add(list)
    @messages.clear

    assert_raises(RuntimeError) do
      @page.dispatch_event(target: list.wire_id, name: "scroll", data: {})
    end
    assert_empty @messages
  end

  def test_end_refresh_method_invokes_the_client
    list = Ruflet.list_view([Ruflet.text("One")], on_refresh: ->(_e) {})
    @page.add(list)
    @messages.clear

    call_id = list.end_refresh

    assert_equal 1, invokes.length
    assert_equal call_id, invokes.first["call_id"]
    assert_equal "end_refresh", invokes.first["name"]
    assert_equal list.wire_id, invokes.first["control_id"]
    assert_nil Ruflet.column.end_refresh, "unmounted control returns nil"
  end
end

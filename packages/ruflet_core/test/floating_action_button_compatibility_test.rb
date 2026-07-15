# frozen_string_literal: true

require_relative "test_helper"

class RufletFloatingActionButtonCompatibilityTest < Minitest::Test
  def test_floating_action_button_serializes_current_flet_props
    button = Ruflet.floating_action_button(
      icon: "add",
      content: "Create",
      autofocus: true,
      bgcolor: "#ABCDEF",
      clip_behavior: "antiAlias",
      disabled_elevation: 1,
      elevation: 6,
      enable_feedback: true,
      focus_color: "#111111",
      focus_elevation: 8,
      foreground_color: "#222222",
      highlight_elevation: 12,
      hover_color: "#333333",
      hover_elevation: 9,
      mini: true,
      mouse_cursor: "click",
      shape: { border_radius: 16 },
      splash_color: "#444444",
      url: "https://example.com",
      on_click: ->(_event) {}
    )

    patch = button.to_patch

    assert_equal "FloatingActionButton", patch["_c"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("add"), patch["icon"]
    assert_equal "Create", patch["content"]
    assert_equal true, patch["autofocus"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal 1, patch["disabled_elevation"]
    assert_equal 6, patch["elevation"]
    assert_equal true, patch["enable_feedback"]
    assert_equal "#111111", patch["focus_color"]
    assert_equal 8, patch["focus_elevation"]
    assert_equal "#222222", patch["foreground_color"]
    assert_equal 12, patch["highlight_elevation"]
    assert_equal "#333333", patch["hover_color"]
    assert_equal 9, patch["hover_elevation"]
    assert_equal true, patch["mini"]
    assert_equal "click", patch["mouse_cursor"]
    assert_equal({ "border_radius" => 16 }, patch["shape"])
    assert_equal "#444444", patch["splash_color"]
    assert_equal "https://example.com", patch["url"]
    assert_equal true, patch["on_click"]
  end

  def test_floating_action_button_requires_icon_or_content_like_flet
    error = assert_raises(ArgumentError) { Ruflet.floating_action_button }

    assert_match(/icon or.*content/, error.message)
  end

  def test_floating_action_button_rejects_negative_elevations_like_flet
    %i[disabled_elevation elevation focus_elevation highlight_elevation hover_elevation].each do |prop|
      error = assert_raises(ArgumentError) do
        Ruflet.floating_action_button(icon: "add", prop => -1)
      end

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_page_add_serializes_floating_action_button_as_view_slot
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.add(Ruflet.text("Body"), floating_action_button: Ruflet.floating_action_button(icon: "add"))

    views_patch = sent.last[1]["patch"].find { |op| op[2] == "views" }
    view = views_patch[3].first
    assert_equal "FloatingActionButton", view["floating_action_button"]["_c"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("add"), view["floating_action_button"]["icon"]
  end

  def test_floating_action_button_click_event_dispatches
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    events = []
    button = Ruflet.floating_action_button(icon: "add", on_click: ->(event) { events << [event.name, event.control.type] })
    page.add(button)

    page.dispatch_event(target: button.wire_id, name: "click", data: nil)

    assert_equal [["click", "floatingactionbutton"]], events
  end
end

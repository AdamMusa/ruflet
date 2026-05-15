# frozen_string_literal: true

require_relative "test_helper"

class RufletBottomSheetCompatibilityTest < Minitest::Test
  def test_bottom_sheet_accepts_positional_content_and_serializes_current_flet_props
    sheet = Ruflet.bottom_sheet(
      Ruflet.container(content: Ruflet.text("Choose an option"), padding: 50),
      animation_style: { duration: 200 },
      barrier_color: "#ABCDEF",
      bgcolor: "#123456",
      clip_behavior: "antiAlias",
      dismissible: false,
      draggable: true,
      elevation: 6,
      fullscreen: true,
      maintain_bottom_view_insets_padding: true,
      open: true,
      scrollable: true,
      shape: { border_radius: 12 },
      show_drag_handle: true,
      size_constraints: { max_height: 500 },
      use_safe_area: false,
      on_dismiss: ->(_event) {}
    )

    patch = sheet.to_patch

    assert_equal "BottomSheet", patch["_c"]
    assert_equal "Container", patch["content"]["_c"]
    assert_equal "Text", patch["content"]["content"]["_c"]
    assert_equal({ "duration" => 200 }, patch["animation_style"])
    assert_equal "#abcdef", patch["barrier_color"]
    assert_equal "#123456", patch["bgcolor"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal false, patch["dismissible"]
    assert_equal true, patch["draggable"]
    assert_equal 6, patch["elevation"]
    assert_equal true, patch["fullscreen"]
    assert_equal true, patch["maintain_bottom_view_insets_padding"]
    assert_equal true, patch["open"]
    assert_equal true, patch["scrollable"]
    assert_equal({ "border_radius" => 12 }, patch["shape"])
    assert_equal true, patch["show_drag_handle"]
    assert_equal({ "max_height" => 500 }, patch["size_constraints"])
    assert_equal false, patch["use_safe_area"]
    assert_equal true, patch["on_dismiss"]
  end

  def test_bottom_sheet_requires_content_like_flet
    error = assert_raises(ArgumentError) { Ruflet.bottom_sheet }

    assert_match(/content/, error.message)
  end

  def test_bottom_sheet_rejects_negative_elevation_like_flet
    error = assert_raises(ArgumentError) do
      Ruflet.bottom_sheet(Ruflet.text("Sheet"), elevation: -1)
    end

    assert_match(/elevation/, error.message)
  end

  def test_bottom_sheet_dismiss_event_closes_dialog_tracking_and_calls_handler
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    dismissed = []
    sheet = Ruflet.bottom_sheet(
      Ruflet.text("Sheet"),
      on_dismiss: ->(event) { dismissed << [event.name, event.control.props["open"]] }
    )

    page.add(Ruflet.text("Root"))
    page.show_dialog(sheet)
    page.dispatch_event(target: sheet.wire_id, name: "dismiss", data: nil)

    assert_equal [["dismiss", true]], dismissed
    assert_equal [], sent.last[1]["patch"][1][3]
  end
end

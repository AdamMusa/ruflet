# frozen_string_literal: true

require_relative "test_helper"

class RufletDraggableScrollableSheetCompatibilityTest < Minitest::Test
  def test_draggable_scrollable_sheet_serializes_its_wire_contract
    sheet = Ruflet.draggable_scrollable_sheet(
      [Ruflet.text("One"), Ruflet.text("Two")],
      header: Ruflet.text("Nearby"),
      initial_child_size: 0.3,
      min_child_size: 0.15,
      max_child_size: 0.9,
      snap: true,
      snap_sizes: [0.3, 0.6],
      snap_animation_duration: 250,
      should_close_on_min_extent: false,
      bgcolor: "#123456",
      border_radius: 20,
      show_drag_handle: false,
      padding: { left: 16, right: 16 },
      spacing: 8,
      elevation: 3,
      extent_change_interval: 100,
      expand: true,
      on_extent_change: ->(_event) {}
    )

    patch = sheet.to_patch

    assert_equal "DraggableScrollableSheet", patch["_c"]
    assert_equal %w[One Two], patch["controls"].map { |child| child["value"] }
    assert_equal "Text", patch["header"]["_c"]
    assert_equal "Nearby", patch["header"]["value"]
    assert_equal 0.3, patch["initial_child_size"]
    assert_equal 0.15, patch["min_child_size"]
    assert_equal 0.9, patch["max_child_size"]
    assert_equal true, patch["snap"]
    assert_equal [0.3, 0.6], patch["snap_sizes"]
    assert_equal 250, patch["snap_animation_duration"]
    assert_equal false, patch["should_close_on_min_extent"]
    assert_equal "#123456", patch["bgcolor"]
    assert_equal 20, patch["border_radius"]
    assert_equal false, patch["show_drag_handle"]
    assert_equal({ "left" => 16, "right" => 16 }, patch["padding"])
    assert_equal 8, patch["spacing"]
    assert_equal 3, patch["elevation"]
    assert_equal 100, patch["extent_change_interval"]
    assert_equal true, patch["expand"]
    assert_equal true, patch["on_extent_change"]
    assert sheet.has_handler?(:extent_change)
  end

  def test_defaults_are_left_to_the_renderer
    patch = Ruflet.draggable_scrollable_sheet.to_patch

    assert_equal "DraggableScrollableSheet", patch["_c"]
    %w[initial_child_size min_child_size max_child_size snap snap_sizes show_drag_handle spacing].each do |key|
      refute patch.key?(key), "#{key} is defaulted by the renderer"
    end
  end

  def test_block_children_and_compact_alias
    sheet = Ruflet.draggablescrollablesheet(controls: [Ruflet.text("Prop")]) do
      text("Block")
    end

    assert_equal "DraggableScrollableSheet", sheet.to_patch["_c"]
    assert_equal %w[Block Prop], sheet.to_patch["controls"].map { |child| child["value"] }
  end

  def test_rejects_unknown_keywords
    error = assert_raises(ArgumentError) { Ruflet.draggable_scrollable_sheet(snap_size: [0.5]) }

    assert_match(/snap_size/, error.message)
  end

  def test_common_layout_keywords_are_accepted
    keywords = Ruflet::UI::Controls::RufletComponents::DraggableScrollableSheetControl::KEYWORDS
    %i[align bottom expand height key left margin opacity right top visible width on_size_change].each do |keyword|
      assert_includes keywords, keyword
    end
    refute_includes keywords, :draggable_expand
  end

  def test_extent_change_event_reaches_the_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    seen = []
    sheet = Ruflet.draggable_scrollable_sheet(
      [Ruflet.text("One")],
      on_extent_change: ->(event) { seen << [event.name, event.data["extent"], event.data["min"], event.data["max"]] }
    )
    page.add(Ruflet.stack(controls: [sheet], expand: true))

    page.dispatch_event(
      target: sheet.wire_id,
      name: "extent_change",
      data: { "extent" => 0.75, "min" => 0.25, "max" => 1.0 }
    )

    assert_equal [["extent_change", 0.75, 0.25, 1.0]], seen
  end

  def test_animate_to_and_jump_to_invoke_the_sheet
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    sheet = Ruflet.draggable_scrollable_sheet([Ruflet.text("One")])
    page.add(Ruflet.stack(controls: [sheet], expand: true))
    messages.clear

    sheet.animate_to(1.0)
    sheet.animate_to(0.4, duration: 150, curve: "easeInOut")
    sheet.jump_to(0.25)

    assert_equal %w[animate_to animate_to jump_to], messages.map { |_action, payload| payload["name"] }
    assert messages.all? { |_action, payload| payload["control_id"] == sheet.wire_id }
    assert_equal({ "size" => 1.0, "duration" => 300, "curve" => "easeOut" }, messages[0].last["args"])
    assert_equal({ "size" => 0.4, "duration" => 150, "curve" => "easeInOut" }, messages[1].last["args"])
    assert_equal({ "size" => 0.25 }, messages[2].last["args"])
  end

  def test_methods_are_safe_before_the_sheet_is_mounted
    sheet = Ruflet.draggable_scrollable_sheet

    assert_nil sheet.animate_to(1.0)
    assert_nil sheet.jump_to(0.5)
  end
end

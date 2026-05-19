# frozen_string_literal: true

require_relative "test_helper"

class RufletInteractiveViewerCompatibilityTest < Minitest::Test
  def test_interactive_viewer_serializes_flet_props_and_events
    viewer = Ruflet.interactive_viewer(
      Ruflet.image("https://picsum.photos/500/500"),
      alignment: { x: 0, y: 0 },
      boundary_margin: { left: 20, top: 20, right: 20, bottom: 20 },
      clip_behavior: "hard_edge",
      constrained: false,
      interaction_end_friction_coefficient: 0.0000135,
      interaction_update_interval: 25,
      max_scale: 5,
      min_scale: 0.1,
      pan_enabled: true,
      scale_enabled: true,
      scale_factor: 200,
      trackpad_scroll_causes_scale: false,
      on_interaction_start: ->(_event) {},
      on_interaction_update: ->(_event) {},
      on_interaction_end: ->(_event) {}
    )

    patch = viewer.to_patch

    assert_equal "InteractiveViewer", patch["_c"]
    assert_equal "Image", patch["content"]["_c"]
    assert_equal "https://picsum.photos/500/500", patch["content"]["src"]
    assert_equal({ "x" => 0, "y" => 0 }, patch["alignment"])
    assert_equal({ "left" => 20, "top" => 20, "right" => 20, "bottom" => 20 }, patch["boundary_margin"])
    assert_equal "hard_edge", patch["clip_behavior"]
    assert_equal false, patch["constrained"]
    assert_equal 0.0000135, patch["interaction_end_friction_coefficient"]
    assert_equal 25, patch["interaction_update_interval"]
    assert_equal 5, patch["max_scale"]
    assert_equal 0.1, patch["min_scale"]
    assert_equal true, patch["pan_enabled"]
    assert_equal true, patch["scale_enabled"]
    assert_equal 200, patch["scale_factor"]
    assert_equal false, patch["trackpad_scroll_causes_scale"]
    assert_equal true, patch["on_interaction_start"]
    assert_equal true, patch["on_interaction_update"]
    assert_equal true, patch["on_interaction_end"]
    assert viewer.has_handler?(:interaction_start)
    assert viewer.has_handler?(:interaction_update)
    assert viewer.has_handler?(:interaction_end)
  end

  def test_interactiveviewer_compact_alias_matches_flet_wire_name
    assert_equal "InteractiveViewer", Ruflet.interactiveviewer.to_patch["_c"]
  end

  def test_interactive_viewer_methods_invoke_flet_control_methods
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    viewer = Ruflet.interactive_viewer(Ruflet.text("Zoom me"))
    page.add(viewer)
    messages.clear

    viewer.pan(50, dy: 25, dz: 5)
    viewer.zoom(1.2)
    viewer.reset(animation_duration: { milliseconds: 300 })
    viewer.save_state
    viewer.restore_state

    assert_equal %w[pan zoom reset save_state restore_state], messages.map { |_action, payload| payload["name"] }
    assert_equal({ "dx" => 50, "dy" => 25, "dz" => 5 }, messages[0].last["args"])
    assert_equal({ "factor" => 1.2 }, messages[1].last["args"])
    assert_equal({ "animation_duration" => { "milliseconds" => 300 } }, messages[2].last["args"])
    assert_nil messages[3].last["args"]
    assert_nil messages[4].last["args"]
  end
end

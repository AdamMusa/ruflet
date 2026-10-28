# frozen_string_literal: true

require_relative "test_helper"

class RufletStepperCompatibilityTest < Minitest::Test
  def test_stepper_serializes_steps_and_props
    wizard = Ruflet.stepper(
      [
        Ruflet.stepper_step(title: "Account", subtitle: "Sign in", content: Ruflet.text("Email"),
                            state: "complete", is_active: true),
        Ruflet.stepper_step(title: Ruflet.text("Address"), content: Ruflet.text("Street"),
                            label: "Where", state: "editing"),
        Ruflet.stepper_step(title: "Confirm")
      ],
      current_step: 1,
      type: "horizontal",
      show_controls: false,
      continue_text: "Next",
      cancel_text: "Back",
      elevation: 2,
      connector_color: { "selected" => "#FF0000", "default" => "#cccccc" },
      connector_thickness: 2,
      clip_behavior: "hardEdge",
      height: 400
    )

    patch = wizard.to_patch

    assert_equal "Stepper", patch["_c"]
    assert_equal "stepper", wizard.type
    assert_equal 1, patch["current_step"]
    assert_equal "horizontal", patch["type"]
    assert_equal false, patch["show_controls"]
    assert_equal "Next", patch["continue_text"]
    assert_equal "Back", patch["cancel_text"]
    assert_equal 2, patch["elevation"]
    assert_equal({ "selected" => "#FF0000", "default" => "#cccccc" }, patch["connector_color"])
    assert_equal 2, patch["connector_thickness"]
    assert_equal "hardEdge", patch["clip_behavior"]
    assert_equal 400, patch["height"]
    refute patch.key?("controls")

    first, second, third = patch["steps"]
    assert_equal %w[Step Step Step], patch["steps"].map { |step| step["_c"] }
    assert_equal "Account", first["title"]
    assert_equal "Sign in", first["subtitle"]
    assert_equal "Text", first["content"]["_c"]
    assert_equal "complete", first["state"]
    assert_equal true, first["is_active"]
    assert_equal "Text", second["title"]["_c"]
    assert_equal "Where", second["label"]
    assert_equal "editing", second["state"]
    assert_equal "Confirm", third["title"]
    refute third.key?("content")
  end

  def test_defaults_current_step_and_vertical_type
    wizard = Ruflet.stepper([Ruflet.stepper_step(title: "Only")])

    assert_equal 0, wizard.props["current_step"]
    assert_equal "vertical", wizard.props["type"]
    assert_equal "vertical", wizard.to_patch["type"]
    assert_nil wizard.props["show_controls"]
  end

  def test_type_keyword_never_replaces_the_control_type
    wizard = Ruflet.control(:stepper, type: "horizontal", steps: [Ruflet.stepper_step(title: "A")])

    assert_equal "stepper", wizard.type
    assert_equal "Stepper", wizard.to_patch["_c"]
    assert_equal "horizontal", wizard.to_patch["type"]
  end

  def test_block_children_become_controls
    wizard = Ruflet.stepper(current_step: 0) do
      stepper_step(title: "One")
      stepper_step(title: "Two")
    end

    patch = wizard.to_patch
    assert_equal %w[One Two], patch["controls"].map { |step| step["title"] }
    refute patch.key?("steps")
  end

  def test_compact_aliases_and_generic_step_type
    assert_equal "Stepper", Ruflet.stepper([]).to_patch["_c"]
    assert_equal "Stepper", Ruflet.control(:stepper).to_patch["_c"]
    assert_equal "Step", Ruflet.stepperstep(title: "Alias").to_patch["_c"]
    assert_equal "Step", Ruflet.control(:step, title: "Generic").to_patch["_c"]
    assert_equal "Step", Ruflet.control(:stepper_step, title: "Generic").to_patch["_c"]
    assert_respond_to Ruflet::DSL, :stepper
    assert_respond_to Ruflet::DSL, :stepper_step
    assert_respond_to Ruflet::DSL, :stepperstep
  end

  def test_no_public_step_helper_is_defined
    # D-6: forwarders are included into Kernel; a public `step` would shadow
    # user code. Only stepper_step is a helper.
    refute Ruflet::UI::SharedControlForwarders.instance_methods.include?(:step)
    refute Ruflet::UI::MaterialControlMethods.instance_methods.include?(:step)
    refute Ruflet::DSL.respond_to?(:step)
  end

  def test_events_are_registered
    wizard = Ruflet.stepper(
      [Ruflet.stepper_step(title: "A")],
      on_step_tap: ->(_e) {},
      on_step_continue: ->(_e) {},
      on_step_cancel: ->(_e) {}
    )

    assert wizard.has_handler?(:step_tap)
    assert wizard.has_handler?(:step_continue)
    assert wizard.has_handler?(:step_cancel)
    patch = wizard.to_patch
    assert_equal true, patch["on_step_tap"]
    assert_equal true, patch["on_step_continue"]
    assert_equal true, patch["on_step_cancel"]
  end

  def test_step_requires_title
    error = assert_raises(ArgumentError) { Ruflet.stepper_step(content: Ruflet.text("Body")) }

    assert_includes error.message, "title"
  end

  def test_unknown_keywords_raise
    assert_raises(ArgumentError) { Ruflet.stepper([], current_index: 1) }
    assert_raises(ArgumentError) { Ruflet.stepper_step(title: "A", expanded: true) }
    assert_raises(ArgumentError) { Ruflet.stepper([], on_change: ->(_e) {}) }
  end

  def test_controlled_events_reach_handlers_without_moving_current_step
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    observed = []
    wizard = Ruflet.stepper(
      [Ruflet.stepper_step(title: "A"), Ruflet.stepper_step(title: "B"), Ruflet.stepper_step(title: "C")],
      on_step_tap: ->(e) { observed << [:tap, e.value] },
      on_step_continue: ->(e) { observed << [:continue, e.value] },
      on_step_cancel: ->(e) { observed << [:cancel, e.value] }
    )
    page.add(wizard)

    page.dispatch_event(target: wizard.wire_id, name: "step_tap", data: 2)
    page.dispatch_event(target: wizard.wire_id, name: "step_continue", data: 0)
    page.dispatch_event(target: wizard.wire_id, name: "step_cancel", data: 0)

    assert_equal [[:tap, 2], [:continue, 0], [:cancel, 0]], observed
    assert_equal 0, wizard.props["current_step"]

    page.update(wizard, current_step: 2)
    assert_equal 2, wizard.props["current_step"]

    page.update(wizard, type: "horizontal")
    assert_equal "horizontal", wizard.props["type"]
    assert_equal "stepper", wizard.type
    assert_equal "Stepper", wizard.to_patch["_c"]
  end
end

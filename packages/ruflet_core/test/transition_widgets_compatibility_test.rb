# frozen_string_literal: true

require_relative "test_helper"

# Explicit transitions (FadeTransition, RotationTransition, ScaleTransition,
# SlideTransition, SizeTransition: a run, a loop or a ping-pong the engine
# drives with an AnimationController, so Ruby sends no patch per frame) and
# the clip widgets Ruflet had no counterpart for (ClipOval,
# ClipRSuperellipse).
class RufletTransitionWidgetsCompatibilityTest < Minitest::Test
  NAMES = {
    "fade_transition" => "FadeTransition",
    "fadetransition" => "FadeTransition",
    "rotation_transition" => "RotationTransition",
    "rotationtransition" => "RotationTransition",
    "scale_transition" => "ScaleTransition",
    "scaletransition" => "ScaleTransition",
    "slide_transition" => "SlideTransition",
    "slidetransition" => "SlideTransition",
    "size_transition" => "SizeTransition",
    "sizetransition" => "SizeTransition",
    "clip_oval" => "ClipOval",
    "clipoval" => "ClipOval",
    "clip_rsuperellipse" => "ClipRSuperellipse",
    "cliprsuperellipse" => "ClipRSuperellipse"
  }.freeze

  TRANSITIONS = %w[fade_transition rotation_transition scale_transition slide_transition size_transition].freeze

  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  def page_with(sent = [])
    Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(action, payload) { sent << [action, payload] })
  end

  def test_fade_transition_defaults_to_a_one_second_fade_in
    patch = Ruflet.fade_transition(Ruflet.text("Hi")).to_patch

    assert_equal "FadeTransition", patch["_c"]
    assert_equal 0.0, patch["begin"]
    assert_equal 1.0, patch["end"]
    assert_equal 1000, patch["duration"]
    assert_equal "Hi", patch["content"]["value"]
    # Engine defaults: plays once, forward, right away, linear.
    %w[repeat reverse animating delay curve].each { |key| refute patch.key?(key), key }
  end

  def test_every_transition_has_a_begin_an_end_and_a_duration_by_default
    defaults = TRANSITIONS.to_h { |name| [name, Ruflet.public_send(name).to_patch] }

    assert_equal [0.0, 1.0], [defaults["rotation_transition"]["begin"], defaults["rotation_transition"]["end"]]
    assert_equal [0.0, 1.0], [defaults["scale_transition"]["begin"], defaults["scale_transition"]["end"]]
    assert_equal [0.0, 1.0], [defaults["size_transition"]["begin"], defaults["size_transition"]["end"]]
    assert_equal({ "x" => 0.0, "y" => 1.0 }, defaults["slide_transition"]["begin"])
    assert_equal({ "x" => 0.0, "y" => 0.0 }, defaults["slide_transition"]["end"])
    defaults.each { |name, patch| assert_equal 1000, patch["duration"], name }
    refute defaults["size_transition"].key?("axis")
    refute defaults["rotation_transition"].key?("alignment")
  end

  def test_timing_keywords_serialize
    patch = Ruflet.fade_transition(
      Ruflet.text("Loading"),
      begin: 0.3, end: 1, duration: Ruflet.duration(seconds: 1, milliseconds: 200), curve: :ease_in_out,
      repeat: true, reverse: true, animating: false, delay: 250, margin: 4
    ).to_patch

    assert_equal 0.3, patch["begin"]
    assert_equal 1, patch["end"]
    assert_equal 1200, patch["duration"]
    assert_equal "ease_in_out", patch["curve"]
    assert_equal true, patch["repeat"]
    assert_equal true, patch["reverse"]
    assert_equal false, patch["animating"]
    assert_equal 250, patch["delay"]
    assert_equal 4, patch["margin"]
  end

  def test_rotation_scale_slide_and_size_serialize_their_values
    rotation = Ruflet.rotation_transition(Ruflet.icon("refresh"), end: 2, repeat: true, alignment: { x: 0, y: -1 }).to_patch
    scale = Ruflet.scale_transition(Ruflet.text("3"), begin: 1, end: 1.15, alignment: { "x" => 1, "y" => 1 }).to_patch
    slide = Ruflet.slide_transition(Ruflet.text("Toast"), begin: { x: -1, y: 0 }, end: Ruflet::Offset.new(x: 0.5, y: 0)).to_patch
    size = Ruflet.size_transition(Ruflet.text("More"), axis: :horizontal, axis_alignment: -1, end: 0.5).to_patch

    assert_equal ["RotationTransition", 0.0, 2, { "x" => 0, "y" => -1 }],
                 [rotation["_c"], rotation["begin"], rotation["end"], rotation["alignment"]]
    assert_equal "Icon", rotation["content"]["_c"]
    assert_equal ["ScaleTransition", 1, 1.15, { "x" => 1, "y" => 1 }],
                 [scale["_c"], scale["begin"], scale["end"], scale["alignment"]]
    assert_equal ["SlideTransition", { "x" => -1, "y" => 0 }, { "x" => 0.5, "y" => 0 }],
                 [slide["_c"], slide["begin"], slide["end"]]
    assert_equal ["SizeTransition", "horizontal", -1, 0.0, 0.5],
                 [size["_c"], size["axis"], size["axis_alignment"], size["begin"], size["end"]]
  end

  def test_curve_names_match_without_case_or_underscores
    %w[easeInOut ease_in_out EASE_OUT_BACK fast_out_slow_in linear].each do |curve|
      assert_equal curve, Ruflet.scale_transition(curve: curve).to_patch["curve"]
    end
    assert_equal "bounce_out", Ruflet.scale_transition(curve: :bounce_out).to_patch["curve"]
  end

  def test_timing_validation
    TRANSITIONS.each do |name|
      assert_raises(ArgumentError, name) { Ruflet.public_send(name, duration: -1) }
      assert_raises(ArgumentError, name) { Ruflet.public_send(name, duration: "fast") }
      assert_raises(ArgumentError, name) { Ruflet.public_send(name, delay: -5) }
      assert_raises(ArgumentError, name) { Ruflet.public_send(name, curve: "wobbly") }
      assert_raises(ArgumentError, name) { Ruflet.public_send(name, curve: 3) }
      assert_raises(ArgumentError, name) { Ruflet.public_send(name, repeat: "yes") }
      assert_raises(ArgumentError, name) { Ruflet.public_send(name, reverse: 1) }
      assert_raises(ArgumentError, name) { Ruflet.public_send(name, animating: "no") }
    end
    assert_equal 0, Ruflet.fade_transition(duration: 0).to_patch["duration"]
    assert_equal 1000, Ruflet.fade_transition(duration: nil).to_patch["duration"], "nil keeps the default"
    refute Ruflet.fade_transition(repeat: nil).to_patch.key?("repeat")
  end

  def test_begin_and_end_validation
    assert_raises(ArgumentError) { Ruflet.fade_transition(begin: 1.5) }
    assert_raises(ArgumentError) { Ruflet.fade_transition(end: -0.1) }
    assert_raises(ArgumentError) { Ruflet.fade_transition(end: "half") }
    assert_raises(ArgumentError) { Ruflet.rotation_transition(begin: "a") }
    assert_raises(ArgumentError) { Ruflet.scale_transition(end: Float::NAN) }
    assert_raises(ArgumentError) { Ruflet.scale_transition(end: Float::INFINITY) }
    assert_raises(ArgumentError) { Ruflet.size_transition(begin: -1) }
    assert_raises(ArgumentError) { Ruflet.slide_transition(begin: 3) }
    assert_raises(ArgumentError) { Ruflet.slide_transition(begin: { x: 1 }) }
    assert_raises(ArgumentError) { Ruflet.slide_transition(end: { x: "a", y: 0 }) }
    assert_raises(ArgumentError) { Ruflet.slide_transition(end: { x: 0, y: 0, z: 1 }) }
    # Rotation and scale take any number: negative turns spin backwards.
    assert_equal(-1, Ruflet.rotation_transition(end: -1).to_patch["end"])
    assert_equal 2, Ruflet.scale_transition(begin: 2).to_patch["begin"]
  end

  def test_axis_and_alignment_validation
    assert_raises(ArgumentError) { Ruflet.size_transition(axis: "diagonal") }
    assert_raises(ArgumentError) { Ruflet.size_transition(axis: 1) }
    assert_raises(ArgumentError) { Ruflet.size_transition(axis_alignment: "top") }
    assert_raises(ArgumentError) { Ruflet.rotation_transition(alignment: "center") }
    assert_raises(ArgumentError) { Ruflet.scale_transition(alignment: { x: 0 }) }
    assert_equal "vertical", Ruflet.size_transition(axis: "vertical").to_patch["axis"]
  end

  def test_clip_oval_and_superellipse_serialize
    oval = Ruflet.clip_oval(Ruflet.image(src: "avatar.png"), clip_behavior: "hard_edge", width: 48, height: 48).to_patch
    squircle = Ruflet.clip_rsuperellipse(Ruflet.text("App"), border_radius: 16).to_patch
    corners = Ruflet.clip_rsuperellipse(border_radius: { top_left: 20, bottom_right: 8 }).to_patch

    assert_equal ["ClipOval", "hard_edge", 48, 48], [oval["_c"], oval["clip_behavior"], oval["width"], oval["height"]]
    assert_equal "Image", oval["content"]["_c"]
    refute Ruflet.clip_oval.to_patch.key?("clip_behavior"), "the engine defaults to anti_alias"
    assert_equal ["ClipRSuperellipse", 16, "App"], [squircle["_c"], squircle["border_radius"], squircle["content"]["value"]]
    assert_equal({ "top_left" => 20, "bottom_right" => 8 }, corners["border_radius"])
  end

  def test_clip_validation
    assert_raises(ArgumentError) { Ruflet.clip_oval(clip_behavior: "round") }
    assert_raises(ArgumentError) { Ruflet.clip_rsuperellipse(border_radius: -1) }
    assert_raises(ArgumentError) { Ruflet.clip_rsuperellipse(border_radius: { top: 4 }) }
    assert_raises(ArgumentError) { Ruflet.clip_rsuperellipse(border_radius: "big") }
    assert_equal "antiAliasWithSaveLayer", Ruflet.clip_oval(clip_behavior: "antiAliasWithSaveLayer").to_patch["clip_behavior"]
  end

  def test_unknown_keywords_raise
    assert_raises(ArgumentError) { Ruflet.fade_transition(axis: "vertical") }
    assert_raises(ArgumentError) { Ruflet.fade_transition(alignment: { x: 0, y: 0 }) }
    assert_raises(ArgumentError) { Ruflet.slide_transition(alignment: { x: 0, y: 0 }) }
    assert_raises(ArgumentError) { Ruflet.rotation_transition(turns: 1) }
    assert_raises(ArgumentError) { Ruflet.clip_oval(duration: 300) }
    assert_raises(ArgumentError) { Ruflet.clip_oval(border_radius: 4) }
  end

  def test_names_aliases_and_dsl_entry_points
    NAMES.each do |name, wire|
      assert Ruflet::UI::ControlFactory.known_control?(name), name
      assert_equal wire, Ruflet::UI::ControlFactory.build(name).wire_type, name
      assert_equal wire, Ruflet.public_send(name).wire_type, "Ruflet.#{name}"
      assert_equal wire, Ruflet::DSL.public_send(name).wire_type, "Ruflet::DSL.#{name}"
      assert_equal wire, Ruflet::DSL.app.public_send(name).wire_type, "DSL app #{name}"
      assert_equal wire, Ruflet::WidgetBuilder.new.public_send(name).wire_type, "WidgetBuilder #{name}"
      assert_equal wire, Ruflet.control(name).wire_type, "Ruflet.control(:#{name})"
    end
    assert_equal "FadeTransition", fade_transition.wire_type
    assert_equal "ClipOval", clip_oval.wire_type
  end

  def test_content_built_in_a_block_is_not_also_a_block_child
    column = Ruflet.column do
      fade_transition(text("fade"), repeat: true, reverse: true)
      rotation_transition(icon("refresh"), repeat: true)
      scale_transition(content: text("pulse"), begin: 1, end: 1.1)
      slide_transition(text("slide"))
      size_transition(text("size"), axis: "horizontal")
      clip_oval(container(width: 40, height: 40))
      clip_rsuperellipse(text("squircle"), border_radius: 12)
    end

    assert_equal %w[FadeTransition RotationTransition ScaleTransition SlideTransition SizeTransition ClipOval ClipRSuperellipse],
                 column.children.map { |child| child.to_patch["_c"] }
    assert_equal "pulse", column.children[2].to_patch["content"]["value"]
  end

  def test_dsl_app_keeps_content_out_of_the_roots
    app = Ruflet::DSL.app
    transition = app.fade_transition(app.text("Hi"), curve: :ease_out)

    assert_equal "ease_out", transition.to_patch["curve"]
    assert_equal "Text", transition.to_patch["content"]["_c"]
  end

  def test_on_animation_end_registers_and_dispatches
    events = []
    page = page_with
    transition = Ruflet.slide_transition(
      Ruflet.text("In"), on_animation_end: ->(event) { events << [event.name, event.data, event.control.type] }
    )
    page.add(transition)

    assert_equal true, transition.to_patch["on_animation_end"]
    assert transition.has_handler?(:animation_end)

    page.dispatch_event(target: transition.wire_id, name: "animation_end", data: "transition")

    assert_equal [%w[animation_end transition slidetransition]], events
  end

  def test_on_animation_end_attached_later_is_sent_to_the_client
    sent = []
    page = page_with(sent)
    transition = Ruflet.fade_transition(Ruflet.text("x"))
    page.add(transition)
    sent.clear
    ended = 0

    transition.on(:animation_end) { ended += 1 }
    page.dispatch_event(target: transition.wire_id, name: "animation_end", data: "transition")

    assert_equal 1, ended
    assert(sent.any? { |_action, payload| payload["patch"].include?([0, 0, "on_animation_end", true]) })
    assert_raises(ArgumentError) { Ruflet.fade_transition(on_finish: ->(_e) {}) }
  end

  def test_a_patch_retargets_or_pauses_a_mounted_transition
    sent = []
    page = page_with(sent)
    pulse = Ruflet.scale_transition(Ruflet.text("3"), begin: 1, end: 1.2, repeat: true, reverse: true)
    page.add(pulse)
    sent.clear

    page.update(pulse, end: 1.5, animating: false, duration: Ruflet.duration(milliseconds: 600))

    assert_equal [1.5, false, 600], [pulse.props["end"], pulse.props["animating"], pulse.props["duration"]]
    assert_equal [[0], [0, 0, "end", 1.5], [0, 0, "animating", false], [0, 0, "duration", 600]],
                 sent.last[1]["patch"]
  end
end

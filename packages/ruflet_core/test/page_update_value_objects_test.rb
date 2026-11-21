# frozen_string_literal: true

require "set"
require_relative "test_helper"

# Page patches carry value objects (Ruflet::TextStyle, StrutStyle, Offset,
# Duration) the way construction does: as their to_h map. Before, a patch
# kept the object itself, which the wire codec sent as "#<...:0x...>" and the
# renderer's parsers (parseTextStyle, parseAnimation) threw on. The bare
# update compared dups of the object, which are never ==, so it re-sent the
# untouched prop on every call.
#
# page.update(control, **props) on a control the client does not have yet
# keeps the props, so the control shows them when it is mounted. Before, the
# update returned early and the props were lost.
class PageUpdateValueObjectsTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  VALUE_OBJECT_CASES = {
    "text(style: TextStyle)" => [
      ->(v) { Ruflet.text("Title", style: v) }, "style",
      Ruflet::TextStyle.new(size: 28, weight: "bold"), Ruflet::TextStyle.new(size: 30, italic: true)
    ],
    "text_field(text_style: TextStyle)" => [
      ->(v) { Ruflet.text_field(text_style: v) }, "text_style",
      Ruflet::TextStyle.new(size: 12), Ruflet::TextStyle.new(size: 14, color: "red")
    ],
    "text_field(strut_style: StrutStyle)" => [
      ->(v) { Ruflet.text_field(strut_style: v) }, "strut_style",
      Ruflet::StrutStyle.new(size: 12), Ruflet::StrutStyle.new(size: 16, leading: 2)
    ],
    "container(offset: Offset)" => [
      ->(v) { Ruflet.container(offset: v, content: Ruflet.text("x")) }, "offset",
      Ruflet::Offset.new(x: 1, y: 0), Ruflet::Offset.new(x: 0, y: 0.5)
    ],
    "container(animate: Duration)" => [
      ->(v) { Ruflet.container(animate: v, content: Ruflet.text("x")) }, "animate",
      Ruflet::Duration.new(milliseconds: 300), Ruflet::Duration.new(milliseconds: 150)
    ]
  }.freeze

  def patches_for(control)
    @sent.select { |action, payload| action == Ruflet::Protocol::ACTIONS[:patch_control] && payload["id"] == control.wire_id }
  end

  def ops_for(control)
    patches_for(control).flat_map { |_action, payload| payload["patch"].drop(1) }
  end

  def objects_in(value)
    case value
    when Hash then value.flat_map { |k, v| objects_in(k) + objects_in(v) }
    when Array then value.flat_map { |v| objects_in(v) }
    when String, Symbol, Numeric, TrueClass, FalseClass, NilClass then []
    else [value]
    end
  end

  VALUE_OBJECT_CASES.each do |label, (build, key, initial, replacement)|
    slug = label.gsub(/\W+/, "_")

    define_method("test_#{slug}_targeted_update_sends_the_map_construction_sends") do
      control = build.call(initial)
      @page.add(control)
      @sent.clear

      @page.update(control, key => replacement)

      assert_equal [[0, 0, key, build.call(replacement).to_patch[key]]], ops_for(control), label
      assert_kind_of Hash, ops_for(control).first[3], label
      assert_empty objects_in(@sent), "#{label}: no Ruby object reaches the sender"
    end

    define_method("test_#{slug}_bare_update_does_not_resend_an_untouched_value_object") do
      control = build.call(initial)
      counter = Ruflet.text("0")
      @page.add(Ruflet.column(controls: [control, counter]))
      @sent.clear

      counter.props["value"] = "1"
      @page.update
      assert_empty patches_for(control), "#{label}: an unrelated change patches only what changed"
      assert_equal [[0, 0, "value", "1"]], ops_for(counter), label

      @sent.clear
      @page.update
      assert_empty @sent, "#{label}: a bare update with nothing changed sends nothing"
    end

    define_method("test_#{slug}_bare_update_sends_a_changed_value_object_as_its_map") do
      control = build.call(initial)
      @page.add(control)
      @sent.clear

      control.props[key] = replacement
      @page.update
      assert_equal [[0, 0, key, build.call(replacement).to_patch[key]]], ops_for(control), label

      @sent.clear
      @page.update
      assert_empty @sent, "#{label}: the published value object is not re-sent"
    end

    define_method("test_#{slug}_an_equal_new_value_object_is_not_a_change") do
      control = build.call(initial)
      @page.add(control)
      @sent.clear

      control.props[key] = initial.dup
      @page.update
      assert_empty @sent, "#{label}: same map, nothing to send"
    end
  end

  def test_value_object_inside_a_hash_prop_is_sent_as_its_map
    text = Ruflet.text("x")
    @page.add(text)
    @sent.clear

    @page.update(text, data: { "shift" => Ruflet::Offset.new(x: 1, y: 2) })

    assert_equal [[0, 0, "data", { "shift" => { "x" => 1, "y" => 2 } }]], ops_for(text)
  end

  def test_page_and_view_props_send_value_objects_as_maps
    @page.add(Ruflet.text("x"))
    @sent.clear

    @page.update(:page, data: Ruflet::Offset.new(x: 3, y: 4))

    refute_empty @sent
    assert contains?(@sent, { "x" => 3, "y" => 4 }), @sent.inspect
    assert_empty objects_in(@sent)
  end

  def contains?(value, wanted)
    return true if value == wanted

    case value
    when Hash then value.each_value.any? { |v| contains?(v, wanted) }
    when Array then value.any? { |v| contains?(v, wanted) }
    else false
    end
  end

  # Values that are not value objects keep going out exactly as before.
  def test_other_values_pass_through_unchanged
    text = Ruflet.text("x")
    @page.add(text)
    struct = Struct.new(:a, :b).new(1, 2)
    range = (1..3)
    set = Set[1, 2]

    {
      "a string" => "a string",
      7 => 7,
      1.5 => 1.5,
      true => true,
      false => false,
      nil => nil,
      { "size" => 30 } => { "size" => 30 },
      [1, "two"] => [1, "two"]
    }.each do |value, expected|
      @sent.clear
      @page.update(text, data: value)
      assert_equal [[0, 0, "data", expected]], ops_for(text), value.inspect
    end

    # A Struct is a value object: construction already sends its to_h.
    @sent.clear
    @page.update(text, data: struct)
    assert_equal [[0, 0, "data", { "a" => 1, "b" => 2 }]], ops_for(text)
    assert_equal({ "a" => 1, "b" => 2 }, Ruflet.text("y", data: struct).to_patch["data"])

    # Collections whose to_h raises are left alone (the codec sends them as
    # it did before) instead of raising.
    [range, set].each do |value|
      @sent.clear
      @page.update(text, data: value)
      assert_equal [[0, 0, "data", value]], ops_for(text), value.inspect
    end
  end

  def test_update_before_mount_keeps_the_props_and_sends_nothing
    title = Ruflet.text("Delete item?")
    dialog = Ruflet.alert_dialog(title: title, actions: [Ruflet.text_button("OK")])
    @page.add(Ruflet.text("body"))
    @sent.clear

    assert_same @page, @page.update(title, value: "Delete 3 items?", style: Ruflet::TextStyle.new(size: 20))

    assert_empty @sent, "nothing is sent for a control the client does not have"
    assert_nil title.wire_id
    assert_equal "Delete 3 items?", title.props["value"]

    @page.show_dialog(dialog)
    shown = @sent.last[1].to_s
    assert_includes shown, "Delete 3 items?"
    refute_includes shown, "Delete item?"
    assert_equal({ "value" => "Delete 3 items?", "style" => { "size" => 20 } },
                 title.to_patch.slice("value", "style"))
    refute_nil title.wire_id

    @sent.clear
    @page.update
    assert_empty @sent, "a bare update after the mount has nothing left to send"

    @page.update(title, value: "Delete 4 items?")
    assert_equal [[0, 0, "value", "Delete 4 items?"]], ops_for(title)
  end

  def test_update_before_mount_replaces_children_for_the_mount
    old_child = Ruflet.text("old")
    new_child = Ruflet.text("new")
    column = Ruflet.column(controls: [old_child])
    @sent.clear

    @page.update(column, controls: [new_child])

    assert_empty @sent
    assert_equal [new_child], column.children
    refute column.props.key?("controls")

    @page.add(column)
    view = @sent.last[1]["patch"].find { |op| op[2] == "views" }[3].first
    mounted = view["controls"].first
    assert_equal(["new"], mounted["controls"].map { |child| child["value"] })
  end

  def test_update_before_mount_by_unknown_id_is_still_a_no_op
    @page.add(Ruflet.text("body"))
    @sent.clear

    assert_same @page, @page.update("no-such-control", value: "x")
    assert_empty @sent
  end
end

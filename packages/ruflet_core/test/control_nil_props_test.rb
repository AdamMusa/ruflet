# frozen_string_literal: true

require_relative "test_helper"

# Control#to_patch converted any value that has to_h, and nil.to_h is {}.
# So a nil prop reached the client as an empty map: Ruflet.text("x",
# tooltip: nil) sent "tooltip" => {}, which the renderer builds into a
# Tooltip with no message, while page.update(text, tooltip: nil) sent nil.
# A nil prop, or a nil inside one, is now sent as nil, as page.update sends it.
class ControlNilPropsTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def test_a_nil_prop_is_sent_as_nil
    assert_equal({ "_c" => "Text", "_i" => nil, "value" => "x", "tooltip" => nil },
                 Ruflet.text("x", tooltip: nil).to_patch)
    assert_equal({ "_c" => "Text", "_i" => nil, "value" => "x", "visible" => nil },
                 Ruflet::UI::ControlFactory.build("text", value: "x", visible: nil).to_patch)
    assert_nil Ruflet::Control.new(type: "custom_widget", label: nil).to_patch.fetch("label")
  end

  def test_a_nil_inside_a_hash_or_an_array_prop_is_sent_as_nil
    control = Ruflet::Control.new(type: "custom_widget", style: { color: nil, sizes: [1, nil] }, items: [nil, { a: nil }])

    patch = control.to_patch

    assert_equal({ "color" => nil, "sizes" => [1, nil] }, patch["style"])
    assert_equal [nil, { "a" => nil }], patch["items"]
  end

  # What page.add sends for a new control, and what a later patch of its
  # parent sends after page.update set a prop to nil, agree with the update.
  def test_page_add_and_a_later_parent_patch_send_nil_like_page_update
    text = Ruflet.text("x", id: "t", tooltip: nil)
    column = Ruflet.column([text])
    @page.add(column)

    sent_text = find_wire_control(@sent.map(&:last), "Text")
    assert sent_text.key?("tooltip")
    assert_nil sent_text["tooltip"]

    labelled = Ruflet.text("y", tooltip: "hint")
    parent = Ruflet.column([labelled])
    @page.add(parent)
    @page.update(labelled, tooltip: nil)
    assert_equal [[0], [0, 0, "tooltip", nil]], @sent.last[1]["patch"]

    # The parent's new children list carries the text's full patch.
    @page.update(parent, controls: [labelled, Ruflet.text("z")])
    _, _, key, children = @sent.last[1]["patch"].last
    assert_equal "controls", key
    assert children.first.key?("tooltip")
    assert_nil children.first["tooltip"]
  end

  # Only nil changed: other values that have to_h still convert, and an
  # empty Hash, false and Strings are sent as they are.
  def test_other_values_serialize_as_before
    point = Struct.new(:x, :y).new(1, 2)
    control = Ruflet::Control.new(type: "custom_widget", point: point, empty: {}, off: false, name: :label, list: [point])

    patch = control.to_patch

    assert_equal({ "x" => 1, "y" => 2 }, patch["point"])
    assert_equal({}, patch["empty"])
    assert_equal false, patch["off"]
    assert_equal "label", patch["name"]
    assert_equal [{ "x" => 1, "y" => 2 }], patch["list"]
  end

  private

  def find_wire_control(value, wire_type)
    case value
    when Hash
      return value if value["_c"] == wire_type

      value.each_value do |item|
        found = find_wire_control(item, wire_type)
        return found if found
      end
    when Array
      value.each do |item|
        found = find_wire_control(item, wire_type)
        return found if found
      end
    end
    nil
  end
end

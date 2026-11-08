# frozen_string_literal: true

require_relative "test_helper"

# A bare page.update sends one patch per changed control. A changed parent's
# patch re-sends only the props (or children list) that changed, so a changed
# descendant is left out only when one of those re-sent values contains it.
class RufletPageNestedChangePatchesTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def control_patches
    @sent.select { |action, payload| action == Ruflet::Protocol::ACTIONS[:patch_control] && payload["id"] != 1 }
         .map { |_action, payload| [payload["id"], payload["patch"].drop(1).map { |op| op[2] }] }
  end

  def test_a_parent_scalar_change_does_not_hide_a_child_change
    text = Ruflet.text("a")
    column = Ruflet.column(controls: [text])
    @page.add(column)
    @sent.clear

    text.props["value"] = "b"
    column.props["spacing"] = 3
    @page.update

    assert_equal [[column.wire_id, ["spacing"]], [text.wire_id, ["value"]]], control_patches
  end

  def test_a_deeper_descendant_change_is_sent_under_a_changed_ancestor
    text = Ruflet.text("a")
    container = Ruflet.container(content: text)
    column = Ruflet.column(controls: [container])
    @page.add(column)
    @sent.clear

    column.props["spacing"] = 3
    text.props["value"] = "b"
    @page.update

    assert_equal [[column.wire_id, ["spacing"]], [text.wire_id, ["value"]]], control_patches
  end

  def test_a_child_inside_a_re_sent_children_list_is_not_patched_twice
    text = Ruflet.text("a")
    column = Ruflet.column(controls: [text])
    @page.add(column)
    @sent.clear

    text.props["value"] = "b"
    column.children << Ruflet.text("new")
    @page.update

    assert_equal [[column.wire_id, ["controls"]]], control_patches
    resent = @sent.last.last["patch"].last[3]
    assert_equal %w[b new], resent.map { |child| child["value"] }
  end

  def test_a_control_inside_a_re_sent_prop_is_not_patched_twice
    title = Ruflet.text("a")
    tile = Ruflet.list_tile(title: title)
    @page.add(tile)
    @sent.clear

    title.props["value"] = "b"
    tile.props["title"] = Ruflet.row(controls: [title]) # re-sent with the changed text inside
    @page.update

    assert_equal [[tile.wire_id, ["title"]]], control_patches
    row = @sent.last.last["patch"].last[3]
    assert_equal "b", row["controls"].first["value"]
  end

  def test_a_changed_control_outside_the_re_sent_prop_still_gets_its_patch
    title = Ruflet.text("a")
    tile = Ruflet.list_tile(title: title)
    @page.add(tile)
    @sent.clear

    title.props["value"] = "b"
    tile.props["subtitle"] = Ruflet.text("c")
    @page.update

    assert_equal [[tile.wire_id, ["subtitle"]], [title.wire_id, ["value"]]], control_patches
  end
end

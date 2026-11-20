# frozen_string_literal: true

require_relative "test_helper"

# page.update(control, **props) encodes an icon-related prop the way
# construction does (Control#icon_prop_key?):
# - show_close_icon, show_edit_icon, show_selected_icon and
#   show_trailing_icon are booleans, not icon names;
# - leading:/trailing: icon names become codepoints. The renderer
#   (buildIconOrWidget) draws a codepoint or a control and drops a String.
# Values that are not a known icon name keep passing through unchanged.
class PageUpdateIconPropsTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def test_show_icon_booleans_update_like_construction
    builders = {
      show_close_icon: ->(v) { Ruflet.snack_bar(content: Ruflet.text("Saved"), show_close_icon: v) },
      show_selected_icon: lambda { |v|
        Ruflet.segmented_button(selected: ["a"], segments: [Ruflet.segment(value: "a", label: Ruflet.text("A"))],
                                show_selected_icon: v)
      },
      show_trailing_icon: ->(v) { Ruflet.expansion_tile(title: Ruflet.text("T"), show_trailing_icon: v) },
      show_edit_icon: ->(v) { Ruflet.data_cell(content: Ruflet.text("c"), show_edit_icon: v) }
    }
    snack_bar = builders[:show_close_icon].call(true)
    segmented = builders[:show_selected_icon].call(true)
    tile = builders[:show_trailing_icon].call(true)
    cell = builders[:show_edit_icon].call(false)

    @page.add(Ruflet.column(controls: [segmented, tile]))
    @page.show_snack_bar(snack_bar)
    @page.add(Ruflet.data_table(columns: [Ruflet.data_column(label: Ruflet.text("h"))],
                                rows: [Ruflet.data_row(cells: [cell])]))

    [
      [snack_bar, :show_close_icon, false],
      [segmented, :show_selected_icon, false],
      [tile, :show_trailing_icon, false],
      [cell, :show_edit_icon, true]
    ].each do |control, key, value|
      assert_equal value, builders[key].call(value).props[key.to_s], "construction with #{key}: #{value}"
      assert_equal [[0, 0, key.to_s, value]], update_ops(control, key => value), "page.update(#{key}: #{value})"
      assert_equal value, control.props[key.to_s]
    end

    @sent.clear
    @page.update
    assert_empty @sent, "a later bare update has nothing left to send"
  end

  def test_show_icon_values_are_not_looked_up_as_icon_names
    snack_bar = Ruflet.snack_bar(content: Ruflet.text("Saved"))
    @page.show_snack_bar(snack_bar)

    assert_equal [[0, 0, "show_close_icon", "true"]], update_ops(snack_bar, show_close_icon: "true")
    assert_equal [[0, 0, "show_close_icon", nil]], update_ops(snack_bar, show_close_icon: nil)
  end

  def test_leading_and_trailing_icon_names_update_like_construction
    expansion = Ruflet.expansion_tile(title: Ruflet.text("Settings"), leading: "settings", trailing: "expand_more")
    list_tile = Ruflet.list_tile(title: Ruflet.text("Row"), leading: "home", trailing: "chevron_right")
    cupertino = Ruflet.cupertino_list_tile(title: Ruflet.text("Row"), leading: "home", trailing: "info")
    banner = Ruflet.banner(content: Ruflet.text("Note"), leading: "info",
                           actions: [Ruflet.text_button(content: "OK")])
    @page.add(Ruflet.column(controls: [expansion, list_tile, cupertino, banner]))

    info = Ruflet::MaterialIconLookup.codepoint_for("info")
    expand_less = Ruflet::MaterialIconLookup.codepoint_for("expand_less")
    refute_nil info
    refute_nil expand_less

    assert_equal [[0, 0, "leading", info], [0, 0, "trailing", expand_less]],
                 update_ops(expansion, leading: "info", trailing: "expand_less")
    assert_equal [[0, 0, "leading", info]], update_ops(list_tile, leading: "info")
    assert_equal [[0, 0, "trailing", info]], update_ops(cupertino, trailing: :info)
    assert_equal [[0, 0, "leading", info]], update_ops(banner, leading: Ruflet::IconData.new("info"))
    assert_equal [[0, 0, "leading", info]], update_ops(list_tile, leading: Ruflet::MaterialIcons::INFO)
    assert_equal info, list_tile.props["leading"]

    assert_equal Ruflet.list_tile(title: Ruflet.text("Row"), leading: "info").props["leading"], info
    assert_equal Ruflet.expansion_tile(title: Ruflet.text("T"), trailing: "expand_less").props["trailing"], expand_less
  end

  def test_leading_and_trailing_cupertino_only_names_use_cupertino_codepoints
    tile = Ruflet.list_tile(title: Ruflet.text("Row"))
    @page.add(tile)

    name = "house_fill"
    assert_nil Ruflet::MaterialIconLookup.codepoint_for(name)
    expected = Ruflet.list_tile(title: Ruflet.text("Row"), leading: name).props["leading"]
    refute_nil expected

    assert_equal [[0, 0, "leading", expected]], update_ops(tile, leading: name)
  end

  def test_leading_and_trailing_values_that_are_not_icon_names_pass_through
    tile = Ruflet.list_tile(title: Ruflet.text("Row"), leading: "home")
    @page.add(tile)

    assert_equal [[0, 0, "leading", 69217]], update_ops(tile, leading: 69217)
    assert_equal [[0, 0, "leading", "not_an_icon_name_xyz"]], update_ops(tile, leading: "not_an_icon_name_xyz")
    assert_equal [[0, 0, "trailing", "not_an_icon_name_xyz"]], update_ops(tile, trailing: :not_an_icon_name_xyz)
    assert_equal [[0, 0, "leading", ""]], update_ops(tile, leading: "")
    assert_equal [[0, 0, "leading", nil]], update_ops(tile, leading: nil)

    avatar = Ruflet.circle_avatar(content: Ruflet.text("A"))
    ops = update_ops(tile, leading: avatar)
    assert_equal 1, ops.length
    assert_equal "leading", ops.first[2]
    assert_equal "CircleAvatar", ops.first[3]["_c"]
  end

  def test_other_icon_props_still_resolve_and_reject_unknown_names
    destination = Ruflet.navigation_bar_destination(icon: "home", label: "Home")
    @page.add(Ruflet.navigation_bar(destinations: [destination, Ruflet.navigation_bar_destination(icon: "info", label: "Info")]))

    settings = Ruflet::MaterialIconLookup.codepoint_for("settings")
    assert_equal [[0, 0, "selected_icon", settings]], update_ops(destination, selected_icon: "settings")
    assert_equal [[0, 0, "icon", settings]], update_ops(destination, icon: :settings)

    error = assert_raises(ArgumentError) { @page.update(destination, icon: "not_an_icon_name_xyz") }
    assert_match(/known icon name/, error.message)
  end

  private

  def update_ops(control, **props)
    @sent.clear
    @page.update(control, **props)
    refute_empty @sent, "page.update(#{props.inspect}) sent nothing"
    patch = @sent.last[1]["patch"]
    assert_equal [0], patch.first
    patch[1..]
  end
end

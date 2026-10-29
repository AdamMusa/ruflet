# frozen_string_literal: true

require_relative "test_helper"

class RufletAppBarLargeCompatibilityTest < Minitest::Test
  def test_app_bar_large_serializes_on_the_canonical_wire_type
    bar = Ruflet.app_bar(title: "Inbox", large: true, actions: [Ruflet.icon_button("edit")])
    patch = bar.to_patch

    assert_equal "AppBar", patch["_c"]
    assert_equal true, patch["large"]
    assert_equal "Inbox", patch["title"]
    assert_equal ["IconButton"], patch["actions"].map { |action| action["_c"] }
  end

  def test_large_combines_with_toolbar_height_color_and_title_text_style
    bar = Ruflet.app_bar(
      title: Ruflet.text("Inbox"),
      large: true,
      toolbar_height: 72,
      color: "#112233",
      title_text_style: { size: 40 }
    )
    patch = bar.to_patch

    assert_equal true, patch["large"]
    assert_equal 72, patch["toolbar_height"]
    assert_equal "#112233", patch["color"]
    assert_equal({ "size" => 40 }, patch["title_text_style"])
    assert_equal "Inbox", patch["title"]["value"]
  end

  def test_large_is_omitted_by_default_and_false_is_sent
    refute Ruflet.app_bar(title: "Inbox").to_patch.key?("large")
    assert_equal false, Ruflet.app_bar(title: "Inbox", large: false).to_patch["large"]
  end

  def test_view_appbar_carries_large_to_the_client
    view = Ruflet.view(route: "/inbox", appbar: Ruflet.app_bar(title: "Inbox", large: true))

    assert_equal true, view.to_patch["appbar"]["large"]
    assert_equal "AppBar", view.to_patch["appbar"]["_c"]
  end
end

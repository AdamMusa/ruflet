# frozen_string_literal: true

require_relative "test_helper"

class RufletRemainingPythonControlCoverageTest < Minitest::Test
  def test_autofill_group_serializes_content_and_dispose_action
    control = Ruflet.control(:autofill_group, content: Ruflet.text("Name"), dispose_action: "commit")
    patch = control.to_patch

    assert_equal "AutofillGroup", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "commit", patch["dispose_action"]
  end

  def test_base_page_serializes_page_level_props
    control = Ruflet.control(:base_page, title: "Shell", enable_screenshots: true)
    patch = control.to_patch

    assert_equal "BasePage", patch["_c"]
    assert_equal "Shell", patch["title"]
    assert_equal true, patch["enable_screenshots"]
  end

  def test_browser_context_menu_serializes_data
    control = Ruflet.control(:browser_context_menu, data: { "enabled" => false })
    patch = control.to_patch

    assert_equal "BrowserContextMenu", patch["_c"]
    assert_equal({ "enabled" => false }, patch["data"])
  end

  def test_dropdown_m2_serializes_options_and_value
    control = Ruflet.dropdown_m2(
      [Ruflet.dropdown_option("one", text: "One")],
      value: "one",
      label: "Pick"
    )
    patch = control.to_patch

    assert_equal "DropdownM2", patch["_c"]
    assert_equal "one", patch["value"]
    assert_equal "Pick", patch["label"]
    assert_equal "DropdownOption", patch["options"].first["_c"]
  end

  def test_gesture_detector_serializes_content_and_events
    control = Ruflet.gesture_detector(content: Ruflet.text("Tap"), on_tap: true)
    patch = control.to_patch

    assert_equal "GestureDetector", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal true, patch["on_tap"]
  end

  def test_hero_serializes_tag_and_content
    control = Ruflet.control(:hero, tag: "profile-photo", content: Ruflet.text("Photo"))
    patch = control.to_patch

    assert_equal "Hero", patch["_c"]
    assert_equal "profile-photo", patch["tag"]
    assert_equal "Text", patch["content"]["_c"]
  end

  def test_markdown_serializes_value_and_link_props
    control = Ruflet.markdown("# Title", selectable: true, auto_follow_links: false)
    patch = control.to_patch

    assert_equal "Markdown", patch["_c"]
    assert_equal "# Title", patch["value"]
    assert_equal true, patch["selectable"]
    assert_equal false, patch["auto_follow_links"]
  end

  def test_pagelet_serializes_content_and_chrome_props
    control = Ruflet.control(:pagelet, content: Ruflet.text("Body"), bgcolor: "#abcdef")
    patch = control.to_patch

    assert_equal "Pagelet", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "#abcdef", patch["bgcolor"]
  end

  def test_shader_mask_serializes_shader_and_content
    control = Ruflet.control(:shader_mask, content: Ruflet.text("Masked"), blend_mode: "srcIn", shader: "linear")
    patch = control.to_patch

    assert_equal "ShaderMask", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "srcIn", patch["blend_mode"]
    assert_equal "linear", patch["shader"]
  end

  def test_shimmer_serializes_animation_props
    control = Ruflet.control(:shimmer, content: Ruflet.text("Loading"), base_color: "#111111", highlight_color: "#eeeeee")
    patch = control.to_patch

    assert_equal "Shimmer", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "#111111", patch["base_color"]
    assert_equal "#eeeeee", patch["highlight_color"]
  end
end

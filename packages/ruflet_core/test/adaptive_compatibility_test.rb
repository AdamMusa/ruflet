# frozen_string_literal: true

require_relative "test_helper"

# Mirrors the flet adaptive-apps cookbook:
# https://flet.dev/docs/cookbook/adaptive-apps
class RufletAdaptiveCompatibilityTest < Minitest::Test
  def test_page_adaptive_serializes_onto_the_view_like_flet
    sent = []
    page = build_page(sent)

    page.adaptive = true
    page.add(Ruflet.text("hello"))

    view = patch_value(sent.last[1]["patch"], "views").first
    # On the client, `adaptive` cascades to children via `parent?.adaptive`,
    # so setting it once on the root view makes the whole app adaptive.
    assert_equal true, view["adaptive"]
  end

  def test_control_level_adaptive_serializes_like_flet
    %i[checkbox switch radio].each do |kind|
      control = Ruflet.public_send(kind, adaptive: true)
      assert_equal true, control.to_patch["adaptive"], "#{kind} should forward adaptive"
    end
  end

  def test_layout_controls_forward_adaptive_like_flet
    assert_equal true, Ruflet.row([], adaptive: true).to_patch["adaptive"]
    assert_equal true, Ruflet.column([], adaptive: true).to_patch["adaptive"]
    assert_equal true, Ruflet.container(adaptive: true).to_patch["adaptive"]
  end

  def test_adaptive_defaults_to_unset_like_flet
    # Flet's default is False; ruflet simply omits the key unless requested.
    refute Ruflet.checkbox.to_patch.key?("adaptive")
  end

  def test_page_platform_reader_reflects_client_details_like_flet
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/", "platform" => "ios" },
      sender: ->(_a, _p) {}
    )

    # The client reports the platform; apps switch Material/Cupertino on it.
    assert_equal "ios", page.platform
  end

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end

  def patch_value(patch, key)
    op = patch.find { |candidate| candidate[2] == key }
    op && op[3]
  end
end

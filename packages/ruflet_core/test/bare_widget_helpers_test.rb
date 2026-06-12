# frozen_string_literal: true

require_relative "test_helper"

# Widget helpers must build real controls anywhere — top-level scripts and
# Ruflet.run blocks — with no builder to instantiate and no prefix. The
# framework owns the control_delegate plumbing so dev code stays clean.
class RufletBareWidgetHelpersTest < Minitest::Test
  def test_bare_top_level_helpers_build_controls
    t = text("hello")
    assert_equal "text", t.type
    assert_equal "hello", t.props["value"]
  end

  def test_bare_helpers_nest
    v = view(
      route: "/",
      appbar: app_bar(title: text("Store")),
      controls: [filled_button(content: text("Go"), on_click: ->(_e) {})]
    )

    assert_equal "view", v.type
    assert_equal "/", v.route
    assert_equal 1, v.children.length
    assert_equal "filledbutton", v.children.first.type.delete("_")
  end

  def test_each_call_is_independent
    a = text("a")
    b = text("b")

    refute_same a, b
    assert_equal "a", a.props["value"]
    assert_equal "b", b.props["value"]
  end

  def test_ruflet_run_block_self_can_use_bare_helpers
    # A Ruflet.run-style block (self == top-level main) builds controls without
    # a builder. Capture the entrypoint instead of starting a server.
    captured = nil
    Ruflet.with_run_interceptor(->(entrypoint:, **_) { captured = entrypoint; :captured }) do
      Ruflet.run { |_page| view(route: "/x", controls: [text("inside")]) }
    end

    built = captured.call(nil)
    assert_equal "view", built.type
    assert_equal "/x", built.route
  end
end

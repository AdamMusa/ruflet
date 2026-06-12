# frozen_string_literal: true

require_relative "test_helper"

# Hotwire Native-style driver: a webview body + a declarative path configuration.
# Web navigation auto-promotes matching paths to native screens — no imperative
# route branching.
class RufletNativeAppTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(session_id: "na", client_details: {},
                             sender: ->(a, p) { @sent << [a, p] })
  end

  def find(node, type)
    case node
    when Ruflet::Control
      return node if node.type == type

      node.props.each_value { |v| (f = find(v, type)) and return f }
      node.children.each { |c| (f = find(c, type)) and return f }
      nil
    when Array
      node.each { |v| (f = find(v, type)) and return f }
      nil
    end
  end

  def stack
    @page.views
  end

  def webview
    find(stack.first, "webview")
  end

  def native_screen(title)
    Ruflet::UI::ControlFactory.build(
      :view, route: "/native",
      controls: [Ruflet::UI::ControlFactory.build(:text, value: title)]
    )
  end

  def test_starts_with_a_single_webview_body
    Ruflet::Rails.native_app(@page, start_url: "https://myapp.com", paths: {})
    assert_equal 1, stack.length
    assert_equal "webview", webview.type
    assert_equal "https://myapp.com", webview.props["url"]
  end

  def test_matching_path_pushes_a_native_screen
    captured = nil
    Ruflet::Rails.native_app(
      @page, start_url: "https://myapp.com",
      paths: { %r{\A/products/(\d+)\z} => ->(ctx) { captured = ctx; native_screen("Product #{ctx.match[1]}") } }
    )

    @page.dispatch_event(target: webview.wire_id, name: "url_change", data: "https://myapp.com/products/42")

    assert_equal 2, stack.length, "a matched path pushes a native screen"
    assert_equal "/products/42", captured.path
    assert_equal "42", captured.match[1]
    assert find(stack.last, "text"), "the native screen is on top"
  end

  def test_unmatched_path_stays_in_the_webview
    Ruflet::Rails.native_app(
      @page, start_url: "https://myapp.com",
      paths: { "/cart" => ->(_ctx) { native_screen("Cart") } }
    )

    @page.dispatch_event(target: webview.wire_id, name: "url_change", data: "https://myapp.com/about")
    assert_equal 1, stack.length, "non-matching navigation stays in the webview"
  end

  def test_exact_string_path_matches
    Ruflet::Rails.native_app(
      @page, start_url: "https://myapp.com",
      paths: { "/cart" => ->(_ctx) { native_screen("Cart") } }
    )

    @page.dispatch_event(target: webview.wire_id, name: "url_change", data: "https://myapp.com/cart")
    assert_equal 2, stack.length
  end

  def test_back_button_pops_the_native_screen
    Ruflet::Rails.native_app(
      @page, start_url: "https://myapp.com",
      paths: { "/cart" => ->(_ctx) { native_screen("Cart") } }
    )
    @page.dispatch_event(target: webview.wire_id, name: "url_change", data: "https://myapp.com/cart")
    assert_equal 2, stack.length

    @page.dispatch_event(target: 1, name: "view_pop", data: nil)
    assert_equal 1, stack.length, "back returns to the webview"
  end

  def test_webview_body_persists_across_pushes
    Ruflet::Rails.native_app(
      @page, start_url: "https://myapp.com",
      paths: { "/cart" => ->(_ctx) { native_screen("Cart") } }
    )
    wv_before = webview.object_id
    @page.dispatch_event(target: webview.wire_id, name: "url_change", data: "https://myapp.com/cart")

    assert_equal wv_before, find(stack.first, "webview").object_id,
                 "the same webview instance stays at the base of the stack"
  end

  def test_native_chrome_is_passed_to_the_body
    bar = Ruflet::UI::ControlFactory.build(:bottomappbar)
    Ruflet::Rails.native_app(@page, start_url: "https://x", bottom_appbar: bar, paths: {})
    assert_same bar, stack.first.props["bottom_appbar"]
  end
end

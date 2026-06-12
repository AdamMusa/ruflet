# frozen_string_literal: true

require_relative "test_helper"

# Ruflet::Rails.webview_app builds a native shell (appbar + bottom nav) around a
# WebView body, and turns webview navigation into native navigation.
class RufletWebviewAppTest < Minitest::Test
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

  def body_of(view)
    view.props["controls"].first
  end

  def test_builds_a_view_with_native_chrome_and_a_webview_body
    appbar = Ruflet::UI::ControlFactory.build(:appbar, title: Ruflet::UI::ControlFactory.build(:text, value: "App"))
    navbar = Ruflet::UI::ControlFactory.build(:navigationbar,
                                              destinations: [
                                                Ruflet::UI::ControlFactory.build(:navigationbardestination, icon: "home", label: "Home"),
                                                Ruflet::UI::ControlFactory.build(:navigationbardestination, icon: "settings", label: "Settings")
                                              ])

    view = Ruflet::Rails.webview_app(
      url: "https://example.com",
      appbar: appbar,
      navigation_bar: navbar,
      route: "/"
    )

    assert_equal "view", view.type
    assert_equal "/", view.route
    assert_same appbar, view.props["appbar"]
    assert_same navbar, view.props["navigation_bar"]

    body = body_of(view)
    assert_equal "webview", body.type
    assert_equal "https://example.com", body.props["url"]
    assert_equal true, body.props["expand"]
  end

  def test_on_navigate_fires_with_the_target_url
    seen = []
    sent = []
    page = Ruflet::Page.new(session_id: "wa", client_details: {},
                            sender: ->(a, p) { sent << [a, p] })

    view = Ruflet::Rails.webview_app(
      url: "https://example.com",
      on_navigate: ->(target) { seen << target; page.go("/details") if target.include?("/product/") }
    )
    page.views = [view]
    page.update

    webview = find(view, "webview")
    page.dispatch_event(target: webview.wire_id, name: "url_change", data: "https://example.com/product/42")

    assert_equal ["https://example.com/product/42"], seen
    assert_equal "/details", page.route, "a matching link pushes a native route"
  end

  def test_prevent_links_pass_through
    view = Ruflet::Rails.webview_app(url: "https://x", prevent_links: ["https://x/native"])
    body = body_of(view)
    assert_equal ["https://x/native"], body.props["prevent_links"]
  end

  def test_block_yields_the_webview_for_later_control
    captured = nil
    Ruflet::Rails.webview_app(url: "https://x") { |wv| captured = wv }
    refute_nil captured
    assert_equal "webview", captured.type
    assert_respond_to captured, :run_javascript
  end

  def test_bottom_appbar_alternative_to_navigation_bar
    bar = Ruflet::UI::ControlFactory.build(:bottomappbar)
    view = Ruflet::Rails.webview_app(url: "https://x", bottom_appbar: bar)
    assert_same bar, view.props["bottom_appbar"]
  end
end

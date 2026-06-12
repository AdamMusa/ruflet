# frozen_string_literal: true

require_relative "test_helper"

# Hotwire Native-style driver. A JS bridge (injected on each page load) turns
# link clicks into "visit" console messages; native turns those into pushed
# screens, bottom-sheet modals, or native screens — declaratively.
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

  def stack = @page.views
  def top_webview = find(stack.last, "webview")

  # Simulate the JS bridge posting a console message from the top screen.
  def post(message, webview: top_webview)
    @page.dispatch_event(target: webview.wire_id, name: "console_message",
                         data: { "message" => message, "severity_level" => "log" })
  end

  def start(**opts)
    Ruflet::Rails.native_app(@page, start_url: "https://myapp.com", **opts)
  end

  # --- bridge -------------------------------------------------------------

  def test_bridge_js_intercepts_links_and_reports_title_and_visits
    js = Ruflet::Rails::NativeApp.bridge_js
    assert_includes js, "addEventListener"
    assert_includes js, "preventDefault"
    assert_includes js, 'report("visit"'
    assert_includes js, 'report("title"'
    assert_includes js, '"ruflet:"' # message channel prefix
    assert_includes js, "location.origin" # only same-origin links are captured
  end

  # --- out-of-the-box navigation -----------------------------------------

  def test_starts_with_one_webview_screen
    start
    assert_equal 1, stack.length
    assert_equal "https://myapp.com", top_webview.props["url"]
    assert_equal "view", stack.first.type
    refute_nil find(stack.first, "appbar"), "screen has a native appbar"
  end

  def test_a_link_visit_pushes_a_native_webview_screen
    start
    post("ruflet:visit:https://myapp.com/about")
    assert_equal 2, stack.length, "a proposed visit pushes a new screen"
    assert_equal "https://myapp.com/about", top_webview.props["url"]
  end

  def test_back_pops_the_pushed_screen
    start
    post("ruflet:visit:https://myapp.com/about")
    assert_equal 2, stack.length

    @page.dispatch_event(target: 1, name: "view_pop", data: nil)
    assert_equal 1, stack.length
  end

  # --- dynamic appbar -----------------------------------------------------

  def test_title_message_updates_the_appbar_title
    start(title: "My App")
    title_text = find(stack.first, "text")
    assert_equal "My App", title_text.props["value"]

    post("ruflet:title:Dashboard")
    assert_equal "Dashboard", title_text.props["value"], "appbar title tracks the page <title>"
  end

  def test_actions_lambda_is_resolved_into_the_appbar
    start(actions: -> { [Ruflet::UI::ControlFactory.build(:iconbutton, icon: "search")] })
    appbar = find(stack.first, "appbar")
    assert_equal 1, Array(appbar.props["actions"]).length
    assert_equal "iconbutton", appbar.props["actions"].first.type
  end

  # --- declarative path config -------------------------------------------

  def test_modal_path_opens_a_bottom_sheet_not_a_screen
    start(modal: ["/sign_in"])
    post("ruflet:visit:https://myapp.com/sign_in")

    assert_equal 1, stack.length, "modal paths do not push a screen"
    sheet = @page.instance_variable_get(:@bottom_sheet)
    refute_nil sheet, "a bottom sheet is presented"
    assert_equal "webview", find(sheet, "webview").type
    assert_equal "https://myapp.com/sign_in", find(sheet, "webview").props["url"]
  end

  def test_native_path_pushes_a_native_screen_with_match_data
    captured = nil
    start(native: {
            %r{\A/products/(\d+)\z} => lambda do |ctx|
              captured = ctx
              Ruflet::UI::ControlFactory.build(:view, route: "/p",
                                               controls: [Ruflet::UI::ControlFactory.build(:text, value: "Product #{ctx.match[1]}")])
            end
          })
    post("ruflet:visit:https://myapp.com/products/42")

    assert_equal 2, stack.length
    assert_equal "42", captured.match[1]
    refute find(stack.last, "webview"), "native screen has no webview"
    assert find(stack.last, "text")
  end

  def test_native_takes_precedence_over_modal
    hits = { native: 0 }
    start(
      modal: [%r{/x}],
      native: { %r{/x} => ->(_ctx) { hits[:native] += 1; Ruflet::UI::ControlFactory.build(:view, route: "/x", controls: [Ruflet::UI::ControlFactory.build(:text, value: "x")]) } }
    )
    post("ruflet:visit:https://myapp.com/x")
    assert_equal 1, hits[:native]
    assert_equal 2, stack.length
  end

  def test_unmatched_messages_are_ignored
    start
    post("some random console output")
    post("ruflet:visit:not a url ::::")
    assert_equal 1, stack.length
  end
end

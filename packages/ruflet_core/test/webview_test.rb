# frozen_string_literal: true

require_relative "test_helper"

# WebView parity with Flet. Method calls emit invoke_control_method frames whose
# name + args match exactly what flet_webview's Dart handler expects (verified
# against webview_mobile_and_mac.dart).
class RufletWebViewTest < Minitest::Test
  def mounted_webview(**props)
    sent = []
    page = Ruflet::Page.new(session_id: "wv", client_details: {},
                            sender: ->(action, payload) { sent << [action, payload] })
    wv = Ruflet::UI::ControlFactory.build(:webview, url: "https://example.com", **props)
    page.add(wv)
    sent.clear
    [page, wv, sent]
  end

  def last_invoke(sent)
    action, payload = sent.reverse.find { |a, _| a == Ruflet::Protocol::ACTIONS[:invoke_control_method] }
    refute_nil action, "expected an invoke_control_method frame"
    payload
  end

  def test_builds_with_new_props_and_events
    wv = Ruflet::UI::ControlFactory.build(
      :webview,
      url: "https://example.com",
      prevent_links: ["https://blocked.example"],
      on_progress: ->(_e) {},
      on_url_change: ->(_e) {},
      on_scroll: ->(_e) {},
      on_console_message: ->(_e) {},
      on_javascript_alert_dialog: ->(_e) {}
    )
    assert_equal ["https://blocked.example"], wv.props["prevent_links"]
    %w[progress url_change scroll console_message javascript_alert_dialog
       page_started page_ended web_resource_error].each do |ev|
      # on_* events that have handlers are advertised to the client.
    end
    assert wv.has_handler?(:progress)
    assert wv.has_handler?(:console_message)
    assert_equal true, wv.props["on_javascript_alert_dialog"]
  end

  def test_run_javascript_emits_the_exact_frame
    _page, wv, sent = mounted_webview
    wv.run_javascript("document.getElementById('x').remove()")

    payload = last_invoke(sent)
    assert_equal wv.wire_id, payload["control_id"]
    assert_equal "run_javascript", payload["name"]
    assert_equal({ "value" => "document.getElementById('x').remove()" }, payload["args"])
  end

  def test_navigation_and_storage_methods
    _page, wv, sent = mounted_webview

    { "reload" => -> { wv.reload },
      "go_back" => -> { wv.go_back },
      "go_forward" => -> { wv.go_forward },
      "clear_cache" => -> { wv.clear_cache },
      "clear_local_storage" => -> { wv.clear_local_storage },
      "enable_zoom" => -> { wv.enable_zoom },
      "disable_zoom" => -> { wv.disable_zoom } }.each do |name, call|
      sent.clear
      call.call
      assert_equal name, last_invoke(sent)["name"]
      assert_nil last_invoke(sent)["args"], "#{name} takes no args"
    end
  end

  def test_load_html_request_file_args
    _page, wv, sent = mounted_webview

    sent.clear
    wv.load_html("<h1>hi</h1>", base_url: "https://base.example")
    p = last_invoke(sent)
    assert_equal "load_html", p["name"]
    assert_equal({ "value" => "<h1>hi</h1>", "base_url" => "https://base.example" }, p["args"])

    sent.clear
    wv.load_request("https://x.example", method: "post")
    p = last_invoke(sent)
    assert_equal "load_request", p["name"]
    assert_equal({ "url" => "https://x.example", "method" => "post" }, p["args"])

    sent.clear
    wv.load_file("/tmp/page.html")
    assert_equal({ "path" => "/tmp/page.html" }, last_invoke(sent)["args"])
  end

  def test_scroll_methods_coerce_to_ints
    _page, wv, sent = mounted_webview
    wv.scroll_to("10", "20")
    assert_equal({ "x" => 10, "y" => 20 }, last_invoke(sent)["args"])

    sent.clear
    wv.scroll_by(5, 6)
    assert_equal({ "x" => 5, "y" => 6 }, last_invoke(sent)["args"])
  end

  def test_result_methods_register_a_callback
    _page, wv, sent = mounted_webview
    got = []
    wv.get_current_url { |value, _err| got << value }

    p = last_invoke(sent)
    assert_equal "get_current_url", p["name"]
    refute_nil p["call_id"]
  end

  def test_set_javascript_mode
    _page, wv, sent = mounted_webview
    wv.set_javascript_mode("unrestricted")
    p = last_invoke(sent)
    assert_equal "set_javascript_mode", p["name"]
    assert_equal({ "mode" => "unrestricted" }, p["args"])
  end

  def test_method_on_unmounted_webview_raises
    wv = Ruflet::UI::ControlFactory.build(:webview, url: "https://x")
    err = assert_raises(RuntimeError) { wv.run_javascript("1+1") }
    assert_match(/not mounted/, err.message)
  end
end

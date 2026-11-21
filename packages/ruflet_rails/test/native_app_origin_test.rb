# frozen_string_literal: true

require_relative "test_helper"

# The native shell's console bridge only listens to pages on a trusted origin
# (start_url's, or one listed in trusted_origins:). Any page the WebView shows
# can log a ruflet:* line, so a line from anywhere else must not reach native
# services, dialogs, screens, chrome or the CSRF-tokened request form.
class RufletNativeAppOriginTest < Minitest::Test
  APP = "https://myapp.com"
  OTHER = "https://other.example"

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

  def start(start_url: APP, **opts)
    Ruflet::Rails.native_shell(@page, start_url: start_url, **opts)
  end

  def body_webview
    find(@page.views.last, "webview")
  end

  def sheet
    @page.instance_variable_get(:@bottom_sheet)
  end

  def sheet_webview
    find(sheet, "webview")
  end

  def event(webview, name, data)
    @page.dispatch_event(target: webview.wire_id, name: name, data: data)
  end

  def log(message, webview: body_webview)
    event(webview, "console_message", { "message" => message, "severity_level" => "log" })
  end

  def action(payload, webview: body_webview)
    log("ruflet:action:#{JSON.generate(payload)}", webview: webview)
  end

  # A full navigation as the client reports it.
  def visit(url, webview: body_webview)
    event(webview, "page_started", url)
    event(webview, "page_ended", url)
  end

  def run_javascript_calls
    @sent.select { |a, p| a == 5 && p.is_a?(Hash) && p["name"] == "run_javascript" }
  end

  def scripts
    run_javascript_calls.map { |_a, p| p["args"]["value"] }
  end

  def probe_token(script)
    script[/ruflet:trust:(\h+)/, 1]
  end

  # The page answers the probe (window.location.origin was a trusted one).
  def answer_probe(webview: body_webview)
    token = probe_token(scripts.reverse.find { |js| probe_token(js) })
    refute_nil token, "a probe was sent"
    log("ruflet:trust:#{token}", webview: webview)
  end

  # Controls reference the page, so a failing assert_nil or refute_includes
  # on them would print the whole session. These keep failures short.
  def assert_none(value, message = nil)
    assert value.nil?, message || "expected nothing, got a #{value.class}"
  end

  def assert_sent(text, message = nil)
    assert @sent.inspect.include?(text), message || "expected the client to receive #{text.inspect}"
  end

  def refute_sent(text, message = nil)
    refute @sent.inspect.include?(text), message || "the client received #{text.inspect}"
  end

  def quietly(&block)
    _out, err = capture_io(&block)
    err
  end

  # --- foreign pages cannot drive the shell -------------------------------

  def test_foreign_page_cannot_invoke_services_dialogs_or_screens
    start
    visit("#{OTHER}/landing")
    @sent.clear

    err = quietly do
      action({ "component" => "clipboard", "text" => "attacker-text" })
      action({ "component" => "url", "url" => "tel:+19005550100" })
      action({ "component" => "share", "text" => "attacker-share" })
      action({ "component" => "dialog", "title" => "Session expired" })
      action({ "component" => "toast", "message" => "attacker-toast" })
      action({ "component" => "navigation", "action" => "push", "url" => "#{OTHER}/fake-login" })
      action({ "action" => "sheet", "url" => "#{OTHER}/sheet" })
    end

    %w[attacker-text tel:+19005550100 attacker-share Session\ expired attacker-toast fake-login].each do |value|
      refute_sent value
    end
    assert_none sheet, "no sheet opened"
    assert_equal "#{OTHER}/landing", body_webview.props["url"], "no screen pushed"
    assert_includes err, "native_shell ignored ruflet:action from https://other.example"
    assert_includes err, "https://myapp.com"
    assert_includes err, "trusted_origins"
  end

  def test_foreign_page_cannot_declare_native_chrome
    start
    visit("#{OTHER}/landing")
    quietly do
      log(%(ruflet:appbar:#{JSON.generate({ "title" => "Your Bank", "actions" => [{ "icon" => "lock", "url" => "/x" }] })}))
      log(%(ruflet:drawer:#{JSON.generate({ "items" => [{ "label" => "Pay", "icon" => "payments", "url" => "/pay" }] })}))
      log(%(ruflet:bottomnav:#{JSON.generate({ "items" => [{ "label" => "A", "icon" => "home", "url" => "/a" },
                                                           { "label" => "B", "icon" => "settings", "url" => "/b" }] })}))
      log(%(ruflet:rail:#{JSON.generate({ "items" => [{ "label" => "A", "icon" => "home", "url" => "/a" },
                                                      { "label" => "B", "icon" => "settings", "url" => "/b" }] })}))
    end

    assert_none find(@page.views.last, "appbar")
    assert_none @page.views.last.props["drawer"]
    assert_none find(@page.views.last, "navigationbar")
    assert_none find(@page.views.last, "navigationrail")
  end

  def test_foreign_page_gets_no_adapter_and_loses_the_previous_pages_chrome
    start
    visit("#{APP}/inbox")
    log(%(ruflet:appbar:#{JSON.generate({ "title" => "Inbox" })}))
    log(%(ruflet:drawer:#{JSON.generate({ "items" => [{ "label" => "Inbox", "icon" => "mail", "url" => "/inbox" }] })}))
    refute_nil find(@page.views.last, "appbar")
    refute_nil @page.views.last.props["drawer"]

    @sent.clear
    visit("#{OTHER}/article")

    assert_empty run_javascript_calls, "the adapter is not injected into a page on another origin"
    assert_none find(@page.views.last, "appbar"), "the AppBar is cleared, as the adapter's absent report did"
    assert_none @page.views.last.props["drawer"], "the drawer is cleared, as the adapter's absent report did"
  end

  def test_foreign_page_cannot_make_the_app_page_post_from_a_sheet_it_opened
    start(start_url: "#{APP}/dashboard")
    visit("#{APP}/posts/1")
    visit("#{OTHER}/landing")
    quietly { action({ "action" => "sheet", "url" => "#{OTHER}/sheet" }) }
    assert_none sheet
  end

  def test_third_party_sheet_cannot_make_the_app_page_post_with_its_csrf_token
    start(start_url: "#{APP}/dashboard")
    action({ "action" => "sheet", "url" => "https://help.thirdparty.example/faq" })
    refute_nil sheet, "the app itself may open a third-party page in a sheet"
    visit("https://help.thirdparty.example/faq", webview: sheet_webview)
    assert_empty run_javascript_calls, "the adapter is not injected into the third-party sheet"

    @sent.clear
    err = quietly do
      action({ "component" => "request", "url" => "#{APP}/account", "method" => "delete", "close" => false },
             webview: sheet_webview)
      action({ "component" => "clipboard", "text" => "attacker-text", "close" => false }, webview: sheet_webview)
      action({ "component" => "navigation", "action" => "root", "url" => "#{OTHER}/x", "close" => false },
             webview: sheet_webview)
    end

    assert_empty run_javascript_calls, "no request form in the app's page, and no probe for a page on another origin"
    refute_sent "attacker-text"
    assert_equal "#{APP}/dashboard", body_webview.props["url"]
    assert_includes err, "native_shell ignored ruflet:action from https://help.thirdparty.example"
  end

  def test_third_party_sheet_is_untrusted_before_its_first_page_event
    start
    action({ "action" => "sheet", "url" => "https://help.thirdparty.example/faq" })
    @sent.clear

    quietly do
      action({ "component" => "clipboard", "text" => "attacker-text", "close" => false }, webview: sheet_webview)
    end

    refute_sent "attacker-text"
  end

  def test_sheet_that_redirects_to_another_origin_stops_being_trusted
    start
    action({ "action" => "sheet", "url" => "#{APP}/quick" })
    event(sheet_webview, "page_started", "#{APP}/quick")
    action({ "component" => "clipboard", "text" => "own-sheet", "close" => false }, webview: sheet_webview)
    assert_sent "own-sheet", "the app's own sheet page drives the shell"

    event(sheet_webview, "url_change", "#{OTHER}/after-redirect")
    @sent.clear

    quietly do
      action({ "component" => "clipboard", "text" => "attacker-text", "close" => false }, webview: sheet_webview)
    end

    refute_sent "attacker-text"
    assert_equal true, sheet.props["open"], "the line was dropped, not deferred to the sheet closing"
  end

  def test_sheet_webview_subscribes_to_url_change_to_see_redirects
    start
    action({ "action" => "sheet", "url" => "#{APP}/quick" })
    assert_equal true, sheet_webview.props["on_url_change"]
  end

  # --- trust comes back only through the probe ----------------------------

  def test_own_page_after_a_foreign_one_is_verified_before_it_counts
    start
    visit("#{OTHER}/oauth")
    @sent.clear
    visit("#{APP}/callback")

    assert_equal 1, scripts.length
    probe = scripts.first
    assert_includes probe, "var o = window.location.origin;"
    assert_includes probe, %(o === "https://myapp.com")
    assert_includes probe, %(o === "https://www.myapp.com")
    refute_includes probe, "other.example"
    assert_includes probe, Ruflet::Rails::NativeApp.html_adapter_js,
                    "the adapter runs inside the probe, only once the origin check passes"
    assert probe.index("ruflet:trust:") < probe.index(Ruflet::Rails::NativeApp.html_adapter_js)

    quietly { log(%(ruflet:appbar:#{JSON.generate({ "title" => "Too early" })})) }
    assert_none find(@page.views.last, "appbar"), "nothing counts before the probe answers"

    answer_probe
    log(%(ruflet:appbar:#{JSON.generate({ "title" => "Welcome back" })}))
    assert_equal "Welcome back", find(find(@page.views.last, "appbar"), "text").props["value"]
  end

  def test_adapter_runs_only_once_the_probe_origin_check_passes
    start
    visit("#{OTHER}/oauth")
    @sent.clear
    visit("#{APP}/callback")
    probe = scripts.first
    adapter = Ruflet::Rails::NativeApp.html_adapter_js

    assert probe.end_with?("#{adapter}})();\n"), "the adapter is the last thing inside the probe function"
    assert probe.index("return;") < probe.index(adapter)

    node = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, "node") }
              .find { |path| File.executable?(path) }
    skip "node is not installed" unless node

    { "https://myapp.com" => true, "https://other.example" => false }.each do |origin, trusted|
      lines = run_probe_in_node(node, probe, origin)
      if trusted
        assert_equal "ruflet:trust:#{probe_token(probe)}", lines.first
        assert_includes lines, %(ruflet:appbar:{"absent":true}), "the adapter ran on #{origin}"
      else
        assert_empty lines, "neither the token nor the adapter ran on #{origin}"
      end
    end
  end

  def run_probe_in_node(node, probe, origin)
    harness = <<~JS
      var lines = [];
      var console = { log: function (line) { lines.push(String(line)); } };
      var document = { querySelector: function () { return null; }, addEventListener: function () {} };
      var window = { location: { origin: #{origin.to_json} }, innerWidth: 400 };
      #{probe}
      process.stdout.write(JSON.stringify(lines));
    JS
    path = File.join(Dir.tmpdir, "ruflet_probe_#{Process.pid}_#{SecureRandom.hex(4)}.js")
    File.write(path, harness)
    out = IO.popen([node, path], err: %i[child out], &:read)
    assert $?.success?, out
    JSON.parse(out)
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def test_a_reported_url_alone_does_not_restore_trust
    start
    visit("#{OTHER}/landing")
    # iOS reports page_ended with webView.url, which is already the next page
    # while the foreign document that started that navigation still runs.
    event(body_webview, "page_started", "#{APP}/")
    event(body_webview, "url_change", "#{APP}/")
    event(body_webview, "page_ended", "#{APP}/")
    @sent.clear

    quietly { action({ "component" => "clipboard", "text" => "attacker-text" }) }

    refute_sent "attacker-text"
  end

  def test_wrong_or_stale_probe_answers_are_ignored
    start
    visit("#{OTHER}/landing")
    visit("#{APP}/back")
    token = probe_token(scripts.last)

    log("ruflet:trust:#{"0" * token.length}")
    quietly { action({ "component" => "clipboard", "text" => "after-wrong-token" }) }
    refute_sent "after-wrong-token"

    event(body_webview, "page_started", "#{OTHER}/again")
    log("ruflet:trust:#{token}")
    quietly { action({ "component" => "clipboard", "text" => "after-stale-token" }) }
    refute_sent "after-stale-token", "a probe sent before a foreign navigation no longer counts"
  end

  def test_url_change_back_to_a_trusted_origin_probes_the_page
    start
    # A navigation that never commits (a download, a cancelled load) leaves the
    # app's page in place, but its foreign URL was reported.
    event(body_webview, "url_change", "https://bucket.storage.example/file.pdf")
    @sent.clear
    event(body_webview, "url_change", "#{APP}/files")
    assert_equal 1, scripts.length
    refute_includes scripts.first, Ruflet::Rails::NativeApp.html_adapter_js, "a bare probe, no adapter"

    answer_probe
    action({ "component" => "clipboard", "text" => "copied-again" })
    assert_sent "copied-again"
  end

  def test_untrusted_message_sends_one_probe_until_it_is_answered
    start
    visit("#{OTHER}/x")
    # Android reports page_started when the next page commits; the adapter
    # only comes with its page_ended.
    event(body_webview, "page_started", "#{APP}/y")
    @sent.clear

    quietly do
      action({ "component" => "clipboard", "text" => "first" })
      action({ "component" => "clipboard", "text" => "second" })
    end

    assert_equal 1, scripts.length, "one probe at a time"
    refute_sent "first"
    answer_probe
    action({ "component" => "clipboard", "text" => "third" })
    assert_sent "third"
  end

  def test_url_change_sends_a_fresh_probe_while_an_earlier_one_is_unanswered
    start
    visit("#{OTHER}/landing")
    event(body_webview, "url_change", "#{APP}/a") # the foreign page is still current and never answers
    @sent.clear

    # A back-forward cache restore reports only the URL.
    event(body_webview, "url_change", "#{APP}/b")
    assert_equal 1, scripts.length, "a fresh probe"
    answer_probe
    action({ "component" => "clipboard", "text" => "restored" })
    assert_sent "restored"
  end

  def test_an_earlier_probe_still_counts_after_a_newer_one
    start
    visit("#{OTHER}/oauth")
    visit("#{APP}/callback")
    with_adapter = probe_token(scripts.last)
    event(body_webview, "url_change", "#{APP}/home") # Turbo, before the page answered

    log("ruflet:trust:#{with_adapter}")
    log(%(ruflet:appbar:#{JSON.generate({ "title" => "Home" })}))
    assert_equal "Home", find(find(@page.views.last, "appbar"), "text").props["value"]
  end

  # --- a navigation in flight -------------------------------------------

  # iOS reports page_started and url_change as a navigation starts, while the
  # app's page still runs; nothing reports the commit. A probe that page
  # answered would hand its trust to the foreign page that replaces it.
  def test_no_probe_while_a_navigation_to_another_origin_is_in_flight
    start
    visit("#{APP}/posts/1")
    event(body_webview, "page_started", "#{OTHER}/landing")
    event(body_webview, "url_change", "#{OTHER}/landing")
    @sent.clear

    quietly { action({ "component" => "clipboard", "text" => "tap-in-the-app-page" }) }
    assert_empty run_javascript_calls, "no probe for the app's page to answer"
    refute_sent "tap-in-the-app-page"

    # The foreign page commits unannounced; its inline script runs.
    quietly do
      action({ "component" => "clipboard", "text" => "bc1-attacker-wallet" })
      action({ "component" => "url", "url" => "tel:+19005550100" })
    end
    assert_empty run_javascript_calls
    refute_sent "bc1-attacker-wallet"
    refute_sent "tel:+19005550100"
  end

  def test_adapter_reports_racing_a_navigation_to_another_origin_send_no_probe
    start
    event(body_webview, "page_started", "#{APP}/posts/1")
    event(body_webview, "page_ended", "#{APP}/posts/1")
    event(body_webview, "page_started", "#{OTHER}/landing") # the user followed an external link
    @sent.clear

    quietly { log(%(ruflet:appbar:#{JSON.generate({ "absent" => true })})) } # the adapter, still in the app page
    assert_empty run_javascript_calls
    quietly { action({ "component" => "dialog", "title" => "Session expired" }) }
    refute_sent "Session expired"
  end

  def test_a_navigation_to_another_origin_that_is_abandoned_is_verified_again
    start
    visit("#{APP}/posts/1")
    event(body_webview, "page_started", "#{OTHER}/report.zip")
    event(body_webview, "url_change", "#{OTHER}/report.zip")
    quietly { action({ "component" => "clipboard", "text" => "dropped" }) }
    @sent.clear

    # A download never commits; WKWebView's URL goes back to the app's page.
    event(body_webview, "url_change", "#{APP}/posts/1")
    assert_equal 1, scripts.length
    answer_probe
    action({ "component" => "clipboard", "text" => "copied" })
    assert_sent "copied"
  end

  # --- origins are read as the WebView reads them -------------------------

  # The WebView reports these as they are; URI.parse rejects them.
  OWN_URLS_URI_REJECTS = ["#{APP}/docs#intro#step-2", "#{APP}/tags/ruby|rails", "#{APP}/files/[draft]",
                          "#{APP}/search?q=%zz"].freeze

  def test_own_pages_whose_url_uri_rejects_keep_driving_the_shell
    start
    OWN_URLS_URI_REJECTS.each_with_index do |url, index|
      @sent.clear
      visit(url)
      assert_equal [Ruflet::Rails::NativeApp.html_adapter_js], scripts, "#{url} gets the adapter"
      action({ "component" => "clipboard", "text" => "own-page-#{index}" })
      assert_sent "own-page-#{index}", "#{url} still drives the shell"
    end
  end

  def test_userinfo_and_backslashes_do_not_hide_another_origin
    ["https://myapp.com@other.example/", "https://other.example\\@myapp.com/", "https://other.example#@myapp.com",
     "https://myapp.com:443@other.example/", "#{OTHER}/docs#a#b"].each_with_index do |url, index|
      setup
      start
      visit("#{APP}/inbox")
      event(body_webview, "page_started", url)
      quietly { action({ "component" => "clipboard", "text" => "from-page-#{index}" }) }
      refute_sent "from-page-#{index}", "#{url} is not on #{APP}"
    end
  end

  def test_request_targets_are_read_as_the_webview_reads_them
    start
    visit("#{APP}/items")
    @sent.clear

    quietly do
      ["https://myapp.com@other.example/x", "https://other.example\\@myapp.com/x", "https://other.example#@myapp.com",
       "/\\other.example/x", "\\\\other.example/x", "/\t/other.example/x", " //other.example/x",
       "java\tscript:alert(1)", " javascript:alert(1)", "https:\\\\other.example/x"].each do |url|
        action({ "component" => "request", "url" => url, "method" => "delete" })
      end
    end
    assert_empty run_javascript_calls

    # The last one is https://myapp.com/@other.example/x to a WebView.
    own = ["/items/ruby|rails", "?q=%zz", "#{APP}/items/[1]", "https://myapp.com\\@other.example/x"]
    own.each { |url| action({ "component" => "request", "url" => url, "method" => "delete" }) }
    assert_equal own.map { |url| %(form.action = #{url.to_json};) },
                 scripts.map { |js| js[/form\.action = .*;/] }, "the form is built as before"
  end

  def test_relative_request_target_on_a_page_whose_url_uri_rejects
    start
    visit("#{APP}/docs#intro#step-2")
    @sent.clear

    quietly do
      action({ "component" => "request", "url" => "//other.example/x", "method" => "delete" })
      action({ "component" => "request", "url" => "/\\other.example/x", "method" => "delete" })
    end
    assert_empty run_javascript_calls

    own = ["/items/1", "//myapp.com/items/2"]
    own.each { |url| action({ "component" => "request", "url" => url, "method" => "delete" }) }
    assert_equal own.map { |url| %(form.action = #{url.to_json};) },
                 scripts.map { |js| js[/form\.action = .*;/] }, "the target stays relative, as before"
  end

  def test_plain_console_output_from_a_foreign_page_is_ignored_silently
    start
    visit("#{OTHER}/landing")
    @sent.clear
    err = quietly { log("some site logging") }
    assert_empty err
    assert_empty @sent
  end

  # --- the request sink ---------------------------------------------------

  def test_request_goes_only_to_http_targets_on_a_trusted_origin
    start
    visit("#{APP}/settings")
    @sent.clear

    err = quietly do
      action({ "component" => "request", "url" => "javascript:alert(document.cookie)" })
      action({ "component" => "request", "url" => "data:text/html,hi" })
      action({ "component" => "request", "url" => "#{OTHER}/collect", "method" => "post" })
    end
    assert_empty run_javascript_calls
    assert_includes err, "ignored a request to a javascript: URL"
    assert_includes err, "ignored a request to https://other.example"

    action({ "component" => "request", "url" => "/account", "method" => "delete" })
    assert_equal 1, scripts.length
    assert_includes scripts.first, %(form.action = "https://myapp.com/account";)
    assert_includes scripts.first, "csrf-token"
  end

  def test_request_from_an_own_sheet_still_runs_in_the_page_under_it_after_it_closes
    start(start_url: "#{APP}/items")
    action({ "action" => "sheet", "url" => "#{APP}/items/1/confirm" })
    visit("#{APP}/items/1/confirm", webview: sheet_webview)
    sheet_control = sheet
    @sent.clear

    action({ "component" => "request", "url" => "#{APP}/items/1", "method" => "delete" }, webview: sheet_webview)
    assert_equal false, sheet_control.props["open"], "the sheet closes first"
    assert_empty run_javascript_calls

    sheet_control.emit("dismiss", Ruflet::Event.new(name: "dismiss", target: sheet_control.wire_id, raw_data: nil,
                                                    page: @page, control: sheet_control))
    calls = run_javascript_calls
    assert_equal [body_webview.wire_id], calls.map { |_a, p| p["control_id"] }
    assert_includes calls.first[1]["args"]["value"], %(form.action = "https://myapp.com/items/1";)
  end

  def test_request_is_not_sent_while_the_page_under_the_sheet_is_not_verified
    start
    action({ "action" => "sheet", "url" => "#{APP}/quick" })
    sheet_frame_webview = sheet_webview
    visit("#{OTHER}/landing")
    @sent.clear

    err = quietly do
      action({ "component" => "request", "url" => "#{APP}/account", "method" => "delete", "close" => false },
             webview: sheet_frame_webview)
    end

    assert_empty run_javascript_calls
    assert_includes err, "is not verified"
  end

  # --- trusted origins ----------------------------------------------------

  def test_trusted_origins_lets_the_apps_other_origins_drive_the_shell
    start(trusted_origins: ["https://auth.myapp.com", "https://accounts.myapp.com/any/path"])
    visit("https://auth.myapp.com/sign_in")
    action({ "component" => "clipboard", "text" => "from-auth" })
    visit("https://accounts.myapp.com/profile")
    action({ "component" => "clipboard", "text" => "from-accounts" })

    assert_sent "from-auth"
    assert_sent "from-accounts"
  end

  def test_http_start_url_trusts_its_https_form_and_www_twin
    start(start_url: "http://myapp.com")
    visit("https://www.myapp.com/")
    action({ "component" => "clipboard", "text" => "after-force-ssl" })
    assert_sent "after-force-ssl"

    visit("http://myapp.com:8080/")
    quietly { action({ "component" => "clipboard", "text" => "other-port" }) }
    refute_sent "other-port"
  end

  def test_www_start_url_trusts_the_bare_domain_but_not_other_subdomains
    start(start_url: "https://www.myapp.com")
    visit("https://myapp.com/")
    action({ "component" => "clipboard", "text" => "bare" })
    assert_sent "bare"

    visit("https://evil.myapp.com/")
    quietly { action({ "component" => "clipboard", "text" => "subdomain" }) }
    refute_sent "subdomain"
  end

  def test_https_start_url_does_not_trust_plain_http
    start
    visit("http://myapp.com/")
    quietly { action({ "component" => "clipboard", "text" => "downgraded" }) }
    refute_sent "downgraded"
  end

  def test_local_development_hosts_keep_their_port_and_get_no_www_twin
    start(start_url: "http://10.0.2.2:3000/")
    visit("http://10.0.2.2:3000/dashboard")
    action({ "component" => "clipboard", "text" => "dev" })
    assert_sent "dev"

    @sent.clear
    visit("http://10.0.2.2:3001/")
    visit("http://10.0.2.2:3000/back")
    assert_includes scripts.last, %(o === "http://10.0.2.2:3000")
    refute_includes scripts.last, "www."
  end

  def test_invalid_trusted_origin_is_rejected
    error = assert_raises(ArgumentError) { start(trusted_origins: ["auth.myapp.com"]) }
    assert_includes error.message, "auth.myapp.com"
  end

  # --- unchanged for the app's own pages ----------------------------------

  def test_own_pages_get_exactly_the_adapter_they_got_before
    start
    @sent.clear
    visit("#{APP}/inbox")
    visit("https://www.myapp.com/settings")
    action({ "action" => "sheet", "url" => "#{APP}/quick" })
    visit("#{APP}/quick", webview: sheet_webview)

    assert_equal [Ruflet::Rails::NativeApp.html_adapter_js,
                  Ruflet::Rails::NativeApp.html_adapter_js,
                  Ruflet::Rails::NativeApp.html_adapter_js(sheet: true)], scripts
  end

  def test_start_url_without_an_http_origin_keeps_the_previous_behavior
    start(start_url: "file:///android_asset/index.html")
    visit("#{OTHER}/landing")
    action({ "component" => "clipboard", "text" => "legacy" })
    assert_sent "legacy"
  end
end

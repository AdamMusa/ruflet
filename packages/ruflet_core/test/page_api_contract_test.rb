# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/page_api_contract"
require "timeout"

# The Page methods in test/support/page_api_contract.rb, one test each, and
# the Page methods no other test called.
class PageApiContractTest < Minitest::Test
  INVOKE_ACTION = Ruflet::Protocol::ACTIONS[:invoke_control_method]

  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "contract-session",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
    @page.add(Ruflet.text("root"))
    @sent.clear
  end

  # --- Methods that call the client -----------------------------------------

  PageApiContract::INVOKES.each do |method_name, spec|
    define_method("test_page_#{method_name.sub(/\?\z/, "_p")}_calls_#{spec.fetch(:name, method_name)}") do
      replies = []
      kwargs = {}
      takes_on_result = Ruflet::Page.instance_method(method_name).parameters.any? { |_, name| name == :on_result }
      kwargs[:on_result] = ->(*reply) { replies << reply } if takes_on_result

      call_id = @page.public_send(method_name, *spec.fetch(:args, []), **kwargs)

      payloads = @sent.select { |action, _| action == INVOKE_ACTION }.map(&:last)
      assert_equal 1, payloads.size
      payload = payloads.first
      assert_equal call_id, payload["call_id"]
      assert_equal spec.fetch(:name, method_name.delete_suffix("?")), payload["name"]
      assert_invoke_target(spec.fetch(:target), payload["control_id"])
      if spec.key?(:sends)
        assert_equal spec[:sends], payload["args"]
      else
        assert_nil payload["args"]
      end
      return unless takes_on_result

      assert @page.handle_invoke_method_result("call_id" => call_id, "result" => "answer", "error" => nil)
      assert_equal [["answer", nil]], replies
    end
  end

  # --- Service accessors ----------------------------------------------------

  PageApiContract::SERVICES.each do |accessor, type|
    define_method("test_page_#{accessor}_mounts_one_#{type}_service") do
      service = @page.public_send(accessor, key: "contract")

      assert_equal type, service.type
      assert_equal "contract", service.props["key"]
      assert_includes @page.services, service
      refute_nil service.wire_id
      assert_same service, @page.public_send(accessor, key: "contract"), "a second call refreshes the same service"
      if PageApiContract::PROXIES.include?(accessor)
        refute_kind_of Ruflet::Control, @page.public_send(accessor), "without props it returns the proxy"
      else
        assert_same service, @page.public_send(accessor)
      end

      assert @sent.any? { |_, payload| payload["id"] == services_wire_id }, "mounting it patches the service registry"
    end
  end

  PageApiContract::VISUAL.each do |accessor, props|
    define_method("test_page_#{accessor}_builds_a_control_without_mounting_it") do
      control = @page.public_send(accessor, **props.transform_values(&:call))

      assert_equal accessor, control.type
      refute_includes @page.services, control
      assert_nil control.wire_id
    end
  end

  # --- Page properties ------------------------------------------------------

  PROP_SAMPLES = {
    "title" => -> { "Contract" },
    "horizontal_alignment" => -> { "center" },
    "vertical_alignment" => -> { "end" },
    "route" => -> { "/contract" },
    "bgcolor" => -> { "#a1b2c3" },
    "padding" => -> { 12 },
    "spacing" => -> { 8 },
    "decoration" => -> { { "bgcolor" => "#ffffff" } },
    "foreground_decoration" => -> { { "bgcolor" => "#000000" } },
    "auto_scroll" => -> { true },
    "floating_action_button_location" => -> { "end_float" },
    "appbar" => -> { Ruflet.app_bar(title: Ruflet.text("Title")) },
    "bottom_appbar" => -> { Ruflet.bottom_app_bar },
    "navigation_bar" => -> { Ruflet.navigation_bar(destinations: []) },
    "drawer" => -> { Ruflet.navigation_drawer },
    "end_drawer" => -> { Ruflet.navigation_drawer },
    "floating_action_button" => -> { Ruflet.floating_action_button(icon: "add") },
    "browser_context_menu" => -> { Ruflet.browser_context_menu }
  }.freeze

  PageApiContract::PROPS.each do |prop, place|
    define_method("test_page_#{prop}_is_read_back_and_sent_on_the_#{place}") do
      value = PROP_SAMPLES.fetch(prop).call
      @page.public_send("#{prop}=", value)

      assert_equal value, @page.public_send(prop)
      @page.update
      assert_equal wire(value), sent_page_value(prop, place)
    end
  end

  def test_bottomappbar_writer_sets_bottom_appbar
    bar = Ruflet.bottom_app_bar
    @page.bottomappbar = bar

    assert_same bar, @page.bottom_appbar
  end

  # --- Methods no other test called ------------------------------------------

  def test_bottom_sheet_writers_host_the_sheet_in_the_dialogs_container
    sheet = Ruflet.bottom_sheet(content: Ruflet.text("Sheet"))
    @page.bottom_sheet = sheet

    assert_same sheet, @page.bottom_sheet
    assert_includes dialogs_container_children, sheet

    other = Ruflet.bottom_sheet(content: Ruflet.text("Other"))
    @page.bottomsheet = other
    assert_same other, @page.bottom_sheet
  end

  def test_snack_bar_writers_and_show_snack_bar_host_and_open_the_snack_bar
    snack = Ruflet.snack_bar(content: Ruflet.text("Saved"))
    @page.snack_bar = snack

    assert_same snack, @page.snack_bar
    assert_includes dialogs_container_children, snack

    other = Ruflet.snack_bar(content: Ruflet.text("Again"))
    @page.snackbar = other
    assert_same other, @page.snack_bar

    shown = Ruflet.snack_bar(content: Ruflet.text("Shown"))
    @page.show_snack_bar(shown)
    assert_equal true, shown.props["open"]
    assert_includes dialogs_container_children, shown
  end

  def test_pop_dialog_closes_the_open_dialog
    dialog = Ruflet.alert_dialog(title: Ruflet.text("Hello"))
    @page.show_dialog(dialog)
    @sent.clear

    @page.pop_dialog

    assert_equal false, dialog.props["open"]
    refute_empty @sent
  end

  def test_go_sets_the_route_with_its_query_and_runs_on_route_change
    events = []
    @page.on_route_change = ->(event) { events << event }

    @page.go("/store", tab: "shoes")

    assert_equal "/store?tab=shoes", @page.route
    assert_equal({ "tab" => "shoes" }, @page.query)
    assert_equal 1, events.size
    refute_empty @sent, "go sends the view patch"
  end

  def test_on_view_pop_runs_when_the_client_pops_a_view
    popped = []
    @page.on_view_pop = ->(event) { popped << event }

    @page.dispatch_event(target: 1, name: "view_pop", data: { "route" => "/details" })

    assert_equal 1, popped.size
    assert_equal "view_pop", popped.first.name.to_s
  end

  def test_patch_page_updates_a_control_like_update
    label = Ruflet.text("Before")
    @page.add(label)
    @sent.clear

    @page.patch_page(label, value: "After")

    assert_equal "After", label.props["value"]
    payload = @sent.map(&:last).find { |message| message["id"] == label.wire_id }
    refute_nil payload
    assert_includes payload["patch"].map { |op| op[2] }, "value"
  end

  def test_invoke_sync_waits_for_the_reply_and_raises_its_error
    target = Ruflet.text("target")
    @page.add(target)

    result = with_reply(result: "done") { @page.invoke_sync(target, "ping", args: { "n" => 1 }, timeout: 2) }
    assert_equal "done", result
    payload = @sent.select { |action, _| action == INVOKE_ACTION }.last[1]
    assert_equal target.wire_id, payload["control_id"]
    assert_equal "ping", payload["name"]
    assert_equal({ "n" => 1 }, payload["args"])

    error = assert_raises(RuntimeError) do
      with_reply(error: "no such method") { @page.invoke_sync(target, "ping", timeout: 2) }
    end
    assert_equal "no such method", error.message
  end

  def test_remove_service_takes_the_control_its_id_or_its_type
    battery = @page.battery
    clipboard = @page.clipboard
    share = @page.share

    @page.remove_service(battery)
    refute_includes @page.services, battery

    @page.remove_service(clipboard.id)
    refute_includes @page.services, clipboard

    @page.remove_service("share")
    refute_includes @page.services, share
  end

  def test_services_writer_replaces_the_mounted_services
    @page.battery
    clipboard = Ruflet::UI::ControlFactory.build("clipboard")
    @sent.clear

    @page.services = [clipboard, nil]

    assert_equal [clipboard], @page.services
    refute_nil clipboard.wire_id
    refute_empty @sent, "the service registry is patched"
  end

  def test_replay_route_after_reload_reruns_on_route_change_once_unless_the_app_routed
    @page.go("/orders")
    @page.reset_for_reload!
    routes = []
    @page.on_route_change = ->(event) { routes << event.data }

    @page.replay_route_after_reload!
    assert_equal ["/orders"], routes

    @page.reset_for_reload!
    @page.on_route_change = ->(event) { routes << event.data }
    @page.go("/cart")
    @page.replay_route_after_reload!
    assert_equal ["/orders", "/cart"], routes, "an app that routed itself is not replayed"
  end

  def test_session_id_is_the_one_the_page_was_built_with
    assert_equal "contract-session", @page.session_id
  end

  def test_unknown_page_props_go_through_method_missing
    @page.theme_mode = "dark"

    assert_equal "dark", @page.theme_mode
    assert @page.respond_to?(:theme_mode=)
    @page.update
    assert_equal "dark", sent_page_value("theme_mode", :page)

    assert_raises(NoMethodError) { @page.text = "x" }
    assert_raises(NoMethodError) { @page.not_a_prop }
  end

  private

  def assert_invoke_target(target, control_id)
    case target
    when :page then assert_equal 1, control_id
    when :view then assert_equal @page.instance_variable_get(:@view_id), control_id
    else
      service = @page.services.find { |candidate| candidate.wire_id == control_id }
      refute_nil service, "the call targets a mounted service"
      assert_equal target, service.type
    end
  end

  def services_wire_id
    @page.instance_variable_get(:@services_container).wire_id
  end

  def dialogs_container_children
    @page.instance_variable_get(:@dialogs_container).props["controls"] || []
  end

  def wire(value)
    value.is_a?(Ruflet::Control) ? value.to_patch : value
  end

  # The value the last page patch sent for +prop+, on the page or its view.
  def sent_page_value(prop, place)
    ops = @sent.map(&:last).select { |payload| payload["id"] == 1 }.flat_map { |payload| payload["patch"][1..] }
    if place == :page
      ops.reverse.find { |op| op[2] == prop }&.last
    else
      ops.reverse.find { |op| op[2] == "views" }&.last&.first&.dig(prop)
    end
  end

  def with_reply(result: nil, error: nil)
    before = @sent.size
    caller = Thread.new { yield }
    caller.report_on_exception = false
    payload = Timeout.timeout(2) do
      sleep 0.005 until @sent[before..].any? { |action, _| action == INVOKE_ACTION }
      @sent[before..].find { |action, _| action == INVOKE_ACTION }[1]
    end
    @page.handle_invoke_method_result("call_id" => payload["call_id"], "result" => result, "error" => error)
    caller.value
  end
end

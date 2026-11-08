# frozen_string_literal: true

require_relative "test_helper"

# Where a page prop lands (the Page control, its implicit View, or both),
# where an event subscription flag lands, and which control each page method
# invokes. Every entry point that assigns page props (page.x =,
# set_view_props, which the DSL's page(...) calls, and update(:page, ...))
# routes through the same table, so these pin that table for every built-in
# key.
class RufletPageRegistriesTest < Minitest::Test
  BUILT_IN_PAGE_PROPS = %w[
    dark_theme fonts route rtl show_semantics_debugger theme theme_mode
    theme_animation_style title
  ].freeze
  BUILT_IN_PAGE_AND_VIEW_PROPS = %w[vertical_alignment horizontal_alignment scroll].freeze
  # Keys that are Page keywords on the client but are routed to the View
  # today (RT-02 moves some of them); pinned so that a refactor cannot move
  # them by accident.
  VIEW_PROPS = %w[
    bgcolor padding spacing locale_configuration platform enable_screenshots
    auto_scroll decoration not_a_known_prop
  ].freeze

  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/", "platform" => "android" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def invokes
    @sent.select { |action, _payload| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }.map(&:last)
  end

  def implicit_view(patch)
    patch.fetch("views").first
  end

  def assert_routed(key, page:, view:, patch:)
    value = "value-#{key}"
    assert_equal page, patch.key?(key) && patch[key] == value, "#{key} on the Page"
    assert_equal view, implicit_view(patch)[key] == value, "#{key} on the View"
  end

  def test_the_built_in_constant_is_unchanged
    assert_equal BUILT_IN_PAGE_PROPS + BUILT_IN_PAGE_AND_VIEW_PROPS, Ruflet::Page::PAGE_PROP_KEYS
    assert Ruflet::Page::PAGE_PROP_KEYS.frozen?
    assert_equal %w[dialog snack_bar bottom_sheet], Ruflet::Page::DIALOG_PROP_KEYS
  end

  def test_every_entry_point_routes_each_built_in_key_the_same_way
    keys = BUILT_IN_PAGE_PROPS + BUILT_IN_PAGE_AND_VIEW_PROPS + VIEW_PROPS
    entry_points = {
      "set_view_props" => ->(page, key, value) { page.set_view_props(key => value) },
      "set_view_props (symbol)" => ->(page, key, value) { page.set_view_props(key.to_sym => value) },
      "public setter" => ->(page, key, value) { page.public_send(:"#{key}=", value) },
      "method_missing setter" => ->(page, key, value) { page.__send__(:method_missing, :"#{key}=", value) },
      "update(:page)" => ->(page, key, value) { page.update(:page, key.to_sym => value) }
    }

    entry_points.each do |entry, assign|
      keys.each do |key|
        setup
        assign.call(@page, key, "value-#{key}")
        patch = @page.register_page_patch
        page_side = BUILT_IN_PAGE_PROPS.include?(key) || BUILT_IN_PAGE_AND_VIEW_PROPS.include?(key)
        # The implicit View always carries the page route.
        view_side = !BUILT_IN_PAGE_PROPS.include?(key) || key == "route"
        assert_routed(key, page: page_side, view: view_side, patch: patch)
      rescue Minitest::Assertion => e
        raise Minitest::Assertion, "#{entry}: #{e.message}"
      end
    end
  end

  def test_dialog_slots_are_not_props
    dialog = Ruflet.alert_dialog(title: Ruflet.text("Hi"))
    @page.set_view_props("dialog" => dialog)
    patch = @page.register_page_patch

    assert_same dialog, @page.dialog
    refute patch.key?("dialog")
    refute implicit_view(patch).key?("dialog")
    assert_equal [dialog.to_patch["_i"]], patch["_dialogs"]["controls"].map { |control| control["_i"] }
  end

  def test_event_flags_land_where_they_do_today
    handler = ->(_event) {}

    # Setter form: View events flag the View, every other event the Page.
    @page.on_scroll = handler
    @page.on_resize = handler
    @page.on_keyboard_event = handler
    @page.on_made_up_event = handler
    # Page#on flags View events only; Page events get no flag from it.
    @page.on(:end_reached) {}
    @page.on(:media_change) {}
    @page.on(:on_locale_change) {}
    @page.on(:route_change) {}

    patch = @page.register_page_patch
    view = implicit_view(patch)
    assert_equal true, view["on_scroll"]
    assert_equal true, view["on_end_reached"]
    assert_equal true, patch["on_resize"]
    assert_equal true, patch["on_keyboard_event"]
    assert_equal true, patch["on_made_up_event"]
    %w[on_media_change on_locale_change on_route_change].each do |flag|
      refute patch.key?(flag), "#{flag} on the Page"
      refute view.key?(flag), "#{flag} on the View"
    end
    %w[on_resize on_keyboard_event on_made_up_event].each { |flag| refute view.key?(flag), flag }
    refute patch.key?("on_scroll")

    # Clearing: a Page flag becomes an explicit nil, a View flag disappears.
    @page.on_resize = nil
    @page.on_scroll = nil
    @page.on(:end_reached)
    patch = @page.register_page_patch
    assert patch.key?("on_resize")
    assert_nil patch["on_resize"]
    refute implicit_view(patch).key?("on_scroll")
    assert_equal true, implicit_view(patch)["on_end_reached"], "Page#on without a block leaves the View flag"
  end

  def test_page_methods_invoke_the_same_controls_and_names
    @page.drawer = Ruflet.navigation_drawer([Ruflet.navigation_drawer_destination(icon: "home")])
    @page.end_drawer = Ruflet.navigation_drawer([Ruflet.navigation_drawer_destination(icon: "search")])
    @page.add(Ruflet.text("Body"))
    @page.update
    @sent.clear

    @page.get_device_info
    @page.get_device_info(timeout: 3, on_result: ->(_info, _error) {})
    @page.set_allowed_device_orientations(%i[portrait_up landscape_left], timeout: nil)
    @page.set_allowed_device_orientations([])
    @page.show_drawer
    @page.close_drawer(timeout: 5)
    @page.show_end_drawer(timeout: nil)
    @page.close_end_drawer
    @page.scroll_to(offset: 10, duration: 200)
    @page.scroll_to

    wire = invokes.map { |payload| payload.reject { |key, _| key == "call_id" } }
    view = 20
    assert_equal [
      { "control_id" => 1, "name" => "get_device_info", "args" => nil, "timeout" => 10 },
      { "control_id" => 1, "name" => "get_device_info", "args" => nil, "timeout" => 3 },
      { "control_id" => 1, "name" => "set_allowed_device_orientations",
        "args" => { "orientations" => %w[portraitUp landscapeLeft] } },
      { "control_id" => 1, "name" => "set_allowed_device_orientations",
        "args" => { "orientations" => [] }, "timeout" => 10 },
      { "control_id" => view, "name" => "show_drawer", "args" => nil, "timeout" => 10 },
      { "control_id" => view, "name" => "close_drawer", "args" => nil, "timeout" => 5 },
      { "control_id" => view, "name" => "show_end_drawer", "args" => nil },
      { "control_id" => view, "name" => "close_end_drawer", "args" => nil, "timeout" => 10 },
      { "control_id" => view, "name" => "scroll_to",
        "args" => { "offset" => 10, "delta" => nil, "scroll_key" => nil, "duration" => 200, "curve" => nil },
        "timeout" => 10 },
      { "control_id" => view, "name" => "scroll_to",
        "args" => { "offset" => nil, "delta" => nil, "scroll_key" => nil, "duration" => nil, "curve" => nil },
        "timeout" => 10 }
    ], wire
    assert_equal wire.map { |payload| payload.keys }, invokes.map { |payload| payload.keys - ["call_id"] }
  end

  def test_get_device_info_sync_waits_on_the_page
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/", "platform" => "android" },
      sender: lambda do |action, payload|
        @sent << [action, payload]
        if action == Ruflet::Protocol::ACTIONS[:invoke_control_method]
          Thread.new { @sync_page.handle_invoke_method_result("call_id" => payload["call_id"], "result" => { "model" => "Pixel" }) }
        end
      end
    )
    @sync_page = page

    info = page.get_device_info_sync(timeout: 2)

    assert_equal "Pixel", info.model
    payload = invokes.last
    assert_equal({ "control_id" => 1, "name" => "get_device_info", "args" => nil, "timeout" => 2 },
                 payload.reject { |key, _| key == "call_id" })
  end
end

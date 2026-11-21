# frozen_string_literal: true

require_relative "test_helper"

# The client methods Flet's View, Dismissible, Pagelet and KeyboardListener
# have, called the way an app calls them: from the handler that asks for the
# answer (view.dart and dismissible.dart wait for confirm_pop and
# confirm_dismiss), or on a mounted control. What each sends is also
# specified in test/support/method_contracts/control.rb.
class ConfirmAndDrawerMethodsTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" },
                             sender: ->(action, payload) { @sent << [action, payload] })
  end

  def invokes
    @sent.select { |action, _| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }
         .map { |_, payload| [payload["control_id"], payload["name"], payload["args"]] }
  end

  def test_on_confirm_pop_answers_with_view_confirm_pop
    saved = false
    view = Ruflet.view(route: "/edit", can_pop: false, on_confirm_pop: ->(e) { e.control.confirm_pop(saved) })
    @page.add(view)
    @sent.clear

    @page.dispatch_event(target: view.wire_id, name: "confirm_pop", data: nil)
    saved = true
    @page.dispatch_event(target: view.wire_id, name: "confirm_pop", data: nil)

    assert_equal [
      [view.wire_id, "confirm_pop", { "should_pop" => false }],
      [view.wire_id, "confirm_pop", { "should_pop" => true }]
    ], invokes
  end

  def test_view_confirm_pop_defaults_to_popping
    view = Ruflet.view(on_confirm_pop: ->(e) { e.control.confirm_pop })
    @page.add(view)
    @sent.clear

    @page.dispatch_event(target: view.wire_id, name: "confirm_pop", data: nil)

    assert_equal [[view.wire_id, "confirm_pop", { "should_pop" => true }]], invokes
  end

  def test_on_confirm_dismiss_answers_with_dismissible_confirm_dismiss
    item = Ruflet.dismissible(
      Ruflet.text("Swipe"),
      on_confirm_dismiss: ->(e) { e.control.confirm_dismiss(e.data["direction"] == "endToStart") }
    )
    @page.add(item)
    @sent.clear

    @page.dispatch_event(target: item.wire_id, name: "confirm_dismiss", data: { "direction" => "endToStart" })
    @page.dispatch_event(target: item.wire_id, name: "confirm_dismiss", data: { "direction" => "startToEnd" })

    assert_equal [
      [item.wire_id, "confirm_dismiss", { "dismiss" => true }],
      [item.wire_id, "confirm_dismiss", { "dismiss" => false }]
    ], invokes
  end

  def test_view_and_pagelet_drawer_methods_target_their_own_control
    view = Ruflet.view(drawer: Ruflet.navigation_drawer(controls: []), controls: [Ruflet.text("v")])
    pagelet = Ruflet.pagelet(content: Ruflet.text("p"), drawer: Ruflet.navigation_drawer(controls: []),
                             end_drawer: Ruflet.navigation_drawer(controls: []))
    @page.add(Ruflet.column(controls: [view, pagelet]))
    @sent.clear

    [view, pagelet].each do |control|
      control.show_drawer
      control.close_drawer
      control.show_end_drawer
      control.close_end_drawer
    end

    names = %w[show_drawer close_drawer show_end_drawer close_end_drawer]
    assert_equal names.map { |name| [view.wire_id, name, nil] } + names.map { |name| [pagelet.wire_id, name, nil] }, invokes
  end

  def test_keyboard_listener_focus_requests_focus
    listener = Ruflet.keyboard_listener(content: Ruflet.text("Keys"), on_key_down: ->(_e) {})
    @page.add(listener)
    @sent.clear

    listener.focus

    assert_equal [[listener.wire_id, "focus", {}]], invokes
  end

  def test_unmounted_controls_send_nothing
    controls = {
      view: Ruflet.view,
      dismissible: Ruflet.dismissible(Ruflet.text("x")),
      pagelet: Ruflet.pagelet(content: Ruflet.text("p")),
      keyboard_listener: Ruflet.keyboard_listener(content: Ruflet.text("k"))
    }

    assert_nil controls[:view].confirm_pop
    assert_nil controls[:view].show_drawer
    assert_nil controls[:dismissible].confirm_dismiss
    assert_nil controls[:pagelet].close_end_drawer
    assert_nil controls[:keyboard_listener].focus
    assert_empty @sent
  end
end

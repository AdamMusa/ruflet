# frozen_string_literal: true

require_relative "test_helper"

# Page#reload_transaction is how a hot reload re-renders a live page: what the
# page sends is held until the reload finishes, and a reload that raises is
# undone, so the client keeps the last working UI and the page still matches it.
class RufletPageReloadTransactionTest < Minitest::Test
  PATCH = Ruflet::Protocol::ACTIONS[:patch_control]
  INVOKE = Ruflet::Protocol::ACTIONS[:invoke_control_method]

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end

  def text(id, value)
    Ruflet::Control.new(type: "Text", id: id, value: value)
  end

  # The page as the client has it after registering: rendered, with the
  # register response's full state published.
  def rendered_page(sent, &render)
    page = build_page(sent)
    render.call(page)
    page.register_page_patch
    sent.clear
    page
  end

  def first_render(page)
    page.title = "Counter"
    page.on_route_change = ->(_e) { nil }
    page.add(text("header", "header"))
    page.add(text("body", "body"))
    page.overlay << text("toast", "toast")
  end

  # What Server#reload_app! runs inside the transaction.
  def rerender(page)
    page.reset_for_reload!
    yield page
    page.finalize_reload!
    page.replay_route_after_reload!
    page.update
  end

  def second_render(page)
    page.title = "Counter v2"
    page.add(text("header2", "header v2"))
    page.add(text("body2", "body v2"))
    page.overlay << text("toast2", "toast v2")
  end

  def test_a_reload_transaction_sends_what_a_direct_reload_sends_once_it_returns
    direct_sent = []
    direct = rendered_page(direct_sent) { |page| first_render(page) }
    rerender(direct) { |page| second_render(page) }

    sent = []
    page = rendered_page(sent) { |p| first_render(p) }
    held_while_running = nil
    page.reload_transaction do
      rerender(page) { |p| second_render(p) }
      held_while_running = sent.dup
    end

    assert_empty held_while_running, "nothing goes out while the reload runs"
    refute_empty direct_sent
    assert_equal direct_sent, sent, "a reload that completes sends the same messages, in the same order"
  end

  def test_a_reload_transaction_whose_block_raises_sends_nothing_and_puts_the_page_back
    sent = []
    page = rendered_page(sent) { |p| first_render(p) }
    handlers = page.instance_variable_get(:@page_event_handlers).dup
    controls = page.controls.dup

    error = assert_raises(NameError) do
      page.reload_transaction do
        rerender(page) do |p|
          p.title = "Broken"
          p.add(text("header2", "header v2"))
          p.overlay << text("toast2", "toast v2")
          raise NameError, "undefined local variable or method 'footer_text' for main"
        end
      end
    end

    assert_includes error.message, "footer_text"
    assert_empty sent, "a failed reload sends nothing: the client keeps the last working UI"
    assert_equal controls, page.controls
    assert_equal %w[header body], page.controls.map(&:id)
    assert_equal "Counter", page.title
    assert_equal ["toast"], page.overlay.map(&:id)
    assert_equal handlers, page.instance_variable_get(:@page_event_handlers)

    page.update
    assert_empty sent, "the page still matches what the client shows, so a bare update has nothing to send"

    page.add(text("row", "new row"))
    _action, payload = sent.last
    view = payload["patch"].find { |op| op.is_a?(Array) && op[2] == "views" }[3].first
    assert_equal %w[header body new\ row], view["controls"].map { |control| control["value"] }
  end

  def test_a_failed_reload_transaction_keeps_page_handlers_and_services
    sent = []
    page = rendered_page(sent) do |p|
      p.add(text("body", "body"))
      p.add_service(Ruflet::Control.new(type: "Clipboard", id: "clip"))
    end
    resized = []
    page.on_resize = ->(_e) { resized << :v1 }

    assert_raises(RuntimeError) do
      page.reload_transaction do
        page.reset_for_reload!
        page.add_service(Ruflet::Control.new(type: "Wakelock", id: "lock"))
        raise "boom"
      end
    end

    assert_equal ["clip"], page.services.map(&:id)
    page.dispatch_event(target: 1, name: "resize", data: {})
    assert_equal [:v1], resized, "a page handler the failed block cleared still runs"
  end

  def test_a_synchronous_invoke_sends_what_the_reload_holds_first
    sent = []
    page = nil
    sender = lambda do |action, payload|
      sent << [action, payload]
      next unless action == INVOKE

      Thread.new { page.handle_invoke_method_result("call_id" => payload["call_id"], "result" => "ok") }
    end
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: sender)
    page.add(text("body", "body"))
    page.register_page_patch
    sent.clear

    result = nil
    assert_raises(RuntimeError) do
      page.reload_transaction do
        page.reset_for_reload!
        page.add(text("body2", "body v2"))
        result = page.invoke_sync(:page, "probe", timeout: 2)
        raise "after the invoke"
      end
    end

    assert_equal "ok", result, "the client got the invoke and answered it"
    assert_equal [PATCH, INVOKE], sent.map(&:first), "what the reload held goes out before the invoke"
    assert_equal %w[body2], page.controls.map(&:id),
                 "once the reload went out it is not undone: the page matches what the client got"
  end
end

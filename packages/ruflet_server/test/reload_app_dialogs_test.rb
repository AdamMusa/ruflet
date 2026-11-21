# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../ruflet_core/test/support/dialogs_client"

# Server#reload_app! closes the dialogs that are open, then re-runs the app
# block on the same page. A dialog it closed must stay on the client until
# the client reports it closed: removed from the Dialogs list in the same
# frame as its `open: false` (as when the reloaded block shows a snack bar
# and the whole list was sent again), its route was never popped and a modal
# stayed on screen over the reloaded app.
class RufletReloadAppDialogsTest < Minitest::Test
  class FakeWs
    def session_key
      object_id
    end

    def closed?
      false
    end

    def send_binary(_bytes); end
  end

  def test_reload_closes_an_open_modal_when_the_block_shows_a_snack_bar
    reloaded = false
    server = Ruflet::Server.new(port: 0) do |page|
      page.add(Ruflet.text("Body"))
      page.show_snack_bar(Ruflet.snack_bar(content: Ruflet.text("Reloaded"))) if reloaded
    end
    page, client = start_session(server)
    step(client) { page.show_dialog(Ruflet.alert_dialog(title: Ruflet.text("Modal D"), modal: true)) }
    assert_equal 1, client.visible("Modal D")

    reloaded = true
    step(client) { server.reload_app! }

    assert_equal 0, client.visible("Modal D")
    assert_equal 1, client.visible("Reloaded")
    assert_empty client.stuck

    settle(client, page)
    step(client) { page.show_dialog(Ruflet.alert_dialog(title: Ruflet.text("After"))) }
    assert_equal [0, 1], [client.visible("Modal D"), client.visible("After")]
    assert_empty client.stuck
  end

  def test_reload_closes_an_open_modal_when_the_block_shows_nothing
    server = Ruflet::Server.new(port: 0) { |page| page.add(Ruflet.text("Body")) }
    page, client = start_session(server)
    step(client) { page.show_dialog(Ruflet.alert_dialog(title: Ruflet.text("Modal D"), modal: true)) }

    step(client) { server.reload_app! }
    settle(client, page)

    assert_equal 0, client.visible("Modal D")
    assert_empty client.stuck
  end

  private

  def start_session(server)
    @sent = []
    ws = FakeWs.new
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/" },
      sender: ->(_action, payload) { @sent << payload }
    )
    server.instance_variable_get(:@sessions)[ws.session_key] = page
    server.instance_variable_get(:@connections)[ws.session_key] = ws
    client = DialogsClient.new
    step(client) { server.instance_variable_get(:@app_block).call(page) }
    [page, client]
  end

  def step(client)
    yield
    @sent.each { |payload| client.receive(payload) }
    @sent.clear
    client.frame!
  end

  def settle(client, page)
    step(client) { client.deliver_report(page) } while client.pending_reports?
  end
end

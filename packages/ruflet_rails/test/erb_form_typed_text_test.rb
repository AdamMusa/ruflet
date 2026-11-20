# frozen_string_literal: true

require_relative "test_helper"

# An ERB-to-native form posts what the user typed, as Rails params are:
# Strings, also when the text looks like a number or like JSON. Driven
# through the ConnectionProtocol receiver ruflet_rails uses, with the frames
# textfield.dart sends on each keystroke (update_control, then change with
# the text as data).
class ErbFormTypedTextTest < Minitest::Test
  ACTIONS = Ruflet::Protocol::ACTIONS

  class FakeWs
    attr_reader :sent

    def initialize
      @sent = []
    end

    def session_key
      object_id
    end

    def closed?
      false
    end

    def close; end

    def send_binary(bytes)
      @sent << bytes
    end
  end

  class StubFetcher
    Response = Ruflet::Rails::HtmlDsl::TemplateSource::Response
    attr_reader :submitted

    def fetch(url, params: nil)
      path = URI.parse(url).path
      @submitted = params if path == "/orders"
      body =
        if path == "/orders"
          "<text>saved</text>"
        else
          <<~HTML
            <form action="/orders" method="post">
              <input type="text" name="zip" label="ZIP">
              <input type="text" name="price" label="Price">
              <input type="text" name="note" label="Note">
              <input type="text" name="tags" label="Tags">
              <input type="submit" value="Save">
            </form>
          HTML
        end
      Response.new(body: body, url: url)
    end
  end

  class ProtocolHost
    include Ruflet::ConnectionProtocol

    def initialize(&app_block)
      @app_block = app_block
      @sessions = {}
      @sessions_mutex = Mutex.new
    end
  end

  def controls_of_type(node, type, found = [])
    case node
    when Ruflet::Control
      found << node if node.type == type
      node.props.each_value { |value| controls_of_type(value, type, found) }
      node.children.each { |child| controls_of_type(child, type, found) }
    when Array
      node.each { |value| controls_of_type(value, type, found) }
    end
    found
  end

  def test_typed_text_reaches_the_controller_as_typed
    fetcher = StubFetcher.new
    host = ProtocolHost.new { |page| Ruflet::Rails.erb_to_native(page, start_url: "/", fetcher: fetcher) }
    ws = FakeWs.new
    receive = ->(action, payload) { host.handle_message(ws, Ruflet::WireCodec.pack([action, payload])) }
    receive.call(ACTIONS[:register_client], { "session_id" => "", "page" => { "route" => "/" } })
    page = host.instance_variable_get(:@sessions)[ws.session_key]

    zip, price, note, tags = controls_of_type(page.views, "textfield")
    { zip => "12345", price => "19.90", note => "null", tags => "[1]" }.each do |field, typed|
      receive.call(ACTIONS[:update_control], { "id" => field.wire_id, "props" => { "value" => typed } })
      receive.call(ACTIONS[:control_event], { "target" => field.wire_id, "name" => "change", "data" => typed })
    end
    save = controls_of_type(page.views, "filledbutton").first
    receive.call(ACTIONS[:control_event], { "target" => save.wire_id, "name" => "click", "data" => "" })

    assert_equal({ "zip" => "12345", "price" => "19.90", "note" => "null", "tags" => "[1]" }, fetcher.submitted)
  end
end

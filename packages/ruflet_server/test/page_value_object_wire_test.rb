# frozen_string_literal: true

require_relative "test_helper"

# Value-object props (Ruflet::TextStyle, Offset, Duration) reach the wire as
# the map construction sends, through every Page patch path. Before the fix
# WireCodec packed them as "#<Ruflet::UI::Types::TextStyle:0x...>", which the
# renderer's parseTextStyle throws on, and every bare update re-sent them.
class RufletPageValueObjectWireTest < Minitest::Test
  ACTIONS = Ruflet::Protocol::ACTIONS

  class AppHost
    include Ruflet::ConnectionProtocol

    def initialize(&app)
      @app_block = app
      @sessions = {}
      @sessions_mutex = Mutex.new
    end

    def log_connection_error(error)
      raise error
    end

    def session_removed(_page, _ws); end

    def page_for(ws)
      @sessions_mutex.synchronize { @sessions[ws.session_key] }
    end
  end

  class FakeWs
    attr_reader :sent

    def initialize
      @sent = []
    end

    def session_key = object_id
    def closed? = false
    def close; end

    def send_binary(bytes)
      @sent << bytes
    end
  end

  def strings_in(value)
    case value
    when String then [value]
    when Hash then value.flat_map { |k, v| strings_in(k) + strings_in(v) }
    when Array then value.flat_map { |v| strings_in(v) }
    else []
    end
  end

  def build_page(frames)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { frames << Ruflet::WireCodec.pack([action, payload]) }
    )
  end

  def decode(frames)
    frames.map { |frame| Ruflet::WireCodec.unpack(frame) }
  end

  def patches_for(decoded, control)
    decoded.select { |action, payload| action == ACTIONS[:patch_control] && payload["id"] == control.wire_id }
           .flat_map { |_action, payload| payload["patch"].drop(1) }
  end

  def test_register_flow_sends_the_style_map_and_no_follow_up_patch
    title = nil
    host = AppHost.new do |page|
      page.title = "Demo"
      title = Ruflet.text("Hello", style: Ruflet::TextStyle.new(size: 28, weight: "bold"))
      page.add(title)
    end
    ws = FakeWs.new

    host.handle_message(ws, Ruflet::WireCodec.pack([ACTIONS[:register_client],
                                                    { "session_id" => "s-1", "page" => { "route" => "/" } }]))

    decoded = decode(ws.sent)
    assert_empty strings_in(decoded).grep(/#<Ruflet::/), "no value object is packed as a string"
    assert_empty patches_for(decoded, title), "the server's bare update after the app block has nothing to send"
    assert_equal({ "size" => 28, "weight" => "bold" }, title.to_patch["style"])
  end

  def test_targeted_and_bare_updates_round_trip_as_maps
    frames = []
    page = build_page(frames)
    title = Ruflet.text("Title", style: Ruflet::TextStyle.new(size: 28, weight: "bold"))
    box = Ruflet.container(offset: Ruflet::Offset.new(x: 1, y: 0),
                           animate: Ruflet::Duration.new(milliseconds: 300),
                           content: Ruflet.text("x"))
    counter = Ruflet.text("0")
    page.add(Ruflet.column(controls: [title, box, counter]))

    frames.clear
    counter.props["value"] = "1"
    page.update
    page.update
    decoded = decode(frames)
    assert_empty patches_for(decoded, title)
    assert_empty patches_for(decoded, box)
    assert_equal [[0, 0, "value", "1"]], patches_for(decoded, counter)

    frames.clear
    page.update(title, style: Ruflet::TextStyle.new(size: 30))
    page.update(box, offset: Ruflet::Offset.new(x: 0, y: 0.5), animate: Ruflet::Duration.new(milliseconds: 150))
    decoded = decode(frames)
    assert_equal [[0, 0, "style", { "size" => 30 }]], patches_for(decoded, title)
    assert_equal [[0, 0, "offset", { "x" => 0, "y" => 0.5 }], [0, 0, "animate", { "milliseconds" => 150 }]],
                 patches_for(decoded, box)
    assert_empty strings_in(decoded).grep(/#<Ruflet::/)
  end

  def test_docs_route_pattern_does_not_resend_the_style
    frames = []
    page = build_page(frames)
    page.views = [Ruflet.view(route: "/", controls: [Ruflet.text("Home", style: Ruflet::TextStyle.new(size: 20))])]
    page.update

    assert_empty strings_in(decode(frames)).grep(/#<Ruflet::/)
    frames.clear
    page.update
    assert_empty frames, "a bare update with nothing changed sends nothing"
  end
end

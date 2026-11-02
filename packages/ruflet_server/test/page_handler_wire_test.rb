# frozen_string_literal: true

require_relative "test_helper"

# A page-level handler must never be packed onto the wire, whatever page API
# it arrives through (before the fix WireCodec packed it as "#<Proc:...>"),
# and it must be registered so events from the default page View reach it.
class RufletPageHandlerWireTest < Minitest::Test
  ENTRY_POINTS = {
    "page.on_scroll = handler" => ->(page, handler) { page.on_scroll = handler },
    "page.set_view_props(on_scroll:)" => ->(page, handler) { page.set_view_props(on_scroll: handler) },
    "DSL page(on_scroll:) at startup" => lambda do |page, handler|
      app = Ruflet::DSL::App.new(host: "127.0.0.1", port: 0).page(on_scroll: handler)
      page.set_view_props(app.page_props.dup) # what DSL::App#run does per session
    end,
    "page.update(:page, on_scroll:)" => ->(page, handler) { page.update(:page, on_scroll: handler) },
    "page.on(:scroll) { }" => ->(page, handler) { page.on(:scroll, &handler) }
  }.freeze

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

  def decoded_view(frames)
    decoded = frames.map { |frame| Ruflet::WireCodec.unpack(frame) }
    views = decoded.reverse_each.lazy.map do |_action, payload|
      next nil unless payload.is_a?(Hash) && payload["patch"].is_a?(Array)

      payload["patch"].find { |op| op.is_a?(Array) && op[2] == "views" }
    end.find { |op| op }
    [decoded, views[3].first]
  end

  ENTRY_POINTS.each do |label, assign|
    define_method("test_#{label.gsub(/\W+/, '_')}_sends_a_flag_and_registers_the_handler") do
      frames = []
      calls = []
      page = build_page(frames)
      assign.call(page, ->(e) { calls << e.name })
      page.add(Ruflet.text("Body"))
      page.update(:page, padding: 4) # a later page update must not leak it either

      decoded, view = decoded_view(frames)
      assert_empty strings_in(decoded).grep(/#<(Proc|Method)/), label
      assert_equal true, view["on_scroll"], label

      page.dispatch_event(target: view["_i"], name: "scroll", data: { "pixels" => 1.0 })
      assert_equal ["scroll"], calls, label
    end
  end

  def test_page_handlers_pack_as_boolean_flags
    frames = []
    page = build_page(frames)
    page.on_refresh = ->(_e) {}
    page.on_scroll = ->(_e) {}
    page.add(Ruflet.text("Body"))

    decoded, view = decoded_view(frames)
    assert_empty strings_in(decoded).grep(/#<(Proc|Method)/)
    assert_equal true, view["on_refresh"]
    assert_equal true, view["on_scroll"]
  end
end

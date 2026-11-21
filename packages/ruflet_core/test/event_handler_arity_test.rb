# frozen_string_literal: true

require_relative "test_helper"

# A handler that takes no parameters is called without the event, as in Flet
# (base_control.py calls a handler without parameters without its event). A
# lambda or Method of arity 0 raised ArgumentError on every event before.
# Every other handler still gets the event.
class EventHandlerArityTest < Minitest::Test
  class Counter
    attr_reader :calls

    def initialize
      @calls = []
    end

    def refresh
      @calls << :refresh
    end

    def clicked(event)
      @calls << [:clicked, event.name]
    end

    def clicked_maybe(event = nil)
      @calls << [:clicked_maybe, event&.name]
    end
  end

  class Callable
    attr_reader :events

    def initialize
      @events = []
    end

    def call(event)
      @events << event.name
    end
  end

  def setup
    @page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
  end

  def click(control)
    @page.dispatch_event(target: control.wire_id, name: "click", data: nil)
  end

  def test_zero_parameter_lambda_handlers_run_without_the_event
    hits = []
    keyword = Ruflet.button("A", on_click: -> { hits << :keyword })
    later = Ruflet.button("B")
    later.on(:click, &-> { hits << :block_lambda })
    @page.add(Ruflet.column(controls: [keyword, later]))

    click(keyword)
    click(later)

    assert_equal %i[keyword block_lambda], hits
  end

  def test_handlers_with_parameters_still_get_the_event
    seen = []
    counter = Counter.new
    callable = Callable.new
    buttons = [
      Ruflet.button("lambda", on_click: ->(e) { seen << [:lambda, e.name] }),
      Ruflet.button("optional", on_click: ->(e = nil) { seen << [:optional, e&.name] }),
      Ruflet.button("splat", on_click: ->(*args) { seen << [:splat, args.size] }),
      Ruflet.button("proc0", on_click: proc { seen << [:proc0] }),
      Ruflet.button("proc1", on_click: proc { |e| seen << [:proc1, e.name] }),
      Ruflet.button("method1", on_click: counter.method(:clicked)),
      Ruflet.button("method_optional", on_click: counter.method(:clicked_maybe)),
      Ruflet.button("callable", on_click: callable)
    ]
    block = Ruflet.button("block")
    block.on(:click) { |e| seen << [:block, e.name] }
    @page.add(Ruflet.column(controls: buttons + [block]))

    (buttons + [block]).each { |button| click(button) }

    assert_equal [[:lambda, "click"], [:optional, "click"], [:splat, 1], [:proc0], [:proc1, "click"], [:block, "click"]], seen
    assert_equal [[:clicked, "click"], [:clicked_maybe, "click"]], counter.calls
    assert_equal ["click"], callable.events
  end

  def test_zero_parameter_method_handlers_run_without_the_event
    counter = Counter.new
    button = Ruflet.button("Refresh", on_click: counter.method(:refresh))
    @page.add(button)

    click(button)

    assert_equal [:refresh], counter.calls
  end

  def test_zero_parameter_page_handlers_run_without_the_event
    hits = []
    @page.on_route_change = -> { hits << :route_change }
    @page.on(:view_pop, &-> { hits << :view_pop })
    @page.on_keyboard_event = -> { hits << :keyboard_event }

    @page.dispatch_event(target: 1, name: "route_change", data: "/next")
    @page.dispatch_event(target: 1, name: "view_pop", data: "/next")
    @page.dispatch_event(target: 1, name: "keyboard_event", data: { "key" => "A" })

    assert_equal %i[route_change view_pop keyboard_event], hits
  end

  def test_zero_parameter_service_handlers_run_without_the_event
    hits = []
    flashlight = Ruflet.flashlight(on_error: -> { hits << :error })
    @page.add_service(flashlight)

    @page.dispatch_event(target: flashlight.wire_id, name: "error", data: { "message" => "no torch" })

    assert_equal [:error], hits
  end

  def test_zero_parameter_material2_change_handler_runs_without_the_event
    hits = []
    dropdown = Ruflet.dropdown_m2([Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")], value: "red",
                                  on_change: -> { hits << :change })
    @page.add(dropdown)

    @page.apply_client_update(dropdown.wire_id, { "value" => "blue" })
    @page.dispatch_event(target: dropdown.wire_id, name: "select", data: "blue")

    assert_equal [:change], hits
  end

  def test_a_zero_parameter_handler_that_raises_still_raises
    button = Ruflet.button("Boom", on_click: -> { raise ArgumentError, "from the handler" })
    @page.add(button)

    error = assert_raises(ArgumentError) { click(button) }
    assert_equal "from the handler", error.message
  end
end

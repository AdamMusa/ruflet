# frozen_string_literal: true

require_relative "test_helper"

class RufletControlMethodsCompatibilityTest < Minitest::Test
  INVOKE = Ruflet::Protocol::ACTIONS[:invoke_control_method]

  def setup
    @messages = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @messages << [action, payload] }
    )
  end

  def mount(control)
    @page.add(control)
    @messages.clear
    control
  end

  def invokes
    @messages.select { |action, _payload| action == INVOKE }.map(&:last)
  end

  def calls
    invokes.map { |payload| [payload["name"], payload["args"]] }
  end

  def test_text_field_focus_and_blur_invoke_the_client
    field = mount(Ruflet.text_field(label: "Email"))

    field.focus
    field.blur(timeout: 3)

    assert_equal [["focus", {}], ["blur", {}]], calls
    assert_equal [field.wire_id, field.wire_id], invokes.map { |payload| payload["control_id"] }
    assert_equal 3, invokes.last["timeout"]
  end

  def test_cupertino_text_field_focus_and_blur_invoke_the_client
    field = mount(Ruflet.cupertino_text_field(placeholder_text: "Name"))

    field.focus
    field.blur

    assert_equal "TextField", field.to_patch["_c"]
    assert_equal [["focus", {}], ["blur", {}]], calls
  end

  def test_buttons_icon_buttons_and_dropdowns_focus
    controls = [
      Ruflet.button("Go"),
      Ruflet.elevated_button("Go"),
      Ruflet.filled_button("Go"),
      Ruflet.filled_tonal_button("Go"),
      Ruflet.outlined_button("Go"),
      Ruflet.text_button("Go"),
      Ruflet.cupertino_button("Go"),
      Ruflet.cupertino_filled_button("Go"),
      Ruflet.cupertino_tinted_button("Go"),
      Ruflet.icon_button("add"),
      Ruflet.filled_icon_button("add"),
      Ruflet.filled_tonal_icon_button("add"),
      Ruflet.outlined_icon_button("add"),
      Ruflet.dropdown([Ruflet.dropdown_option("a")]),
      Ruflet.dropdown_m2([Ruflet.dropdown_option("a")])
    ]
    controls.each { |control| @page.add(control) }
    @messages.clear

    controls.each(&:focus)

    assert_equal controls.map(&:wire_id), invokes.map { |payload| payload["control_id"] }
    assert_equal [["focus", {}]] * controls.length, calls
  end

  def test_blur_is_only_offered_by_text_inputs
    refute_respond_to Ruflet.button("Go"), :blur
    refute_respond_to Ruflet.icon_button("add"), :blur
    assert_respond_to Ruflet.text_field, :blur
  end

  def test_page_view_paging_methods_send_the_args_the_client_reads
    pager = mount(Ruflet.page_view([Ruflet.text("One"), Ruflet.text("Two"), Ruflet.text("Three")]))

    pager.next_page
    pager.next_page(duration: 300, curve: "easeInOut")
    pager.previous_page(duration: 200)
    pager.go_to_page(2, duration: 400, curve: :easeOut)
    pager.go_to_page(1)
    pager.jump_to_page(0)
    pager.jump_to(120.5)

    assert_equal [
      ["next_page", {}],
      ["next_page", { "duration" => 300, "curve" => "easeInOut" }],
      ["previous_page", { "duration" => 200 }],
      ["go_to_page", { "index" => 2, "duration" => 400, "curve" => "easeOut" }],
      ["go_to_page", { "index" => 1 }],
      ["jump_to_page", { "index" => 0 }],
      ["jump_to", { "value" => 120.5 }]
    ], calls
    assert(invokes.all? { |payload| payload["control_id"] == pager.wire_id })
  end

  def test_tabs_move_to_sends_index_duration_and_curve
    tabs = mount(Ruflet.tabs(length: 3, content: Ruflet.text("Body")))

    tabs.move_to(2, duration: 250, curve: "ease")
    tabs.move_to(-1)

    assert_equal [
      ["move_to", { "index" => 2, "duration" => 250, "curve" => "ease" }],
      ["move_to", { "index" => -1 }]
    ], calls
  end

  def test_canvas_capture_methods
    results = []
    canvas = mount(Ruflet.canvas([Ruflet.control(:circle, x: 5, y: 6, radius: 7)]))

    canvas.capture(pixel_ratio: 2.0)
    canvas.capture
    call_id = canvas.get_capture(on_result: ->(result, error) { results << [result, error] })
    canvas.clear_capture

    assert_equal [
      ["capture", { "pixel_ratio" => 2.0 }],
      ["capture", {}],
      ["get_capture", {}],
      ["clear_capture", {}]
    ], calls
    assert_equal call_id, invokes[2]["call_id"]
  end

  def test_methods_are_safe_when_the_control_is_not_on_a_page
    [
      -> { Ruflet.text_field.focus },
      -> { Ruflet.text_field.blur },
      -> { Ruflet.button("Go").focus },
      -> { Ruflet.page_view([]).next_page },
      -> { Ruflet.page_view([]).go_to_page(1) },
      -> { Ruflet.tabs(length: 1).move_to(0) },
      -> { Ruflet.canvas([]).capture }
    ].each { |call| assert_nil call.call }
    assert_empty @messages
  end
end

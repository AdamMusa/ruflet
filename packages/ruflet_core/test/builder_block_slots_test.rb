# frozen_string_literal: true

require_relative "test_helper"

# A builder's block fills its control's child slot (#135). Before, 96
# builders with a slot took no block, so Ruby dropped it: `list_view { ... }`
# and `card { ... }` went on the wire empty, and `bottom_sheet { ... }` and
# `safe_area { ... }` raised "requires content". container, gesture_detector,
# pagelet, tabs, navigation_bar, navigation_rail and tab_bar ran their block
# but sent its controls under "controls", which their renderers never read.
#
# A control that is pressed (a content slot and an on_click event) never runs
# its block: `elevated_button(on_click: h) { save }` written as a handler
# would otherwise run `save` while the page is built. A block beside a slot
# passed explicitly is not run either, unless it was before #135.
class RufletBuilderBlockSlotsTest < Minitest::Test
  # Every child slot a builder's block can fill, by wire key.
  SLOT_KEYS = %w[content controls actions destinations items options tabs rows shapes segments steps slivers header_slivers].freeze

  # Props or positional arguments a builder cannot be built without.
  REQUIRED = {
    "expansion_tile" => [[], { title: "T" }],
    "nested_scroll_view" => [[], { body: -> { Ruflet.text("body") } }],
    "stepper_step" => [[], { title: "A" }],
    # Pressed controls require content; their block never provides it.
    "action_sheet_action" => [[], { content: "x" }],
    "context_menu_action" => [[], { content: "x" }],
    "cupertino_action_sheet_action" => [[], { content: "x" }],
    "cupertino_context_menu_action" => [[], { content: "x" }],
    "cupertino_dialog_action" => [[], { content: "x" }]
  }.freeze

  # Builders that need two children: the contract block builds a second.
  TWO_CHILDREN = %w[cupertino_segmented_button cupertino_sliding_segmented_button].freeze

  # The builders that ran their block before #135 even when the slot was
  # passed too, and still do. column and its kin put the block's controls
  # before the passed ones; container and the other legacy builders send them
  # under "controls". Every other builder leaves the block unrun.
  RAN_BESIDE_A_GIVEN_SLOT = %w[
    carousel_view center column container custom_scroll_view drag_target draggable draggable_scrollable_sheet
    form gesture_detector grid_view indexed_stack list_section navigation_bar navigation_rail nested_scroll_view
    pagelet responsive_row row sliver_grid sliver_list sliver_padding stack stepper tab_bar tab_bar_view table
    table_row tabs view
  ].freeze

  Probe = Class.new(StandardError)

  def setup
    Ruflet::DSL._reset_pending_app!
    Ruflet::UI::BlockSlots.reset_warnings!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
    Ruflet::UI::BlockSlots.reset_warnings!
  end

  # -- Contract: every WidgetBuilder method with a child slot ----------------

  def test_every_slot_builder_fills_a_declared_slot_from_its_block
    checked = 0
    slot_builders.each do |name, klass, slots|
      next if pressed?(klass)

      ran = false
      args, props = required_for(name)
      control = Ruflet::WidgetBuilder.new.public_send(name, *args, **props, &contract_block(name) { ran = true })
      patch = control.to_patch

      assert ran, "#{name} runs its block"
      key = slots.find { |slot| holds_block_text?(patch[slot]) }
      assert key, "#{name} puts its block's control in one of #{slots.inspect}: #{patch.keys.inspect}"
      refute patch.key?("controls") && !slots.include?("controls"),
             "#{name} sends no controls key its class does not declare"
      checked += 1
    end
    assert_operator checked, :>=, 120, "slot builders checked"
  end

  def test_pressed_controls_never_run_their_block
    pressed = slot_builders.select { |_name, klass, _slots| pressed?(klass) }.map(&:first)
    expected = %w[
      action_sheet_action button context_menu_action cupertino_action_sheet_action cupertino_button
      cupertino_context_menu_action cupertino_dialog_action cupertino_filled_button cupertino_tinted_button
      elevated_button fab filled_button filled_tonal_button floating_action_button menu_item_button option
      outlined_button popup_menu_item text_button
    ]
    assert_equal expected, pressed.reject { |name| compact_alias?(name) }.sort

    pressed.each do |name|
      Ruflet::UI::BlockSlots.reset_warnings!
      ran = false
      args, props = required_for(name)
      props = { content: "x" }.merge(props)
      without = Ruflet::WidgetBuilder.new.public_send(name, *args, **props).to_patch
      control = nil
      _out, err = capture_io do
        control = Ruflet::WidgetBuilder.new.public_send(name, *args, **props) { ran = true; text("from block") }
      end

      refute ran, "#{name} does not run its block"
      assert_equal without, control.to_patch, "#{name} with a block sends what it sends without one"
      assert_match(/does not run its block/, err, "#{name} says it ignored its block")
    end
  end

  # Every way of calling a slot builder hands it the block: Ruflet.*,
  # Ruflet::UI.*, Ruflet::DSL.*, the bare helper and a DSL app.
  def test_every_forwarder_hands_the_block_to_the_builder
    slot_builders.each do |name, klass, _slots|
      next if pressed?(klass)

      args, props = required_for(name)
      block = contract_block(name)
      want = Ruflet::WidgetBuilder.new.public_send(name, *args, **props, &block).to_patch
      {
        "Ruflet" => -> { Ruflet.public_send(name, *required_for(name)[0], **required_for(name)[1], &block) },
        "Ruflet::UI" => -> { Ruflet::UI.public_send(name, *required_for(name)[0], **required_for(name)[1], &block) },
        "Ruflet::DSL" => -> { Ruflet::DSL.public_send(name, *required_for(name)[0], **required_for(name)[1], &block) },
        "bare" => -> { Object.new.send(name, *required_for(name)[0], **required_for(name)[1], &block) },
        "app" => -> { Ruflet::DSL.app.public_send(name, *required_for(name)[0], **required_for(name)[1], &block) }
      }.each do |via, call|
        assert_equal want, call.call.to_patch, "#{via}.#{name} { ... }"
      end
    end
  end

  # A call that passes the slot its block would fill sends what it sent
  # before #135: the block is not run, and a warning says so. Only the
  # builders that ran such a block before still run it.
  def test_a_block_beside_a_given_slot_is_not_run_unless_it_was_before
    ran_anyway = []
    checked = 0
    slot_builders.each do |name, klass, _slots|
      next if pressed?(klass)

      args, props = required_for(name)
      key = filled_key(name)
      assert key, "#{name} fills a slot from its block"
      given = -> { props.merge(key.to_sym => given_value(name, key)) }
      without = Ruflet::WidgetBuilder.new.public_send(name, *args, **given.call).to_patch

      Ruflet::UI::BlockSlots.reset_warnings!
      ran = false
      control = nil
      _out, err = capture_io do
        control = Ruflet::WidgetBuilder.new.public_send(name, *args, **given.call, &contract_block(name) { ran = true })
      end
      checked += 1
      if ran
        ran_anyway << name
        next
      end

      assert_equal without, control.to_patch, "#{name}(#{key}: ...) { ... } sends what it sends without the block"
      assert_match(/ignores its block because \w+: was given/, err, "#{name} says it ignored its block")
    end

    assert_equal RAN_BESIDE_A_GIVEN_SLOT, ran_anyway.reject { |name| compact_alias?(name) }.sort
    assert_operator checked, :>=, 150, "slot builders checked"
  end

  def test_a_passed_children_list_keeps_a_list_builders_block_unrun
    ran = []
    list = search = segmented = nil
    _out, err = capture_io do
      list = Ruflet.list_view([Ruflet.text("given")]) { ran << :list; text("block") }
      search = Ruflet.search_bar(controls: [Ruflet.text("suggestion")], on_change: ->(_e) {}) { |_e| ran << :search }
      segmented = Ruflet.segmented_button([Ruflet.segment("a")], selected: ["a"]) { ran << :segmented; segment("b") }
    end

    assert_empty ran
    assert_equal ["given"], list.to_patch["controls"].map { |c| c["value"] }
    assert_equal ["suggestion"], search.to_patch["controls"].map { |c| c["value"] }
    assert_equal ["a"], segmented.to_patch["segments"].map { |s| s["value"] }
    refute segmented.to_patch.key?("controls")
    assert_match(/list_view ignores its block because children: was given/, err)
    assert_match(/search_bar ignores its block because controls: was given/, err)
    assert_match(/segmented_button ignores its block because segments: was given/, err)
  end

  # -- What the block fills ---------------------------------------------------

  def test_list_view_block_builds_its_controls_like_column
    list = Ruflet.list_view(spacing: 4) { text("a"); text("b") }
    column = Ruflet.column(spacing: 4) { text("a"); text("b") }

    assert_equal %w[a b], list.to_patch["controls"].map { |c| c["value"] }
    assert_equal column.to_patch["controls"], list.to_patch["controls"]
  end

  def test_content_slot_builders_fill_content
    assert_equal "x", Ruflet.card { text("x") }.to_patch["content"]["value"]
    assert_equal "x", Ruflet.safe_area { text("x") }.to_patch["content"]["value"]
    assert_equal "x", Ruflet.bottom_sheet { text("x") }.to_patch["content"]["value"]
    assert_equal "x", Ruflet.draggable(group: "g") { text("x") }.to_patch["content"]["value"]
    assert_equal "x", Ruflet.drag_target(group: "g") { text("x") }.to_patch["content"]["value"]
  end

  def test_alert_dialog_block_fills_content_and_keeps_explicit_actions
    dialog = Ruflet.alert_dialog(title: Ruflet.text("T"), actions: [Ruflet.text_button("OK")]) { text("Body") }
    patch = dialog.to_patch

    assert_equal "Body", patch["content"]["value"]
    assert_equal ["TextButton"], patch["actions"].map { |a| a["_c"] }
    assert_equal "T", patch["title"]["value"]
  end

  def test_list_slots_take_every_control_the_block_builds
    bar = Ruflet.app_bar(title: Ruflet.text("T")) { icon_button(icon: "add"); icon_button(icon: "edit") }
    assert_equal %w[IconButton IconButton], bar.to_patch["actions"].map { |a| a["_c"] }

    dropdown = Ruflet.dropdown(label: "Color") { dropdown_option("red"); dropdown_option("blue") }
    assert_equal %w[red blue], dropdown.to_patch["options"].map { |o| o["key"] }

    menu = Ruflet.popup_menu_button { popup_menu_item(content: "Copy"); popup_menu_item(content: "Paste") }
    assert_equal %w[PopupMenuItem PopupMenuItem], menu.to_patch["items"].map { |i| i["_c"] }

    table = Ruflet.data_table([Ruflet.data_column(label: Ruflet.text("Name"))]) { data_row(cells: [data_cell(text("Ada"))]) }
    assert_equal ["DataRow"], table.to_patch["rows"].map { |r| r["_c"] }
    assert_equal ["DataColumn"], table.to_patch["columns"].map { |c| c["_c"] }
  end

  def test_navigation_and_tab_bars_fill_the_list_their_renderer_reads
    bar = Ruflet.navigation_bar do
      navigation_bar_destination(icon: "home", label: "Home")
      navigation_bar_destination(icon: "search", label: "Search")
    end
    assert_equal %w[Home Search], bar.to_patch["destinations"].map { |d| d["label"] }
    refute bar.to_patch.key?("controls")

    rail = Ruflet.navigation_rail { navigation_rail_destination(icon: "home", label: "Home") }
    assert_equal ["NavigationRailDestination"], rail.to_patch["destinations"].map { |d| d["_c"] }

    tab_bar = Ruflet.tab_bar { tab(label: "Inbox"); tab(label: "Sent") }
    assert_equal %w[Inbox Sent], tab_bar.to_patch["tabs"].map { |t| t["label"] }
    refute tab_bar.to_patch.key?("controls")
  end

  def test_container_gesture_detector_pagelet_and_tabs_fill_content
    %i[container gesture_detector pagelet tabs].each do |name|
      patch = Ruflet.public_send(name) { text("x") }.to_patch
      assert_equal "x", patch["content"]["value"], "#{name} { text }"
      refute patch.key?("controls"), "#{name} sends no controls"
    end
  end

  # The example in nestedscrollview_control.rb.
  def test_tabs_around_a_nested_scroll_view_sends_it_as_content
    layout = Ruflet.tabs(length: 2) do
      nested_scroll_view(body: tab_bar_view([list_view([text("a")]), list_view([text("b")])])) do
        sliver_app_bar(title: text("Mail"), pinned: true, bottom: tab_bar(tabs: [tab(label: "Inbox"), tab(label: "Sent")]))
      end
    end
    patch = layout.to_patch

    assert_equal %w[_c _i length content], patch.keys
    assert_equal "NestedScrollView", patch["content"]["_c"]
    assert_equal ["SliverAppBar"], patch["content"]["controls"].map { |s| s["_c"] }
  end

  def test_canvas_block_fills_shapes
    canvas = Ruflet.canvas(width: 10) { circle(x: 1, y: 2, radius: 3); line(x1: 0, y1: 0, x2: 1, y2: 1) }
    assert_equal %w[Circle Line], canvas.to_patch["shapes"].map { |s| s["_c"] }
  end

  def test_cupertino_segmented_buttons_take_their_children_from_the_block
    button = Ruflet.cupertino_segmented_button { text("a"); text("b") }
    assert_equal %w[a b], button.to_patch["controls"].map { |c| c["value"] }

    sliding = Ruflet.cupertino_sliding_segmented_button { text("a"); text("b") }
    assert_equal %w[a b], sliding.to_patch["controls"].map { |c| c["value"] }

    assert_raises(ArgumentError) { Ruflet.cupertino_segmented_button { text("only one") } }

    ran = false
    passed = nil
    capture_io { passed = Ruflet.cupertino_segmented_button([Ruflet.text("c"), Ruflet.text("d")]) { ran = true; text("a") } }
    refute ran
    assert_equal %w[c d], passed.to_patch["controls"].map { |c| c["value"] }
  end

  def test_a_control_returned_by_the_block_is_its_child
    built = Ruflet.text("outside")
    card = Ruflet.card { built }
    assert_same built, card.props["content"]
  end

  # Ruflet.text inside the block lands in the block's builder, so a block
  # whose last value is not a control keeps what it built.
  def test_ruflet_calls_in_a_slot_block_fill_the_slot
    assert_equal "a", Ruflet.card { Ruflet.text("a"); nil }.to_patch["content"]["value"]
    bar = Ruflet.app_bar { Ruflet.icon_button(icon: "add"); Ruflet.icon_button(icon: "edit"); nil }
    assert_equal %w[IconButton IconButton], bar.to_patch["actions"].map { |a| a["_c"] }
    assert_equal "a", Ruflet::DSL.app.card { Ruflet.text("a"); nil }.to_patch["content"]["value"]
  end

  def test_services_built_in_a_slot_block_go_where_the_builders_services_go
    services = []
    builder = Ruflet::WidgetBuilder.new(services: services)
    builder.card { audio(src: "a.mp3"); text("x") }

    assert_equal ["Audio"], services.map(&:wire_type)
  end

  def test_a_page_sends_block_children_in_the_slot
    sent = []
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(a, p) { sent << [a, p] })
    page.add(Ruflet.column([Ruflet.card { text("in card") }, Ruflet.list_view { text("in list") }]))
    controls = sent.last[1]["patch"].find { |op| op[2] == "views" }[3].first["controls"].first["controls"]

    assert_equal "in card", controls[0]["content"]["value"]
    assert_equal ["in list"], controls[1]["controls"].map { |c| c["value"] }
  end

  def test_dsl_app_blocks_fill_slots
    app = Ruflet::DSL.app
    card = app.card { text("x") }
    dialog = app.alert_dialog { column { text("a"); text("b") } }

    assert_equal "x", card.to_patch["content"]["value"]
    assert_equal %w[a b], dialog.to_patch["content"]["controls"].map { |c| c["value"] }
  end

  def test_services_built_in_a_dsl_app_slot_block_go_to_the_apps_services
    app = Ruflet::DSL.app
    card = app.card { audio(src: "a.mp3"); text("x") }

    assert_equal ["Audio"], app.instance_variable_get(:@services).map(&:wire_type)
    assert_equal "x", card.to_patch["content"]["value"]
  end

  # In a DSL app a slot block runs on the app, as a column's block does, so
  # both see the app's methods and instance variables.
  def test_dsl_app_slot_blocks_run_on_the_app_like_column_blocks
    app = Ruflet::DSL.app do
      @count = 3
      def header = text("Header")
      page(title: "x") do
        column { text("column #{@count}"); header }
        card { text("card #{@count}") }
        card { header }
        list_view { text("list #{@count}"); header }
        column { card { text("nested"); nil } } # the block's value is not its control
      end
    end
    roots = app.instance_variable_get(:@roots).map(&:to_patch)

    assert_equal ["column 3", "Header"], roots[0]["controls"].map { |c| c["value"] }
    assert_equal "card 3", roots[1]["content"]["value"]
    assert_equal "Header", roots[2]["content"]["value"]
    assert_equal ["list 3", "Header"], roots[3]["controls"].map { |c| c["value"] }
    assert_equal ["Card"], roots[4]["controls"].map { |c| c["_c"] }
    assert_equal "nested", roots[4]["controls"][0]["content"]["value"]
    assert_equal 5, roots.size
  end

  def test_a_control_returned_by_a_dsl_app_slot_block_is_its_child
    built = Ruflet.text("outside")
    assert_same built, Ruflet::DSL.app.card { built }.props["content"]
  end

  # -- What an explicit slot, or a pressed control, keeps ---------------------

  def test_an_explicit_slot_wins_over_the_block_and_says_so
    ran = false
    card = nil
    _out, err = capture_io { card = Ruflet.card(Ruflet.text("given")) { ran = true; text("block") } }

    refute ran
    assert_equal "given", card.to_patch["content"]["value"]
    assert_match(/card ignores its block because content: was given/, err)
  end

  # container and the others ran their block before #135; given the slot
  # too, they still do, and send what they sent then.
  def test_a_block_beside_an_explicit_slot_keeps_its_earlier_output
    container = Ruflet.container(content: Ruflet.text("given")) { text("block") }
    patch = container.to_patch

    assert_equal "given", patch["content"]["value"]
    assert_equal ["block"], patch["controls"].map { |c| c["value"] }
  end

  def test_one_content_slot_keeps_the_first_of_several_and_warns_once
    card = nil
    _out, err = capture_io do
      card = Ruflet.card { text("a"); text("b") }
      Ruflet.card { text("c"); text("d") }
    end

    assert_equal "a", card.to_patch["content"]["value"]
    assert_equal 1, err.scan("card takes one content control").size
  end

  def test_a_handler_written_as_a_button_block_is_not_run
    clicks = 0
    handler = ->(_e) { clicks += 1 }
    button = nil
    _out, err = capture_io do
      button = Ruflet.elevated_button("Save", on_click: handler) { clicks += 100 }
      Ruflet.elevated_button("Again") { clicks += 100 }
    end

    assert_equal 0, clicks
    assert_equal Ruflet.elevated_button("Save", on_click: handler).to_patch, button.to_patch
    assert_equal 1, err.scan("elevated_button does not run its block").size
  end

  # A block written as an event handler builds a generic control for each
  # method it calls; a type nothing registered is reported once.
  def test_a_slot_block_that_builds_an_unregistered_control_warns_once
    view = Class.new do
      def build = Ruflet.dropdown(label: "Color", on_change: ->(_e) {}) { |e| apply_color(e) }
      def apply_color(_e) = nil
    end
    _out, err = capture_io do
      2.times { view.new.build }
      Ruflet.list_view { refresh_items(1) }
      Ruflet.cupertino_segmented_button { text("a"); reload_items(1) }
      Ruflet.card { text("x") }
      Ruflet.dropdown { dropdown_option("red") }
    end

    assert_equal 1, err.scan("dropdown's block built `apply_color`, which is not a registered control").size
    assert_equal 1, err.scan("list_view's block built `refresh_items`").size
    assert_equal 1, err.scan("cupertino_segmented_button's block built `reload_items`").size
    refute_match(/card's block|`text`|`dropdown_option`|`dropdownoption`/, err)
  end

  def test_floating_action_button_takes_its_content_positionally
    positional = Ruflet.floating_action_button("Add", icon: "add")
    keyword = Ruflet.floating_action_button(content: "Add", icon: "add")

    assert_equal keyword.to_patch, positional.to_patch
    assert_equal "Add", positional.to_patch["content"]
    assert_equal keyword.to_patch, Ruflet.floatingactionbutton("Add", icon: "add").to_patch
    assert_equal keyword.to_patch, Ruflet::DSL.floating_action_button("Add", icon: "add").to_patch
    assert_equal Ruflet.floating_action_button(icon: "add").to_patch, Ruflet::WidgetBuilder.new.floating_action_button(icon: "add").to_patch
  end

  # -- Children lists ---------------------------------------------------------

  def test_a_children_list_reports_what_it_drops_once_naming_its_class
    column = nil
    _out, err = capture_io do
      column = Ruflet.column(["a", Ruflet.text("b"), nil, false, :c, { d: 1 }, 2])
      Ruflet.column(["again"])
    end

    assert_equal ["b"], column.to_patch["controls"].map { |c| c["value"] }
    %w[String Symbol Hash Integer].each do |kind|
      assert_equal 1, err.scan("Column dropped a #{kind} child").size, kind
    end
    refute_match(/NilClass|FalseClass/, err)
  end

  def test_the_dsl_app_reports_dropped_children_too
    _out, err = capture_io { Ruflet::DSL.app.row(["a"]) }
    assert_match(/Row dropped a String child/, err)
  end

  def test_nil_and_false_children_are_skipped_silently
    _out, err = capture_io { Ruflet.column([Ruflet.text("a"), nil, false]) }
    assert_empty err
  end

  private

  def slot_builders
    @slot_builders ||= begin
      names = (Ruflet::WidgetBuilder.public_instance_methods - Object.public_instance_methods).map(&:to_s).sort
      names.filter_map do |name|
        type = built_type(name)
        next unless type

        klass = Ruflet::UI::ControlFactory::CLASS_MAP[type.downcase]
        next unless klass

        slots = SLOT_KEYS & Ruflet::UI::ControlFactory.constructor_keywords(klass).map(&:to_s)
        next if slots.empty?

        [name, klass, slots]
      end
    end
  end

  # The control type a builder builds, without building it.
  def built_type(name)
    type = nil
    probe = Ruflet::WidgetBuilder.new
    probe.define_singleton_method(:build_widget) { |t, **| type = t.to_s; raise Probe }
    probe.define_singleton_method(:build_service) { |_t, **| raise Probe }
    args, props = required_for(name)
    probe.public_send(name, *args, **props)
    nil
  rescue Probe
    type
  rescue ArgumentError
    nil
  end

  # A control that is pressed: a content slot and an on_click event.
  def pressed?(klass)
    keywords = Ruflet::UI::ControlFactory.constructor_keywords(klass)
    keywords.include?(:content) && keywords.include?(:on_click) && !klass.name.end_with?("ContainerControl")
  end

  # The block the contract tests pass: one control, or two for a builder that
  # needs two children. +on_run+ is called when the block runs.
  def contract_block(name, &on_run)
    second = TWO_CHILDREN.any? { |key| key == name || key.delete("_") == name }
    proc do
      on_run&.call
      text("from block")
      text("other") if second
    end
  end

  # The wire key a builder's block fills, found by building it.
  def filled_key(name)
    args, props = required_for(name)
    patch = Ruflet::WidgetBuilder.new.public_send(name, *args, **props, &contract_block(name)).to_patch
    patch.keys.find { |key| holds_block_text?(patch[key]) }
  end

  # A fresh control (or list of them) to pass in +key+ explicitly.
  def given_value(name, key)
    return Ruflet.text("given") if key == "content"
    return [Ruflet.text("given"), Ruflet.text("given 2")] if TWO_CHILDREN.any? { |k| k == name || k.delete("_") == name }

    [Ruflet.text("given")]
  end

  def required_for(name)
    canonical = REQUIRED.keys.find { |key| key == name || key.delete("_") == name }
    args, props = REQUIRED.fetch(canonical, [[], {}])
    [args.map { |arg| arg.respond_to?(:call) ? arg.call : arg }, props.transform_values { |v| v.respond_to?(:call) ? v.call : v }]
  end

  def compact_alias?(name)
    !name.include?("_") && slot_builders.any? { |other, _, _| other != name && other.delete("_") == name }
  end

  def holds_block_text?(value)
    case value
    when Hash then value["value"] == "from block" || value.values.any? { |v| holds_block_text?(v) }
    when Array then value.any? { |v| holds_block_text?(v) }
    else false
    end
  end
end

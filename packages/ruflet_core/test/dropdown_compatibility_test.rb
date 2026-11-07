# frozen_string_literal: true

require_relative "test_helper"

class RufletDropdownCompatibilityTest < Minitest::Test
  def test_dropdown_accepts_positional_options_and_serializes_current_flet_props
    dropdown = Ruflet.dropdown(
      [
        Ruflet.dropdown_option("red", text: "Red", leading_icon: "palette"),
        Ruflet.dropdown_option(text: "Blue", trailing_icon: Ruflet.icon("check"))
      ],
      autofocus: true,
      bgcolor: { focused: "#ABCDEF" },
      border: "outline",
      border_color: "#111111",
      border_radius: 8,
      border_width: 1,
      color: "#222222",
      content_padding: { left: 12 },
      editable: true,
      elevation: 4,
      enable_filter: true,
      enable_search: true,
      error_style: { color: "#333333" },
      error_text: "Required",
      expanded_insets: { left: 4 },
      fill_color: "#444444",
      filled: true,
      focused_border_color: "#555555",
      focused_border_width: 2,
      helper_style: { size: 12 },
      helper_text: "Pick one",
      hint_style: { italic: true },
      hint_text: "Color",
      input_filter: { allow: "[a-z]" },
      label: "Favorite",
      label_style: { weight: "bold" },
      leading_icon: "search",
      menu_height: 240,
      menu_style: { bgcolor: "#666666" },
      menu_width: 300,
      selected_suffix: Ruflet.text("selected"),
      selected_trailing_icon: "done",
      text: "Re",
      text_align: "start",
      text_size: 14,
      text_style: { color: "#777777" },
      trailing_icon: "arrow_drop_down",
      value: "red",
      on_blur: ->(_event) {},
      on_focus: ->(_event) {},
      on_select: ->(_event) {},
      on_text_change: ->(_event) {}
    )

    patch = dropdown.to_patch

    assert_equal "Dropdown", patch["_c"]
    assert_equal true, patch["autofocus"]
    assert_equal({ "focused" => "#ABCDEF" }, patch["bgcolor"])
    assert_equal "outline", patch["border"]
    assert_equal "#111111", patch["border_color"]
    assert_equal 8, patch["border_radius"]
    assert_equal 1, patch["border_width"]
    assert_equal "#222222", patch["color"]
    assert_equal({ "left" => 12 }, patch["content_padding"])
    assert_equal true, patch["editable"]
    assert_equal 4, patch["elevation"]
    assert_equal true, patch["enable_filter"]
    assert_equal true, patch["enable_search"]
    assert_equal({ "color" => "#333333" }, patch["error_style"])
    assert_equal "Required", patch["error_text"]
    assert_equal({ "left" => 4 }, patch["expanded_insets"])
    assert_equal "#444444", patch["fill_color"]
    assert_equal true, patch["filled"]
    assert_equal "#555555", patch["focused_border_color"]
    assert_equal 2, patch["focused_border_width"]
    assert_equal({ "size" => 12 }, patch["helper_style"])
    assert_equal "Pick one", patch["helper_text"]
    assert_equal({ "italic" => true }, patch["hint_style"])
    assert_equal "Color", patch["hint_text"]
    assert_equal({ "allow" => "[a-z]" }, patch["input_filter"])
    assert_equal "Favorite", patch["label"]
    assert_equal({ "weight" => "bold" }, patch["label_style"])
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("search"), patch["leading_icon"]
    assert_equal 240, patch["menu_height"]
    assert_equal({ "bgcolor" => "#666666" }, patch["menu_style"])
    assert_equal 300, patch["menu_width"]
    assert_equal "Text", patch["selected_suffix"]["_c"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("done"), patch["selected_trailing_icon"]
    assert_equal "Re", patch["text"]
    assert_equal "start", patch["text_align"]
    assert_equal 14, patch["text_size"]
    assert_equal({ "color" => "#777777" }, patch["text_style"])
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("arrow_drop_down"), patch["trailing_icon"]
    assert_equal "red", patch["value"]
    assert_equal true, patch["on_blur"]
    assert_equal true, patch["on_focus"]
    assert_equal true, patch["on_select"]
    assert_equal true, patch["on_text_change"]

    first, second = patch["options"]
    assert_equal "DropdownOption", first["_c"]
    assert_equal "red", first["key"]
    assert_equal "Red", first["text"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("palette"), first["leading_icon"]
    assert_equal "Blue", second["key"]
    assert_equal "Blue", second["text"]
    assert_equal "Icon", second["trailing_icon"]["_c"]
  end

  def test_dropdown_option_accepts_positional_key_and_applies_flet_fallbacks
    keyed = Ruflet.dropdown_option("red")
    texted = Ruflet.dropdown_option(text: "Blue")

    assert_equal "red", keyed.props["key"]
    assert_equal "red", keyed.props["text"]
    assert_equal "Blue", texted.props["key"]
    assert_equal "Blue", texted.props["text"]
  end

  def test_dropdown_option_serializes_without_key_or_text_like_flet
    patch = Ruflet.dropdown_option.to_patch

    assert_equal "DropdownOption", patch["_c"]
    refute patch.key?("key")
    refute patch.key?("text")
  end

  def test_dropdown_serializes_negative_numeric_values_like_flet
    patch = Ruflet.dropdown([], border_width: -1, elevation: -2, focused_border_width: -3, menu_height: -4, menu_width: -5, text_size: -6).to_patch

    assert_equal(-1, patch["border_width"])
    assert_equal(-2, patch["elevation"])
    assert_equal(-3, patch["focused_border_width"])
    assert_equal(-4, patch["menu_height"])
    assert_equal(-5, patch["menu_width"])
    assert_equal(-6, patch["text_size"])
  end

  def test_dropdown_select_event_updates_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    dropdown = Ruflet.dropdown(
      [Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")],
      value: "red",
      on_select: ->(event) { observed << [event.value, event.control.props["value"]] }
    )
    page.add(dropdown)

    page.dispatch_event(target: dropdown.wire_id, name: "select", data: { "value" => "blue" })

    assert_equal "blue", dropdown.props["value"]
    assert_equal [["blue", "blue"]], observed
  end

  def test_dropdown_m2_on_change_fires_on_the_canonical_select_event
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    dropdown = Ruflet.dropdownm2(
      [Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")],
      value: "red",
      on_change: ->(event) { observed << [event.name, event.value] }
    )
    page.add(dropdown)
    patch = dropdown.to_patch

    assert_equal "Dropdown", patch["_c"]
    assert_equal true, patch["on_select"]
    refute patch.key?("on_change")
    assert dropdown.has_handler?(:on_change)

    page.dispatch_event(target: dropdown.wire_id, name: "select", data: { "value" => "blue" })

    assert_equal "blue", dropdown.props["value"]
    # The handler was registered as on_change, so it sees "change" even though
    # the Dropdown renderer fires "select".
    assert_equal [["change", "blue"]], observed
  end

  def test_dropdown_m2_change_handler_attached_later_fires_on_select
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    dropdown = Ruflet.dropdown_m2([Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")], value: "red")
    dropdown.on(:change) { |event| observed << [event.name, event.value] }
    page.add(dropdown)

    assert_equal true, dropdown.to_patch["on_select"]
    page.dispatch_event(target: dropdown.wire_id, name: "select", data: { "value" => "blue" })

    assert_equal [["change", "blue"]], observed
  end

  def test_material2_change_handlers_see_change_while_on_select_handlers_see_select
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    record = ->(label) { ->(event) { observed << [label, event.name] } }
    options = -> { [Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")] }
    controls = {
      "dropdown_m2(on_change:)" => Ruflet.dropdown_m2(options.call, on_change: record.call("dropdown_m2(on_change:)")),
      "dropdownm2(on_change:)" => Ruflet.dropdownm2(options.call, on_change: record.call("dropdownm2(on_change:)")),
      "dropdown(on_change:)" => Ruflet.dropdown(options.call, on_change: record.call("dropdown(on_change:)")),
      "dropdown(on_select:)" => Ruflet.dropdown(options.call, on_select: record.call("dropdown(on_select:)")),
      "dropdown_m2(on_select:)" => Ruflet.dropdown_m2(options.call, on_select: record.call("dropdown_m2(on_select:)")),
      "on(:change)" => Ruflet.dropdown(options.call).on(:change, &record.call("on(:change)")),
      "on(:on_change)" => Ruflet.dropdown(options.call).on(:on_change, &record.call("on(:on_change)")),
      "on(\"change\")" => Ruflet.dropdown(options.call).on("change", &record.call("on(\"change\")")),
      "on(:select)" => Ruflet.dropdown(options.call).on(:select, &record.call("on(:select)")),
      "attach_handler(:on_change)" => Ruflet.dropdown(options.call).attach_handler(:on_change, record.call("attach_handler(:on_change)")),
      "attach_handler(\"change\")" => Ruflet.dropdown(options.call).attach_handler("change", record.call("attach_handler(\"change\")")),
      "attach_handler(:select)" => Ruflet.dropdown(options.call).attach_handler(:select, record.call("attach_handler(:select)"))
    }
    controls.each_value { |control| page.add(control) }

    controls.each_value do |control|
      assert_equal true, control.to_patch["on_select"]
      refute control.to_patch.key?("on_change")
      page.dispatch_event(target: control.wire_id, name: "select", data: "blue")
    end

    expected = controls.keys.map do |label|
      [label, label.include?("change") ? "change" : "select"]
    end
    assert_equal expected, observed
  end

  def test_material2_change_handler_gets_the_same_event_data_as_an_on_select_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    received = {}
    legacy = Ruflet.dropdown_m2(
      [Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")],
      value: "red",
      on_change: ->(event) { received[:legacy] = event }
    )
    canonical = Ruflet.dropdown(
      [Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")],
      value: "red",
      on_select: ->(event) { received[:canonical] = event }
    )
    page.add(legacy)
    page.add(canonical)

    payload = { "value" => "blue", "selection" => { "value" => "blue" } }
    page.dispatch_event(target: legacy.wire_id, name: "select", data: payload)
    page.dispatch_event(target: canonical.wire_id, name: "select", data: payload)

    old_style = received.fetch(:legacy)
    new_style = received.fetch(:canonical)
    assert_equal "change", old_style.name
    assert_equal "select", new_style.name
    assert_kind_of Ruflet::Event, old_style
    assert_same legacy, old_style.control
    assert_same page, old_style.page
    assert_equal legacy.wire_id, old_style.target
    assert_equal new_style.raw_data, old_style.raw_data
    assert_equal new_style.data, old_style.data
    assert_equal new_style.value, old_style.value
    assert_equal new_style.typed_data.class, old_style.typed_data.class
    assert_equal({ "value" => "blue" }, old_style.selection)
    assert_equal "blue", legacy.props["value"]
    assert_equal "blue", canonical.props["value"]
  end

  def test_material2_change_handler_still_sees_change_when_the_client_sends_change
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    dropdown = Ruflet.dropdown_m2(
      [Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")],
      on_change: ->(event) { observed << [event.name, event.value] }
    )
    page.add(dropdown)

    page.dispatch_event(target: dropdown.wire_id, name: "change", data: { "value" => "blue" })

    assert_equal [["change", "blue"]], observed
  end

  def test_replacing_a_material2_change_handler_with_on_select_delivers_select
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    dropdown = Ruflet.dropdown_m2(
      [Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")],
      on_change: ->(event) { observed << [:legacy, event.name] }
    )
    dropdown.on(:select) { |event| observed << [:canonical, event.name] }
    page.add(dropdown)

    page.dispatch_event(target: dropdown.wire_id, name: "select", data: "blue")

    assert_equal [[:canonical, "select"]], observed
  end

  def test_dropdown_m2_renames_material2_keys_onto_the_dropdown_contract
    patch = Ruflet.dropdownm2(
      [Ruflet.dropdown_option("red")],
      max_menu_height: 240,
      prefix_icon: "palette",
      select_icon: "arrow_drop_down"
    ).to_patch
    canonical = Ruflet.dropdown(
      [Ruflet.dropdown_option("red")],
      menu_height: 240,
      leading_icon: "palette",
      trailing_icon: "arrow_drop_down"
    ).to_patch

    assert_equal 240, patch["menu_height"]
    assert_equal canonical["leading_icon"], patch["leading_icon"]
    assert_equal canonical["trailing_icon"], patch["trailing_icon"]
    %w[max_menu_height prefix_icon select_icon].each { |key| refute patch.key?(key), key }
  end

  def test_dropdown_m2_warns_and_keeps_the_dropdown_key_when_both_spellings_are_given
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    calls = []
    dropdown = nil

    _out, err = capture_warnings do
      dropdown = Ruflet.dropdownm2(
        [Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")],
        value: "red",
        on_change: ->(_event) { calls << :on_change },
        on_select: ->(_event) { calls << :on_select }
      )
    end

    assert_equal 1, err.lines.size, err
    assert_includes err, ":on_select"
    assert_includes err, ":on_change"
    patch = dropdown.to_patch
    assert_equal true, patch["on_select"]
    refute patch.key?("on_change")

    page.add(dropdown)
    page.dispatch_event(target: dropdown.wire_id, name: "select", data: "blue")
    page.dispatch_event(target: dropdown.wire_id, name: "change", data: "blue")

    assert_equal %i[on_select on_select], calls
  end

  def test_every_material2_key_given_with_its_dropdown_spelling_warns_and_the_dropdown_key_wins
    builders = {
      "dropdown" => ->(**props) { Ruflet.dropdown([], **props) },
      "dropdown_m2" => ->(**props) { Ruflet.dropdown_m2([], **props) },
      "dropdownm2" => ->(**props) { Ruflet.dropdownm2([], **props) }
    }
    canonical = Ruflet.dropdown([], menu_height: 2, leading_icon: "palette", trailing_icon: "arrow_drop_down").to_patch

    builders.each do |name, build|
      control = nil
      _out, err = capture_warnings do
        control = build.call(
          max_menu_height: 1, menu_height: 2,
          prefix_icon: "search", leading_icon: "palette",
          select_icon: "check", trailing_icon: "arrow_drop_down"
        )
      end
      patch = control.to_patch

      assert_equal 3, err.lines.size, "#{name}: #{err}"
      [%w[menu_height max_menu_height], %w[leading_icon prefix_icon], %w[trailing_icon select_icon]].each do |key, legacy|
        assert_equal canonical[key], patch[key], "#{name} #{key}"
        refute patch.key?(legacy), "#{name} #{legacy}"
        assert_match(/:#{key}\b.*:#{legacy}\b/, err, "#{name} warning names :#{key} and :#{legacy}")
      end
    end
  end

  def test_a_lone_material2_key_or_dropdown_key_does_not_warn
    _out, err = capture_warnings do
      Ruflet.dropdownm2([], on_change: ->(_event) {}, max_menu_height: 1, prefix_icon: "search", select_icon: "check")
      Ruflet.dropdown([], on_select: ->(_event) {}, menu_height: 1, leading_icon: "search", trailing_icon: "check")
    end

    assert_empty err
  end

  def test_dropdown_m2_documents_every_material2_keyword_without_a_dropdown_equivalent
    contract = Ruflet::UI::PlatformControlContracts::Components::DropdownControl
    components = Ruflet::UI::Controls::RufletComponents
    material2_only = components::Dropdown2Control::KEYWORDS - components::DropdownControl::KEYWORDS

    assert_equal material2_only.sort,
                 (contract::MATERIAL2_RENAMES.keys + contract::MATERIAL2_UNSUPPORTED_KEYWORDS +
                  contract::MATERIAL2_SHARED_KEYWORDS).sort
    assert_empty contract::MATERIAL2_RENAMES.values - components::DropdownControl::KEYWORDS

    patch = Ruflet.dropdownm2(
      [],
      hint_content: Ruflet.text("Pick"),
      disabled_hint_content: Ruflet.text("Locked"),
      item_height: 48,
      enable_feedback: false
    ).to_patch

    assert_equal "Text", patch["hint_content"]["_c"]
    assert_equal "Text", patch["disabled_hint_content"]["_c"]
    assert_equal 48, patch["item_height"]
    assert_equal false, patch["enable_feedback"]
  end
  # Flet 1.0's DropdownM2.menu_border_radius rounds the open menu; the field
  # keeps border_radius. dropdown_m2 sends both under their own names.
  def test_dropdown_m2_menu_border_radius_is_sent_under_its_own_name
    patch = Ruflet.dropdown_m2([Ruflet.dropdown_option("red")], menu_border_radius: 12, border_radius: 4).to_patch

    assert_equal "Dropdown", patch["_c"]
    assert_equal 12, patch["menu_border_radius"]
    assert_equal 4, patch["border_radius"]
    assert_equal({ "top_left" => 8 }, Ruflet.dropdown([], menu_border_radius: { top_left: 8 }).to_patch["menu_border_radius"])
    refute Ruflet.dropdown_m2([]).to_patch.key?("menu_border_radius")
  end

  private

  # Kernel.warn output, kept even when the suite runs with warnings disabled.
  def capture_warnings(&block)
    verbose = $VERBOSE
    $VERBOSE = false
    capture_io(&block)
  ensure
    $VERBOSE = verbose
  end
end

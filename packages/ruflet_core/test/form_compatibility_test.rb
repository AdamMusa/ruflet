# frozen_string_literal: true

require_relative "test_helper"

# Form validation (Flutter's Form/FormField) with Ruby validators: the form
# lays out its fields like a Column on the client, and validates, resets and
# saves them in Ruby, where the validators stay.
class RufletFormCompatibilityTest < Minitest::Test
  REQUIRED = ->(value) { "Required" if value.to_s.empty? }

  def setup
    Ruflet::DSL._reset_pending_app!
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "form",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  # Every control patch sent since the last clear: { wire_id => { prop => value } }.
  def control_patches
    @sent.each_with_object({}) do |(action, payload), patches|
      next unless action == Ruflet::Protocol::ACTIONS[:patch_control]
      next if payload["id"] == 1

      ops = (patches[payload["id"]] ||= {})
      payload["patch"].drop(1).each { |(_op, _index, key, value)| ops[key] = value }
    end
  end

  def strings_in(value)
    case value
    when String then [value]
    when Hash then value.flat_map { |k, v| strings_in(k.to_s) + strings_in(v) }
    when Array then value.flat_map { |v| strings_in(v) }
    when Proc, Method then [value.inspect]
    else []
    end
  end

  def signup_form(**form_props)
    email = Ruflet.text_field(label: "Email", key: "email", validator: REQUIRED)
    country = Ruflet.dropdown(
      [Ruflet.dropdown_option("fr"), Ruflet.dropdown_option("sn")],
      key: "country", validator: ->(v) { "Pick a country" if v.nil? }
    )
    terms = Ruflet.checkbox(label: "I agree", key: "terms", validator: ->(v) { "Please accept" unless v })
    news = Ruflet.switch(label: "News", key: "news", validator: ->(v) { "Must be on" unless v })
    plan = Ruflet.radio_group(
      content: Ruflet.row([Ruflet.radio(value: "free", label: "Free"), Ruflet.radio(value: "pro", label: "Pro")]),
      key: "plan", validator: ->(v) { "Choose a plan" if v.nil? }
    )
    form = Ruflet.form([email, country, terms, news, plan], **form_props)
    [form, email, country, terms, news, plan]
  end

  # --- the control ------------------------------------------------------------

  def test_form_serializes_as_a_column_like_layout_of_its_controls
    patch = Ruflet.form(
      [Ruflet.text_field(label: "Name")],
      spacing: 12, alignment: "center", horizontal_alignment: "stretch", scroll: "auto", width: 320, expand: true
    ).to_patch

    assert_equal "Form", patch["_c"]
    assert_equal({ "host_expanded" => true }, patch["_internals"], "an expanded field gets its share, as in a Column")
    assert_equal 12, patch["spacing"]
    assert_equal "center", patch["alignment"]
    assert_equal "stretch", patch["horizontal_alignment"]
    assert_equal "auto", patch["scroll"]
    assert_equal 320, patch["width"]
    assert_equal ["TextField"], patch["controls"].map { |c| c["_c"] }
    assert_raises(ArgumentError) { Ruflet.form(wrap: true) }
  end

  def test_names_and_every_dsl_entry_point_build_a_form_with_block_fields
    assert Ruflet::UI::ControlFactory.known_control?("form")
    assert_equal "Form", Ruflet::UI::ControlFactory.build("form").wire_type

    built = [
      Ruflet.form { text_field(label: "A", validator: REQUIRED) },
      Ruflet::DSL.app.form { text_field(label: "A", validator: REQUIRED) },
      form { text_field(label: "A", validator: REQUIRED) }
    ]
    built.each do |form|
      assert_equal "Form", form.wire_type
      assert_equal ["TextField"], form.fields.map(&:wire_type)
      refute form.validate
      assert_equal "Required", form.fields.first.props["error"]
    end

    app = Ruflet::DSL.app do
      form(spacing: 8, autovalidate_mode: "always") do
        text_field(label: "Name", key: "name", validator: REQUIRED)
      end
    end
    page_form = app.instance_variable_get(:@roots).first
    @page.add(page_form)
    assert_equal "always", page_form.autovalidate_mode
    assert_equal "Required", page_form.fields.first.props["error"], "an always form validates when mounted"
  end

  def test_validators_and_form_options_stay_in_ruby
    form, email, = signup_form(autovalidate_mode: "on_unfocus", on_submit: ->(_e) {})
    email.on_saved = ->(_v) {}

    @page.add(form)
    form.validate
    @page.update(email, validator: ->(v) { "Too short" if v.size < 3 }, label: "E-mail")
    @page.update(email, autovalidate_mode: "on_user_interaction")
    @page.update

    sent = strings_in(@sent.map(&:last))
    assert_empty sent.grep(/Proc|Method|lambda/), "a validator must never be serialized"
    %w[validator on_saved autovalidate_mode].each do |name|
      refute_includes sent, name
      refute form.to_patch.to_s.include?(name)
    end
    assert_equal "E-mail", email.props["label"]

    form.validate
    assert_equal "Too short", email.props["error"], "page.update(field, validator:) replaces the validator"
  end

  def test_options_are_rejected_where_they_make_no_sense
    assert_raises(ArgumentError) { Ruflet.text(value: "x", validator: REQUIRED) }
    assert_raises(ArgumentError) { Ruflet.form(validator: REQUIRED) }
    assert_raises(ArgumentError) { Ruflet.button("Go", on_saved: ->(_v) {}) }
    assert_raises(ArgumentError) { Ruflet.text_field(validator: "not callable") }
    assert_raises(ArgumentError) { Ruflet.text_field(autovalidate_mode: "sometimes") }
    assert_raises(ArgumentError) { Ruflet.form(autovalidate_mode: :onUserInteraction) }
    assert_equal "on_unfocus", Ruflet.text_field(autovalidate_mode: :on_unfocus).autovalidate_mode
    assert_equal "disabled", Ruflet.form.autovalidate_mode
    assert_equal "Required",
                 Ruflet::Control.new(type: "textfield", validator: REQUIRED).validator.call(""),
                 "a generic control of a field type takes a validator too"
  end

  # --- validate -----------------------------------------------------------------

  def test_validate_sets_each_fields_error_prop_and_returns_false
    form, email, country, terms, news, plan = signup_form
    @page.add(form)
    @sent.clear

    refute form.validate

    assert_equal "Required", email.props["error"]
    assert_equal "Pick a country", country.props["error_text"]
    assert_equal true, terms.props["error"], "Checkbox shows an error state, not a message"
    refute news.props.key?("error"), "Switch has no error prop"
    refute plan.props.key?("error"), "RadioGroup has no error prop"
    assert_equal({ "email" => "Required", "country" => "Pick a country", "terms" => "Please accept",
                   "news" => "Must be on", "plan" => "Choose a plan" }, form.errors)
    assert_equal "Must be on", news.validation_error

    patches = control_patches
    assert_equal({ "error" => "Required" }, patches[email.wire_id])
    assert_equal({ "error_text" => "Pick a country" }, patches[country.wire_id])
    assert_equal({ "error" => true }, patches[terms.wire_id])
    assert_equal [email, country, terms].map(&:wire_id).sort, patches.keys.sort
  end

  def test_validate_clears_errors_once_the_values_are_valid
    form, email, country, terms, news, plan = signup_form
    @page.add(form)
    form.validate
    @sent.clear

    @page.dispatch_event(target: email.wire_id, name: "change", data: "ada@example.com")
    @page.apply_client_update(country.wire_id, { "value" => "sn" })
    @page.dispatch_event(target: country.wire_id, name: "select", data: "sn")
    @page.dispatch_event(target: terms.wire_id, name: "change", data: true)
    @page.dispatch_event(target: news.wire_id, name: "change", data: true)
    @page.dispatch_event(target: plan.wire_id, name: "change", data: "pro")

    assert form.validate
    assert_empty form.errors
    [email, terms].each { |field| refute field.props.key?("error") }
    refute country.props.key?("error_text")
    patches = control_patches
    assert_equal({ "error" => nil }, patches[email.wire_id])
    assert_equal({ "error_text" => nil }, patches[country.wire_id])
    assert_equal({ "error" => nil }, patches[terms.wire_id])
  end

  def test_validate_pushes_exactly_one_page_update
    form, = signup_form
    @page.add(form)
    updates = 0
    @page.define_singleton_method(:update) do |*args, **props|
      updates += 1
      super(*args, **props)
    end

    form.validate

    assert_equal 1, updates
  end

  def test_validate_skips_invisible_and_disabled_fields_and_clears_their_errors
    hidden = Ruflet.text_field(key: "hidden", validator: REQUIRED)
    locked = Ruflet.text_field(key: "locked", validator: REQUIRED)
    in_hidden_row = Ruflet.text_field(key: "in_hidden_row", validator: REQUIRED)
    in_disabled_box = Ruflet.text_field(key: "in_disabled_box", validator: REQUIRED)
    shown = Ruflet.text_field(key: "shown", validator: REQUIRED)
    row = Ruflet.row([in_hidden_row])
    box = Ruflet.container(content: in_disabled_box)
    form = Ruflet.form([hidden, locked, row, box, shown])
    @page.add(form)

    refute form.validate
    assert_equal %w[hidden locked in_hidden_row in_disabled_box shown], form.errors.keys

    hidden.props["visible"] = false
    locked.props["disabled"] = true
    row.props["visible"] = false
    box.props["disabled"] = true
    shown.props["value"] = "ok"

    assert form.validate, "only visible, enabled fields are validated"
    [hidden, locked, in_hidden_row, in_disabled_box, shown].each do |field|
      refute field.props.key?("error"), field.props["key"]
      assert_nil field.validation_error
    end
    refute_includes form.values.keys, "hidden"
    refute_includes form.values.keys, "in_hidden_row"
    assert_includes form.values.keys, "locked", "a disabled field still has a value"
  end

  def test_fields_inside_containers_and_props_belong_to_the_form_but_not_a_nested_forms
    inner_field = Ruflet.text_field(key: "inner", validator: REQUIRED)
    inner = Ruflet.form([inner_field])
    deep = Ruflet.text_field(key: "deep", validator: REQUIRED)
    outer = Ruflet.form([Ruflet.card(content: Ruflet.column([Ruflet.row([deep])])), inner])

    assert_equal [deep], outer.fields
    assert_equal [inner_field], inner.fields
    refute outer.validate
    assert_nil inner_field.validation_error, "the outer form leaves a nested form's fields alone"
    assert_same inner, inner_field.form_owner
    assert_same outer, deep.form_owner
  end

  # --- reset, save, values ---------------------------------------------------

  def test_reset_restores_the_values_at_mount_and_clears_errors
    form, email, country, terms, news, plan = signup_form
    email.props["value"] = "start@example.com"
    @page.add(form)

    @page.dispatch_event(target: email.wire_id, name: "change", data: "")
    @page.apply_client_update(country.wire_id, { "value" => "fr" })
    @page.dispatch_event(target: terms.wire_id, name: "change", data: true)
    @page.dispatch_event(target: news.wire_id, name: "change", data: true)
    @page.dispatch_event(target: plan.wire_id, name: "change", data: "free")
    form.validate
    @sent.clear

    form.reset

    assert_equal({ "email" => "start@example.com", "country" => nil, "terms" => false, "news" => false,
                   "plan" => nil }, form.values)
    assert_empty form.errors
    refute country.props.key?("error_text")
    refute terms.props.key?("error")
    patches = control_patches
    assert_equal "start@example.com", patches[email.wire_id]["value"]
    assert_nil patches[country.wire_id]["value"]
    assert_equal false, patches[terms.wire_id]["value"]
    assert_nil patches[plan.wire_id]["value"]
  end

  def test_save_calls_on_saved_with_each_value_and_returns_the_values
    saved = []
    name = Ruflet.text_field(key: "name", value: "Ada", on_saved: ->(v) { saved << [:name, v] })
    age = Ruflet.slider(key: "age", value: 36, min: 18, max: 99, on_saved: ->(v) { saved << [:age, v] })
    plain = Ruflet.checkbox(key: "plain", value: true)
    gone = Ruflet.switch(key: "gone", visible: false, on_saved: ->(v) { saved << [:gone, v] })
    form = Ruflet.form([name, age, plain, gone])

    assert_equal({ "name" => "Ada", "age" => 36, "plain" => true }, form.save)
    assert_equal [[:name, "Ada"], [:age, 36]], saved
  end

  def test_values_are_keyed_by_key_or_id_and_use_each_controls_value_prop
    form = Ruflet.form do
      text_field(key: "title")
      text_field(id: "anonymous_field")
      slider(key: "volume", min: 10)
      range_slider(key: "span", start_value: 2, end_value: 8)
      checkbox(key: "maybe", tristate: true)
      cupertino_text_field(key: "ios", value: "hi")
    end

    assert_equal({ "title" => "", "anonymous_field" => "", "volume" => 10, "span" => [2, 8], "maybe" => nil,
                   "ios" => "hi" }, form.values)
  end

  def test_cupertino_aliases_and_other_value_fields_validate_the_same_way
    ios_text = Ruflet.cupertino_text_field(key: "ios_text", validator: REQUIRED)
    ios_check = Ruflet.cupertino_checkbox(key: "ios_check", validator: ->(v) { "Tick it" unless v })
    ios_switch = Ruflet.cupertino_switch(key: "ios_switch", value: true, validator: ->(v) { "Off" unless v })
    volume = Ruflet.slider(key: "volume", min: 0, max: 10, value: 2, validator: ->(v) { "Too quiet" if v < 5 })
    day = Ruflet.date_picker(key: "day", inline: true, validator: ->(v) { "Pick a day" if v.nil? })
    size = Ruflet.segmented_button(
      [Ruflet.segment("s", label: Ruflet.text("S")), Ruflet.segment("m", label: Ruflet.text("M"))],
      key: "size", selected: [], validator: ->(v) { "Pick a size" if v.empty? }
    )
    form = Ruflet.form([ios_text, ios_check, ios_switch, volume, day, size])
    @page.add(form)

    refute form.validate
    assert_equal({ "ios_text" => "Required", "ios_check" => "Tick it", "volume" => "Too quiet",
                   "day" => "Pick a day", "size" => "Pick a size" }, form.errors)
    assert_equal "Required", ios_text.props["error"]
    refute ios_check.props.key?("error"), "CupertinoCheckbox declares no error state"

    @page.dispatch_event(target: volume.wire_id, name: "change", data: 7.0)
    @page.dispatch_event(target: size.wire_id, name: "change", data: ["m"])
    assert_equal 7.0, form.values["volume"]
    assert_equal ["m"], form.values["size"]
    form.validate
    refute_includes form.errors.keys, "volume"
    refute_includes form.errors.keys, "size"
  end

  # --- autovalidate_mode --------------------------------------------------------

  def test_disabled_mode_is_the_default_and_asks_for_no_events
    form, email, = signup_form
    @page.add(form)

    refute email.props.key?("on_change")
    refute email.props.key?("on_blur")
    @page.dispatch_event(target: email.wire_id, name: "change", data: "")
    assert_nil email.validation_error
  end

  def test_always_validates_at_mount_and_after_every_change
    form, email, country, = signup_form(autovalidate_mode: "always")
    @page.add(form)

    view = @sent.last.last["patch"].find { |op| op[2] == "views" }[3].first
    mounted = view["controls"].first["controls"]
    assert_equal "Required", mounted[0]["error"], "errors are in the first patch"
    assert_equal "Pick a country", mounted[1]["error_text"]
    assert_equal true, mounted[0]["on_change"], "the form asks for change events"
    assert_equal true, mounted[1]["on_select"], "a Dropdown changes with select"

    @sent.clear
    @page.dispatch_event(target: email.wire_id, name: "change", data: "ada@example.com")

    refute email.props.key?("error")
    assert_equal({ "error" => nil }, control_patches[email.wire_id])
    assert_equal "Pick a country", country.props["error_text"]
  end

  def test_form_on_user_interaction_validates_every_field_after_any_change_until_reset
    form, email, country, terms, = signup_form(autovalidate_mode: "on_user_interaction")
    @page.add(form)
    assert_empty form.errors, "nothing is validated before the user interacts"
    assert_equal true, terms.props["on_change"]

    @page.dispatch_event(target: terms.wire_id, name: "change", data: true)

    # Flutter: once any field changed, the Form validates all of them.
    assert_equal({ "email" => "Required", "country" => "Pick a country", "news" => "Must be on",
                   "plan" => "Choose a plan" }, form.errors)
    assert_equal "Required", email.props["error"]

    form.reset
    assert_empty form.errors
    @page.update
    assert_empty form.errors, "reset forgets the interaction"
    assert_nil country.validation_error
  end

  def test_field_on_user_interaction_validates_only_that_field_after_its_changes
    email = Ruflet.text_field(key: "email", validator: REQUIRED, autovalidate_mode: "on_user_interaction")
    name = Ruflet.text_field(key: "name", validator: REQUIRED)
    form = Ruflet.form([email, name])
    @page.add(form)
    assert_empty form.errors

    @page.dispatch_event(target: name.wire_id, name: "change", data: "")
    assert_empty form.errors, "another field's change does not count as interacting with this one"

    @page.dispatch_event(target: email.wire_id, name: "change", data: "")
    assert_equal({ "email" => "Required" }, form.errors)
    @page.dispatch_event(target: email.wire_id, name: "change", data: "a")
    assert_empty form.errors
  end

  def test_on_unfocus_validates_a_field_when_it_loses_focus
    form, email, country, terms, = signup_form(autovalidate_mode: "on_unfocus")
    @page.add(form)
    [email, country, terms].each { |field| assert_equal true, field.props["on_blur"] }
    refute email.props.key?("on_change")

    @page.dispatch_event(target: email.wire_id, name: "change", data: "")
    assert_empty form.errors, "typing does not validate"

    @sent.clear
    @page.dispatch_event(target: email.wire_id, name: "blur", data: nil)

    assert_equal({ "email" => "Required" }, form.errors)
    assert_equal({ email.wire_id => { "error" => "Required" } }, control_patches)
    @page.dispatch_event(target: country.wire_id, name: "blur", data: nil)
    assert_equal({ "email" => "Required", "country" => "Pick a country" }, form.errors)
  end

  def test_on_unfocus_on_a_radio_group_listens_to_its_radios
    free = Ruflet.radio(value: "free", label: "Free")
    pro = Ruflet.radio(value: "pro", label: "Pro")
    plan = Ruflet.radio_group(content: Ruflet.column([free, pro]), key: "plan",
                              validator: ->(v) { "Choose a plan" if v.nil? }, autovalidate_mode: "on_unfocus")
    form = Ruflet.form([plan])
    @page.add(form)

    assert_equal true, free.props["on_blur"]
    assert_equal true, pro.props["on_blur"]
    refute_includes form.fields, free

    @page.dispatch_event(target: pro.wire_id, name: "blur", data: nil)
    assert_equal "Choose a plan", plan.validation_error
  end

  def test_field_mode_overrides_and_flags_follow_mode_changes
    note = Ruflet.text_field(key: "note", validator: REQUIRED, autovalidate_mode: "on_unfocus",
                             on_change: ->(_e) {})
    form = Ruflet.form([note])
    @page.add(form)
    assert_equal true, note.props["on_blur"]

    @sent.clear
    @page.update(note, autovalidate_mode: "disabled")

    refute note.props.key?("on_blur"), "a flag the form added goes when nothing needs it"
    assert_equal true, note.props["on_change"], "a flag the app's handler needs stays"
    assert_equal({ "on_blur" => nil }, control_patches[note.wire_id])
  end

  # --- form events ------------------------------------------------------------

  def test_on_submit_fires_when_a_text_field_in_the_form_submits
    events = []
    email = Ruflet.text_field(key: "email", value: "ada@example.com", on_submit: ->(e) { events << [:field, e.data] })
    terms = Ruflet.checkbox(key: "terms")
    form = Ruflet.form([email, terms], on_submit: ->(e) { events << [:form, e.control.values, e.data] })
    @page.add(form)

    assert_equal true, email.props["on_submit"]
    refute terms.props.key?("on_submit")

    @page.dispatch_event(target: email.wire_id, name: "submit", data: "ada@example.com")

    assert_equal [[:field, "ada@example.com"], [:form, { "email" => "ada@example.com", "terms" => false }, "ada@example.com"]],
                 events
  end

  def test_submit_typically_validates_and_saves
    stored = nil
    form = Ruflet.form(on_submit: ->(e) { stored = e.control.save if e.control.validate }) do
      text_field(key: "name", validator: REQUIRED)
    end
    @page.add(form)
    name = form.fields.first

    @page.dispatch_event(target: name.wire_id, name: "submit", data: "")
    assert_nil stored
    assert_equal "Required", name.props["error"]

    @page.dispatch_event(target: name.wire_id, name: "change", data: "Ada")
    @page.dispatch_event(target: name.wire_id, name: "submit", data: "Ada")
    assert_equal({ "name" => "Ada" }, stored)
    refute name.props.key?("error")
  end

  def test_on_change_fires_after_any_field_change
    changes = []
    form = Ruflet.form(on_change: ->(e) { changes << [e.control.wire_type, e.data] }) do
      switch(key: "dark")
    end
    @page.add(form)
    switch = form.fields.first
    assert_equal true, switch.props["on_change"]

    @page.dispatch_event(target: switch.wire_id, name: "change", data: true)

    assert_equal [["Form", true]], changes
    assert_equal({ "dark" => true }, form.values)
  end

  def test_fields_added_later_join_the_form
    form = Ruflet.form([Ruflet.text_field(key: "a")], autovalidate_mode: "on_unfocus")
    @page.add(form)
    late = Ruflet.text_field(key: "b", validator: REQUIRED)
    box = Ruflet.column([])
    @page.update(form, controls: form.children + [box])
    @page.update(box, controls: [late])

    assert_same form, late.form_owner
    assert_equal true, late.props["on_blur"]
    sent_late = @sent.last.last["patch"].find { |op| op[2] == "controls" }[3].first
    assert_equal true, sent_late["on_blur"], "the new field goes out with the flags its form needs"

    @page.dispatch_event(target: late.wire_id, name: "blur", data: nil)
    assert_equal({ "b" => "Required" }, form.errors)
  end
end

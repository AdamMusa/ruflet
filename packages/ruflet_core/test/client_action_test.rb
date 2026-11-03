# frozen_string_literal: true

require_relative "test_helper"

# Client actions (Flet 1.0's `action=ft.ClientAction...`): work the client
# performs inside the tap, before it sends `click`, so browsers still allow
# clipboard writes, new tabs, file pickers and the share sheet.
class RufletClientActionTest < Minitest::Test
  OPEN = {
    "service" => "UrlLauncher",
    "method" => "launch_url",
    "args" => { "url" => "https://ruflet.dev", "web_only_window_name" => "_blank" }
  }.freeze

  COPY = { "service" => "Clipboard", "method" => "set", "args" => { "data" => "token" } }.freeze

  # Every DSL name of the action-control family, with its positional
  # argument (nil when the helper takes none), its required keywords and the
  # wire type it sends.
  FAMILY = [
    [:button, "Go", {}, "Button"],
    [:elevated_button, "Go", {}, "Button"],
    [:filled_button, "Go", {}, "FilledButton"],
    [:filled_tonal_button, "Go", {}, "FilledTonalButton"],
    [:outlined_button, "Go", {}, "OutlinedButton"],
    [:text_button, "Go", {}, "TextButton"],
    [:icon_button, "add", {}, "IconButton"],
    [:filled_icon_button, "add", {}, "FilledIconButton"],
    [:filled_tonal_icon_button, "add", {}, "FilledTonalIconButton"],
    [:outlined_icon_button, "add", {}, "OutlinedIconButton"],
    [:floating_action_button, nil, { icon: "add" }, "FloatingActionButton"],
    [:container, nil, {}, "Container"],
    [:list_tile, nil, { title: "Row" }, "ListTile"],
    [:text_span, "link", {}, "TextSpan"],
    [:cupertino_button, "Go", {}, "Button"],
    [:cupertino_filled_button, "Go", {}, "FilledButton"],
    [:cupertino_tinted_button, "Go", {}, "FilledTonalButton"],
    [:cupertino_dialog_action, nil, { content: "OK" }, "Button"],
    [:cupertino_list_tile, nil, { title: "Row" }, "ListTile"]
  ].freeze

  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  def build(name, positional, required, **props)
    args = positional.nil? ? [] : [positional]
    Ruflet.public_send(name, *args, **required, **props)
  end

  def build_page(sent = [])
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end

  # -- the value type ---------------------------------------------------------

  def test_launch_url_mirrors_page_launch_url_arguments
    action = Ruflet.client_action(:launch_url, url: "https://ruflet.dev", web_window_name: "_blank",
                                               mode: :external_application)

    assert_equal "launch_url", action.type
    assert_equal(
      { "service" => "UrlLauncher", "method" => "launch_url",
        "args" => { "url" => "https://ruflet.dev", "web_only_window_name" => "_blank",
                    "mode" => "external_application" } },
      action.to_h
    )
  end

  def test_copy_to_clipboard_sends_clipboard_set_data
    assert_equal COPY, Ruflet.client_action(:copy_to_clipboard, text: "token").to_h
    assert_equal "42", Ruflet.client_action(:copy_to_clipboard, text: 42).args["data"]
  end

  def test_pick_files_sends_page_pick_files_defaults
    assert_equal(
      { "service" => "FilePicker", "method" => "pick_files",
        "args" => { "file_type" => "any", "allow_multiple" => false, "with_data" => false } },
      Ruflet.client_action(:pick_files).to_h
    )
    assert_equal(
      { "file_type" => "custom", "allow_multiple" => true, "with_data" => true,
        "dialog_title" => "Pick", "initial_directory" => "/tmp", "allowed_extensions" => %w[png jpg] },
      Ruflet.client_action(:pick_files, dialog_title: "Pick", initial_directory: "/tmp", file_type: :custom,
                                        allowed_extensions: [:png, "jpg"], allow_multiple: true, with_data: true).args
    )
  end

  def test_share_actions
    assert_equal(
      { "service" => "Share", "method" => "share_text",
        "args" => { "text" => "Hello", "title" => "Ruflet", "subject" => "Hi" } },
      Ruflet.client_action(:share_text, text: "Hello", title: "Ruflet", subject: "Hi").to_h
    )
    assert_equal({ "uri" => "https://ruflet.dev" }, Ruflet.client_action(:share_uri, uri: "https://ruflet.dev").args)
    assert_equal(
      { "files" => [{ "path" => "/tmp/a.txt" }, { "data" => "\x01\x02".b, "name" => "b.bin", "mime_type" => "x/y" }],
        "text" => "Files" },
      Ruflet.client_action(:share_files, files: ["/tmp/a.txt", { data: [1, 2], name: "b.bin", mime_type: "x/y" }],
                                         text: "Files").args
    )
    assert_equal [{ "path" => "/tmp/a.txt" }], Ruflet.client_action(:share_files, files: "/tmp/a.txt").args["files"]
  end

  def test_flet_and_page_method_spellings_are_aliases
    assert_equal OPEN, Ruflet.client_action(:open_url, url: "https://ruflet.dev", target: "_blank").to_h
    assert_equal OPEN, Ruflet.client_action(:launch_url, url: "https://ruflet.dev", web_only_window_name: "_blank").to_h
    assert_equal COPY, Ruflet.client_action(:set_clipboard, data: "token").to_h
    assert_equal COPY, Ruflet.client_action("copy_to_clipboard", value: "token").to_h
    assert_equal Ruflet::ClientAction.new(:copy_to_clipboard, text: "token"),
                 Ruflet.client_action(:set_clipboard, text: "token")
  end

  def test_nil_options_are_dropped
    assert_equal({ "url" => "https://ruflet.dev" },
                 Ruflet.client_action(:launch_url, url: "https://ruflet.dev", web_window_name: nil).args)
  end

  def test_type_for_maps_a_service_method_back_to_its_action
    assert_equal "pick_files", Ruflet::ClientAction.type_for("FilePicker", "pick_files")
    assert_equal "copy_to_clipboard", Ruflet::ClientAction.type_for("Clipboard", "set")
    assert_nil Ruflet::ClientAction.type_for("Clipboard", "get")
  end

  def test_invalid_actions_raise
    {
      -> { Ruflet.client_action(:vibrate) } => /unknown client action :vibrate/,
      -> { Ruflet.client_action(:launch_url) } => /requires :url/,
      -> { Ruflet.client_action(:launch_url, url: "") } => /:url must be a non-empty String/,
      -> { Ruflet.client_action(:launch_url, url: :home) } => /:url must be a non-empty String/,
      -> { Ruflet.client_action(:launch_url, url: "u", mode: "sideways") } => /:mode must be one of/,
      -> { Ruflet.client_action(:launch_url, url: "u", web_window_name: 1) } => /must be a String/,
      -> { Ruflet.client_action(:launch_url, url: "u", text: "x") } => /unknown keyword :text for client action :launch_url/,
      -> { Ruflet.client_action(:copy_to_clipboard) } => /requires :text/,
      -> { Ruflet.client_action(:copy_to_clipboard, text: "a", data: "b") } => /got :text twice/,
      -> { Ruflet.client_action(:copy_to_clipboard, text: { a: 1 }) } => /:text must be text/,
      -> { Ruflet.client_action(:pick_files, file_type: :pdf) } => /:file_type must be one of any/,
      -> { Ruflet.client_action(:pick_files, allow_multiple: "yes") } => /:allow_multiple must be true or false/,
      -> { Ruflet.client_action(:pick_files, allowed_extensions: "png") } => /must be an Array of Strings/,
      -> { Ruflet.client_action(:share_text, text: nil) } => /requires :text/,
      -> { Ruflet.client_action(:share_files, files: []) } => /:files must be a path/,
      -> { Ruflet.client_action(:share_files, files: [{ name: "a" }]) } => /needs :path or :data/,
      -> { Ruflet.client_action(:share_files, files: [{ url: "a" }]) } => /unknown file key :url/
    }.each do |call, message|
      error = assert_raises(ArgumentError) { call.call }
      assert_match message, error.message
    end
  end

  # -- the `action` keyword ---------------------------------------------------

  def test_every_action_control_serializes_its_action_and_result_event
    action = Ruflet.client_action(:copy_to_clipboard, text: "token")
    FAMILY.each do |name, positional, required, wire|
      control = build(name, positional, required, action: action, on_action_result: ->(_e) {})
      patch = control.to_patch

      assert_equal wire, patch["_c"], name
      assert_equal COPY, patch["action"], name
      assert_equal true, patch["on_action_result"], name
      assert control.has_handler?(:action_result), name
    end
  end

  def test_every_action_control_declares_the_keywords
    classes = FAMILY.map { |name, *| Ruflet::UI::ControlFactory::CLASS_MAP.fetch(name.to_s) }.uniq
    classes.each do |klass|
      keywords = Ruflet::UI::ControlFactory.constructor_keywords(klass)
      assert_includes keywords, :action, klass.name
      assert_includes keywords, :on_action_result, klass.name
    end
  end

  def test_action_takes_a_list_hashes_and_wire_hashes
    button = Ruflet.button(
      "Go",
      action: [
        Ruflet.client_action(:copy_to_clipboard, text: "token"),
        { type: :open_url, url: "https://ruflet.dev", target: "_blank" },
        { "type" => "pick_files", "allow_multiple" => true },
        OPEN
      ]
    )

    assert_equal [COPY, OPEN, Ruflet.client_action(:pick_files, allow_multiple: true).to_h, OPEN],
                 button.to_patch["action"]
  end

  def test_props_hold_plain_wire_data_that_round_trips
    button = Ruflet.icon_button("copy", action: Ruflet.client_action(:copy_to_clipboard, text: "token"))

    assert_instance_of Hash, button.props["action"]
    button.merge_props(action: button.props["action"])
    assert_equal COPY, button.props["action"]
    button.merge_props(action: nil)
    assert_nil button.props["action"]
  end

  def test_invalid_action_values_raise_on_the_control
    {
      -> { Ruflet.button("Go", action: "https://ruflet.dev") } => /action must be a Ruflet.client_action/,
      -> { Ruflet.button("Go", action: []) } => /action list must not be empty/,
      -> { Ruflet.list_tile(title: "Row", action: { url: "u" }) } => /needs a :type/,
      -> { Ruflet.container(action: { type: :launch_url }) } => /requires :url/,
      -> { Ruflet.text_span("x", action: { "service" => "Clipboard", "method" => "get" }) } =>
        /Clipboard.get is not a client action/,
      -> { Ruflet.fab(icon: "add", action: { "service" => "Clipboard", "method" => "set", "args" => { "text" => "x" } }) } =>
        /unknown argument "text" for client action :copy_to_clipboard/,
      -> { Ruflet.text("x", action: Ruflet.client_action(:pick_files)) } => /action/,
      -> { Ruflet.checkbox(action: Ruflet.client_action(:pick_files)) } => /action/
    }.each do |call, message|
      error = assert_raises(ArgumentError) { call.call }
      assert_match message, error.message
    end
  end

  def test_snack_bar_action_keeps_its_own_meaning
    patch = Ruflet.snack_bar(content: Ruflet.text("Saved"), action: "Undo").to_patch

    assert_equal "Undo", patch["action"]
  end

  def test_builder_blocks_take_actions
    column = Ruflet.column do
      button("Docs", action: Ruflet.client_action(:open_url, url: "https://ruflet.dev", target: "_blank"))
      cupertino_list_tile(title: "Copy", action: Ruflet.client_action(:copy_to_clipboard, text: "token"))
    end

    assert_equal %w[Button ListTile], column.children.map { |c| c.to_patch["_c"] }
    assert_equal [OPEN, COPY], column.children.map { |c| c.to_patch["action"] }
  end

  def test_text_spans_inside_text_carry_actions
    text = Ruflet.text(spans: [Ruflet.text_span("copy", action: Ruflet.client_action(:copy_to_clipboard, text: "token"))])

    assert_equal COPY, text.to_patch["spans"].first["action"]
  end

  # -- on the page --------------------------------------------------------------

  def test_page_update_validates_and_sends_the_wire_hash
    sent = []
    page = build_page(sent)
    button = Ruflet.button("Go")
    page.add(button)
    sent.clear

    page.update(button, action: Ruflet.client_action(:copy_to_clipboard, text: "token"))

    patch = sent.last.last["patch"]
    assert_includes patch, [0, 0, "action", COPY]
    assert_equal COPY, button.props["action"]
    assert_raises(ArgumentError) { page.update(button, action: { type: :launch_url }) }
  end

  def test_action_result_event_reaches_the_clicked_controls_handler
    events = []
    clicks = []
    button = Ruflet.button(
      "Upload",
      action: Ruflet.client_action(:pick_files, allow_multiple: true),
      on_click: ->(_e) { clicks << :click },
      on_action_result: ->(e) { events << e }
    )
    page = build_page
    page.add(button)

    page.dispatch_event(target: button.wire_id, name: "click", data: nil)
    page.dispatch_event(
      target: button.wire_id,
      name: "action_result",
      data: { "index" => 0, "service" => "FilePicker", "method" => "pick_files",
              "result" => [{ "id" => 0, "name" => "a.txt", "path" => nil, "size" => 3, "bytes" => nil }] }
    )

    assert_equal [:click], clicks
    assert_equal 1, events.length
    event = events.first
    assert_same button, event.control
    assert_equal "pick_files", event.action
    assert_equal 0, event.index
    assert_equal "FilePicker", event.service
    assert_equal "pick_files", event.method_name
    assert event.ok?
    refute event.error?
    assert_equal ["a.txt"], event.files.map { |file| file["name"] }
    assert_equal event.result, event.value
  end

  def test_action_result_event_reports_errors_and_void_results
    events = []
    tile = Ruflet.list_tile(
      title: "Copy",
      action: [Ruflet.client_action(:copy_to_clipboard, text: "token"), Ruflet.client_action(:share_text, text: "x")],
      on_action_result: ->(e) { events << e }
    )
    page = build_page
    page.add(tile)

    page.dispatch_event(target: tile.wire_id, name: "action_result",
                        data: { "index" => 0, "service" => "Clipboard", "method" => "set", "result" => nil })
    page.dispatch_event(target: tile.wire_id, name: "action_result",
                        data: { "index" => 1, "service" => "Share", "method" => "share_text",
                                "error" => "share sheet unavailable" })

    copied, shared = events
    assert_equal "copy_to_clipboard", copied.action
    assert copied.ok?
    assert_nil copied.value
    assert_nil copied.files
    assert_equal "share_text", shared.action
    assert shared.error?
    assert_equal "share sheet unavailable", shared.error
  end

  def test_on_action_result_can_be_attached_later
    events = []
    span = Ruflet.text_span("copy", action: Ruflet.client_action(:copy_to_clipboard, text: "token"))
    span.on(:action_result) { |e| events << e.action }
    page = build_page
    page.add(Ruflet.text(spans: [span]))

    assert_equal true, span.props["on_action_result"]
    page.dispatch_event(target: span.wire_id, name: "action_result",
                        data: { "index" => 0, "service" => "Clipboard", "method" => "set", "result" => nil })

    assert_equal ["copy_to_clipboard"], events
  end
end

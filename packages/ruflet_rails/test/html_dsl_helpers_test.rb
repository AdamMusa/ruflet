# frozen_string_literal: true

require_relative "test_helper"

# ERB helper DSL: Ruby helpers that emit HTML DSL markup, round-tripped
# through the transformer to prove both authoring styles are equivalent.
class RufletHtmlDslHelpersTest < Minitest::Test
  class Template
    include Ruflet::Rails::HtmlDsl::ViewHelpers
  end

  class RecordingHandlers
    attr_reader :navigations, :actions, :submissions, :control_events, :services

    def initialize
      @navigations = []
      @actions = []
      @submissions = []
      @control_events = []
      @services = []
    end

    def navigate(url, mode) = @navigations << [url, mode]
    def action(url:) = @actions << url
    def submit_form(form) = @submissions << form
    def field_changed(name, value); end
    def control_event(spec, event) = @control_events << [spec, event]
    def service(spec) = @services << spec
  end

  def setup
    @view = Template.new
  end

  def transform(html)
    handlers = RecordingHandlers.new
    result = Ruflet::Rails::HtmlDsl::Transformer.new(handlers: handlers).transform(html)
    [result, handlers]
  end

  def find(node, type)
    case node
    when Ruflet::Control
      return node if node.type == type

      node.props.each_value { |v| (f = find(v, type)) and return f }
      node.children.each { |c| (f = find(c, type)) and return f }
      nil
    when Array
      node.each { |v| (f = find(v, type)) and return f }
      nil
    end
  end

  def without_wire_ids(value)
    case value
    when Hash
      value.reject { |key, _| key == "_i" }.transform_values { |nested| without_wire_ids(nested) }
    when Array
      value.map { |nested| without_wire_ids(nested) }
    else
      value
    end
  end

  def test_layout_helpers_emit_dsl_tags
    markup = @view.column(class: "p-6 gap-4") do
      @view.text("Hello", class: "text-xl font-bold") + @view.row(class: "gap-2") { @view.text("a") }
    end

    assert_includes markup, '<column class="p-6 gap-4">'
    assert_includes markup, '<text class="text-xl font-bold">Hello</text>'
    assert_includes markup, '<row class="gap-2"><text>a</text></row>'
  end

  def test_snake_case_attributes_become_kebab_case
    markup = @view.button("Up", variant: "filled", icon: "add", on_click: "/counter/up")
    assert_equal '<button variant="filled" icon="add" on-click="/counter/up">Up</button>', markup
  end

  def test_service_button_emits_a_service_attribute
    markup = @view.button("Copy", service: "copy", text: "Hello 🚀")
    assert_equal '<button service="copy" text="Hello 🚀">Copy</button>', markup
  end

  def test_rive_maps_its_url_to_the_src_attribute
    markup = @view.rive("https://cdn.rive.app/animations/vehicles.riv", fit: "contain")
    assert_includes markup, 'src="https://cdn.rive.app/animations/vehicles.riv"'
    # The URL must not end up as element body text (which never loads).
    refute_includes markup, ">https://cdn.rive.app"
  end

  def test_content_is_escaped_and_booleans_render_bare
    markup = @view.text("<script>alert(1)</script>")
    assert_includes markup, "&lt;script&gt;"

    markup = @view.input("remember", type: "checkbox", checked: true, label: "Remember")
    assert_includes markup, " checked "
    refute_includes markup, 'checked="'
  end

  def test_hash_attributes_serialize_as_json
    markup = @view.widget("chart", data: { points: [1, 2] })
    assert_includes markup, "data=\"{&quot;points&quot;:[1,2]}\""
  end

  def test_spinkit_preserves_the_ruflet_studio_variant_api
    markup = @view.spinkit(wave: { color: "#74c0fc", size: 48 })
    assert_includes markup, 'variant="wave"'

    result, = transform(markup)
    spinner = result.controls.first
    assert_equal "spinkit", spinner.type
    assert_equal "wave", spinner.props["variant"]
    assert_equal "#74c0fc", spinner.props["color"]
    assert_equal 48, spinner.props["size"]
  end

  def test_map_child_helpers_build_the_same_named_layers_as_studio
    markup = @view.map(initial_center: [51.505, -0.09]) do
      @view.tile_layer(url_template: "https://tiles/{z}/{x}/{y}.png") +
        @view.marker_layer do
          @view.marker(coordinates: [51.505, -0.09]) { @view.icon("location_on") }
        end
    end

    result, = transform(markup)
    map = result.controls.first
    assert_equal %w[tile_layer marker_layer], map.props["layers"].map(&:type)
    assert_equal "marker", map.props["layers"].last.props["markers"].first.type
  end

  def test_extension_event_attributes_translate_to_native_callbacks
    markup = @view.rive(
      id: "animation",
      src: "sample.riv",
      on_state_change_target: "status",
      on_state_change_prefix: "State: "
    )
    result, handlers = transform(markup)
    event = Struct.new(:data).new("playing")
    assert result.controls.first.emit("state_change", event)
    assert_equal "status", handlers.control_events.first[0]["target"]
    assert_equal "State: ", handlers.control_events.first[0]["prefix"]
  end

  def test_helper_markup_round_trips_through_the_transformer
    markup = @view.column(class: "p-4 gap-3") do
      [
        @view.h1("Counter"),
        @view.text("42", class: "text-5xl font-bold"),
        @view.row(class: "gap-2") do
          @view.button("Up", variant: "filled", on_click: "/inc") +
            @view.link("Settings", "/settings")
        end
      ].join
    end

    result, handlers = transform(markup)
    # p-4 wraps the column in a padded container by design.
    boxed = result.controls.first
    assert_equal "container", boxed.type
    assert_equal 16, boxed.props["padding"]
    column = find(boxed, "column")
    assert_equal 12, column.props["spacing"]

    heading = column.children.first
    assert_equal 32, heading.props["size"]

    find(column, "filledbutton").emit("click", nil)
    assert_equal ["/inc"], handlers.actions

    find(column, "textbutton").emit("click", nil)
    assert_equal [["/settings", "push"]], handlers.navigations
  end

  def test_appbar_helper_round_trips
    markup = @view.appbar("Inbox", leading_icon: "menu") do
      @view.appbar_action("search", "/search")
    end
    markup += @view.text("body")

    result, = transform(markup)
    assert_equal "Inbox", result.appbar.props["title"].props["value"]
    assert_equal 1, result.appbar.props["actions"].length
  end

  def test_form_helpers_round_trip
    markup = @view.form(action: "/session") do
      @view.input("email", type: "email", label: "Email", value: "a@b.c") +
        @view.dropdown("locale", options: [%w[fr Français], %w[en English]], value: "en") +
        @view.submit("Sign in")
    end

    result, handlers = transform(markup)
    assert_equal "en", find(result.controls, "dropdown").props["value"]

    find(result.controls, "filledbutton").emit("click", nil)
    form = handlers.submissions.first
    assert_equal "/session", form[:action]
    assert_equal %w[email locale], form[:fields].keys.sort
  end

  def test_widget_reaches_the_control_registry
    result, = transform(@view.widget("progress_bar", value: 0.4))
    assert_equal "progressbar", result.controls.first.type
    assert_equal 0.4, result.controls.first.props["value"]
  end

  def test_registry_controls_are_available_as_named_view_helpers
    markup = @view.alert_dialog(modal: true) { @view.text("Saved") }

    assert_equal '<alert-dialog modal><text>Saved</text></alert-dialog>', markup

    Ruflet::UI::ControlFactory::CLASS_MAP.keys.map(&:to_s).uniq.each do |type|
      assert_respond_to @view, type
    end
  end

  def test_alert_dialog_helper_preserves_title_content_and_action_slots
    markup = @view.alert_dialog(
      id: "demo-dialog",
      modal: true,
      title: @view.text("Dialog"),
      content: @view.text("Hello world from a Ruflet dialog."),
      actions: [
        @view.text_button(
          @view.text("Close"), service: "control", target: "demo-dialog",
                               method: "update", open: "false"
        )
      ]
    )

    result, handlers = transform(markup)
    dialog = result.controls.first
    assert_equal "alertdialog", dialog.type
    assert_equal "Dialog", dialog.props["title"].props["value"]
    assert_equal "Hello world from a Ruflet dialog.", dialog.props["content"].props["value"]
    assert_equal ["textbutton"], dialog.props["actions"].map(&:type)
    assert_equal "text", dialog.props["actions"].first.props["content"].type
    assert_equal "Close", dialog.props["actions"].first.props["content"].props["value"]
    assert_empty dialog.children

    core_dialog = Ruflet::UI::ControlFactory.build(
      "alert_dialog",
      modal: true,
      title: Ruflet::UI::ControlFactory.build("text", value: "Dialog"),
      content: Ruflet::UI::ControlFactory.build("text", value: "Hello world from a Ruflet dialog."),
      actions: [
        Ruflet::UI::ControlFactory.build(
          "text_button",
          content: Ruflet::UI::ControlFactory.build("text", value: "Close"),
          on_click: ->(_event) {}
        )
      ]
    )
    assert_equal without_wire_ids(core_dialog.to_patch), without_wire_ids(dialog.to_patch)

    dialog.props["actions"].first.emit("click", nil)
    assert_equal "control", handlers.services.first["service"]
    assert_equal "demo-dialog", handlers.services.first["target"]
    assert_equal false, handlers.services.first["open"]
  end

  def test_control_valued_keywords_work_for_the_full_registry
    markup = @view.list_tile(
      title: @view.text("Inbox"),
      subtitle: @view.text("12 unread"),
      leading: @view.icon("mail")
    )

    result, = transform(markup)
    tile = result.controls.first
    assert_equal "listtile", tile.type
    assert_equal "Inbox", tile.props["title"].props["value"]
    assert_equal "12 unread", tile.props["subtitle"].props["value"]
    assert_equal "icon", tile.props["leading"].type
  end

  def test_appbar_accepts_core_control_valued_keywords
    markup = @view.appbar(
      @view.text("Inbox"),
      leading: @view.icon_button(icon: "menu"),
      actions: [@view.icon_button(icon: "search")]
    )
    markup += @view.text("body")

    result, = transform(markup)
    assert_equal "Inbox", result.appbar.props["title"].props["value"]
    assert_equal "iconbutton", result.appbar.props["leading"].type
    assert_equal ["iconbutton"], result.appbar.props["actions"].map(&:type)
  end

  def test_rich_component_helpers_round_trip
    markup = @view.column do
      [
        @view.badge("3") { @view.icon("notifications") },
        @view.list_tile(title: "Inbox", subtitle: "12 unread", leading: "mail", href: "/inbox"),
        @view.segmented_button("view", value: "list",
                               segments: [{ value: "list", label: "List", icon: "list" },
                                          { value: "grid", label: "Grid", icon: "grid_view" }]),
        @view.tabs do
          @view.tab("Overview") { @view.text("a") } + @view.tab("Details", icon: "info") { @view.text("b") }
        end
      ].join
    end

    result, = transform(markup)
    assert_equal "3", find(result.controls, "icon").props["badge"]
    assert_equal "Inbox", find(result.controls, "listtile").props["title"]
    assert_equal 2, Array(find(result.controls, "segmentedbutton").props["segments"]).length
    assert_equal 2, find(result.controls, "tabs").props["length"]
  end

  def test_fab_helper_round_trips
    result, handlers = transform(@view.fab(icon: "add", href: "/items/new") + @view.text("list"))
    refute_nil result.fab
    result.fab.emit("click", nil)
    assert_equal [["/items/new", "push"]], handlers.navigations
  end

  def test_service_and_extension_helpers
    assert_equal "<camera></camera>", @view.camera
    assert_equal "<geolocator></geolocator>", @view.geolocator
    assert_equal '<lottie src="loader.json"></lottie>', @view.lottie(src: "loader.json")
    assert_equal '<web-view url="https://x.test"></web-view>', @view.web_view(url: "https://x.test")

    result, = transform(@view.camera + @view.battery + @view.lottie(src: "x.json"))
    assert_equal %w[battery], result.services.map(&:type)
    assert_equal %w[camera lottie], result.controls.map(&:type)
  end

  def test_bottom_nav_and_container_helpers_round_trip
    markup = @view.container(class: "p-4") do
      @view.bottom_nav do
        @view.nav_item(icon: "chat", label: "Chats", href: "/wa", selected: true) +
          @view.nav_item(icon: "call", label: "Calls", href: "/wa/calls")
      end + @view.text("body")
    end

    result, handlers = transform(markup)
    assert_equal 2, result.bottom_nav.props["destinations"].length
    result.bottom_nav.emit("change", { "selected_index" => 1 })
    assert_equal [["/wa/calls", "root"]], handlers.navigations
    # container helper produced a real Container wrapping the body.
    assert_equal "container", result.controls.first.type
  end
end

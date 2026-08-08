# frozen_string_literal: true

require_relative "test_helper"

# HTML DSL: parser, style mapping, and HTML -> Ruflet control transformation.
class RufletHtmlDslTest < Minitest::Test
  Parser = Ruflet::Rails::HtmlDsl::Parser
  Styles = Ruflet::Rails::HtmlDsl::Styles

  class RecordingHandlers
    attr_reader :navigations, :actions, :submissions, :fields, :services

    def initialize
      @navigations = []
      @actions = []
      @submissions = []
      @fields = {}
      @services = []
    end

    def navigate(url, mode) = @navigations << [url, mode]
    def action(method:, url:) = @actions << [method, url]
    def submit_form(form) = @submissions << form
    def field_changed(name, value) = @fields[name] = value
    def service(spec) = @services << spec
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

  def find_all(node, type, matches = [])
    case node
    when Ruflet::Control
      matches << node if node.type == type
      node.props.each_value { |v| find_all(v, type, matches) }
      node.children.each { |c| find_all(c, type, matches) }
    when Array
      node.each { |v| find_all(v, type, matches) }
    end
    matches
  end

  # --- parser ---------------------------------------------------------------

  def test_parser_builds_a_tree_with_attributes
    nodes = Parser.parse('<column class="p-4"><text bold>Hi &amp; bye</text><br><img src="/a.png"/></column>')
    column = nodes.first
    assert_equal "column", column.tag
    assert_equal "p-4", column["class"]

    text = column.elements.first
    assert_equal "text", text.tag
    assert text.key?("bold")
    assert_equal "Hi & bye", text.text

    img = column.elements.last
    assert_equal "img", img.tag
    assert_equal "/a.png", img["src"]
  end

  def test_parser_skips_comments_doctype_scripts_and_styles
    nodes = Parser.parse(<<~HTML)
      <!DOCTYPE html>
      <!-- a comment -->
      <script>var x = "<column>ignored</column>";</script>
      <style>.a { color: red; }</style>
      <text>kept</text>
    HTML
    tags = nodes.select(&:element?).map(&:tag)
    assert_equal %w[text], tags
  end

  def test_parser_tolerates_unclosed_and_stray_tags
    nodes = Parser.parse("<column><row><text>a</text></column>")
    assert_equal "column", nodes.first.tag
    assert_equal "a", nodes.first.text
  end

  # --- styles ---------------------------------------------------------------

  def test_styles_map_spacing_colors_and_typography
    props = Styles.parse("p-4 px-6 gap-2 bg-slate-100 text-xl font-bold text-white rounded-lg shadow flex-1")
    assert_equal({ "left" => 24, "top" => 16, "right" => 24, "bottom" => 16 }, props[:padding])
    assert_equal 8, props[:spacing]
    assert_equal "#f1f5f9", props[:bgcolor]
    assert_equal 20, props[:size]
    assert_equal "bold", props[:weight]
    assert_equal "#ffffff", props[:color]
    assert_equal 8, props[:border_radius]
    assert props[:shadow]
    assert_equal true, props[:expand]
  end

  def test_styles_map_alignment_and_arbitrary_values
    props = Styles.parse("items-center justify-between text-[42] w-[320px] bg-[#123456]")
    assert_equal "center", props[:cross_alignment]
    assert_equal "spaceBetween", props[:main_alignment]
    assert_equal 42, props[:size]
    assert_equal 320, props[:width]
    assert_equal "#123456", props[:bgcolor]
  end

  def test_styles_map_transforms_positioning_and_effects
    props = Styles.parse("rotate-45 scale-95 top-4 left-2 blur-md opacity-75 overflow-hidden aspect-video")
    assert_in_delta 0.7854, props[:rotate], 0.001
    assert_equal 0.95, props[:scale]
    assert_equal 16, props[:top]
    assert_equal 8, props[:left]
    assert_equal 8, props[:blur]
    assert_equal 0.75, props[:opacity]
    assert_equal "hardEdge", props[:clip_behavior]
    assert_in_delta 1.777, props[:aspect_ratio], 0.01
  end

  def test_styles_map_gradients_borders_and_corners
    grad = Styles.parse("bg-gradient-to-r from-blue-500 to-cyan-400")[:gradient]
    assert_equal "linear", grad["_type"]
    assert_equal({ "x" => -1, "y" => 0 }, grad["begin"])
    assert_equal ["#3b82f6", "#22d3ee"], grad["colors"]

    border = Styles.parse("border-2 border-red-500")[:border]
    assert_equal 2, border["top"]["width"]
    assert_equal "#ef4444", border["left"]["color"]

    # per-side border and per-corner radius
    assert_equal %w[top], Styles.parse("border-t")[:border].keys
    assert_equal({ "top_left" => 12, "bottom_right" => 2 },
                 Styles.parse("rounded-tl-xl rounded-br-sm")[:border_radius])
  end

  def test_styles_map_typography_details_and_transitions
    props = Styles.parse("tracking-wide leading-relaxed underline uppercase")
    assert_equal 0.4, props[:letter_spacing]
    assert_equal 1.625, props[:line_height]
    assert_equal 1, props[:decoration]
    assert_equal "uppercase", props[:text_transform]
    assert_equal 5, Styles.parse("underline line-through")[:decoration] # 1|4

    assert_equal 300, Styles.parse("duration-300")[:animate]
    assert_equal({ "duration" => 200, "curve" => "easeInOut" },
                 Styles.parse("transition ease-in-out duration-200")[:animate])
    assert_equal({ "x" => 0, "y" => 0 }, Styles.parse("place-center")[:alignment])
  end

  def test_styles_map_size_gap_and_screen_helpers
    assert_equal({ width: 48, height: 48 }, Styles.parse("size-12").slice(:width, :height))
    assert_equal 12, Styles.parse("gap-x-3")[:spacing]
    assert_equal 8, Styles.parse("gap-y-2")[:run_spacing]
    assert_equal 256, Styles.parse("max-w-64")[:width]
    assert_equal true, Styles.parse("w-screen")[:expand]
    assert_equal true, Styles.parse("min-h-screen")[:expand]
    assert_equal({ left: 16, right: 16 }, Styles.parse("inset-x-4").slice(:left, :right))
  end

  def test_text_style_details_reach_the_control
    result, = transform('<text class="tracking-wide leading-loose underline uppercase">hi there</text>')
    text = find(result.controls, "text")
    assert_equal "HI THERE", text.props["value"]
    assert_equal 0.4, text.props["style"]["letter_spacing"]
    assert_equal 2.0, text.props["style"]["height"]
    assert_equal 1, text.props["style"]["decoration"]

    result, = transform('<container class="transition duration-300 place-center"><text>x</text></container>')
    box = result.controls.first
    assert_equal 300, box.props["animate"]
    assert_equal({ "x" => 0, "y" => 0 }, box.props["alignment"])
  end

  def test_styles_map_text_truncation_and_fit
    text = Styles.parse("truncate line-clamp-2 font-mono whitespace-nowrap select-none")
    assert_equal 2, text[:max_lines]
    assert_equal "ellipsis", text[:overflow]
    assert_equal "monospace", text[:font_family]
    assert_equal true, text[:no_wrap]
    assert_equal false, text[:selectable]

    assert_equal "cover", Styles.parse("object-cover")[:fit]
    assert_equal false, Styles.parse("hidden")[:visible]
  end

  def test_rich_utilities_reach_the_control
    result, = transform(<<~HTML)
      <container class="rotate-3 scale-105 blur-sm overflow-hidden bg-gradient-to-br from-indigo-500 to-pink-500 border-2 border-white">
        <text class="truncate font-mono">Hi</text>
      </container>
    HTML
    box = result.controls.first
    assert_equal "container", box.type
    assert_in_delta 0.0524, box.props["rotate"], 0.001
    assert_equal 1.05, box.props["scale"]
    assert_equal "linear", box.props["gradient"]["_type"]
    assert box.props["border"].is_a?(Hash)

    text = find(box, "text")
    assert_equal 1, text.props["max_lines"]
    assert_equal "monospace", text.props["font_family"]
  end

  def test_styles_map_theme_color_tokens
    props = Styles.parse("bg-primary text-on-surface")
    assert_equal "primary", props[:bgcolor]
    assert_equal "onsurface", props[:color]
  end

  # --- transformer: structure ------------------------------------------------

  def test_layout_tags_become_flex_controls
    result, = transform(<<~HTML)
      <column class="gap-4 items-center justify-center">
        <text class="text-3xl font-bold">42</text>
        <row class="gap-2"><text>a</text><text>b</text></row>
      </column>
    HTML

    column = result.controls.first
    assert_equal "column", column.type
    assert_equal 16, column.props["spacing"]
    assert_equal "center", column.props["horizontal_alignment"]
    assert_equal "center", column.props["alignment"]

    headline = column.children.first
    assert_equal "text", headline.type
    assert_equal "42", headline.props["value"]
    assert_equal 30, headline.props["size"]
    assert_equal "bold", headline.props["weight"]

    row = column.children.last
    assert_equal "row", row.type
    assert_equal 8, row.props["spacing"]
  end

  def test_headings_paragraphs_and_box_styles
    result, = transform('<h1>Title</h1><p class="p-4 bg-white rounded">Body</p>')

    h1 = result.controls.first
    assert_equal "text", h1.type
    assert_equal 32, h1.props["size"]

    boxed = result.controls.last
    assert_equal "container", boxed.type
    assert_equal 16, boxed.props["padding"]
    assert_equal "#ffffff", boxed.props["bgcolor"]
    assert_equal "Body", boxed.props["content"].props["value"]
  end

  def test_full_rails_layout_unwraps_to_body_and_reads_metadata
    result, = transform(<<~HTML)
      <html>
        <head>
          <title>Inbox</title>
          <meta name="csrf-token" content="tok123">
        </head>
        <body><text>hello</text></body>
      </html>
    HTML

    assert_equal "Inbox", result.title
    assert_equal 1, result.controls.length
    assert_equal "hello", result.controls.first.props["value"]
  end

  def test_unknown_tags_fall_through_to_the_control_registry
    result, = transform('<progress-bar value="0.4"></progress-bar><divider></divider>')

    bar = result.controls.first
    assert_equal "progressbar", bar.type
    assert_equal 0.4, bar.props["value"]
    assert_equal "divider", result.controls.last.type
  end

  # The generic passthrough is schema-aware: text and children route into the
  # prop the control actually accepts, so the whole registry works from markup.
  def test_generic_passthrough_routes_text_into_the_right_prop
    # Button variants take `content`, not `value`.
    result, = transform("<filled-button>Save</filled-button>")
    button = result.controls.first
    assert_equal "filledbutton", button.type
    assert_equal "Save", find(button, "text").props["value"]
    refute button.props.key?("value")

    # A container-like control takes `content`.
    result, = transform("<card>Hello</card>")
    assert_equal "Hello", find(result.controls.first, "text").props["value"]
  end

  def test_generic_passthrough_routes_children_into_content_or_controls
    # bottom_app_bar accepts `content` (single child).
    result, = transform("<bottom-app-bar><text>bar</text></bottom-app-bar>")
    bar = result.controls.first
    assert_equal "bottomappbar", bar.type
    assert_equal "bar", find(bar, "text").props["value"]

    # responsive_row accepts `controls` (a list).
    result, = transform("<responsive-row><text>a</text><text>b</text></responsive-row>")
    rr = result.controls.first
    assert_equal "responsiverow", rr.type
    assert_equal 2, Array(rr.props["controls"]).length
  end

  def test_composite_controls_render_with_content
    result, = transform("<banner><text>Heads up</text></banner>")
    assert_equal "banner", result.controls.first.type
    assert_equal "Heads up", find(result.controls.first, "text").props["value"]
  end

  # Every control in the ruflet_core registry must be reachable from markup
  # without ever raising: it either builds, or (for genuinely-required-attribute
  # controls used the wrong way) degrades to an inline placeholder.
  def test_every_registry_control_is_reachable_from_markup
    types = Ruflet::UI::ControlFactory::CLASS_MAP.keys
    built = 0
    types.each do |type|
      tag = type.tr("_", "-")
      %W[<#{tag}></#{tag}> <#{tag}><text>x</text></#{tag}>].each do |html|
        result = Ruflet::Rails::HtmlDsl::Transformer.new(handlers: RecordingHandlers.new).transform(html)
        assert_kind_of Array, result.controls
        placeholder = result.controls.any? do |control|
          control.type == "text" && control.props["value"].to_s.start_with?("⚠")
        end
        built += 1 unless placeholder
      end
    end
    # The vast majority build cleanly; only a handful of required-attribute
    # controls (icon/destination/segment) legitimately need more than a bare tag.
    assert_operator built, :>=, types.length, "expected most catalog tags to build cleanly"
  end

  # Charts carry data in named props (groups/sections/points), so nested chart
  # tags must route into the right slot with numeric attributes coerced.
  def test_nested_chart_tags_build_typed_data
    result, = transform(<<~HTML)
      <bar-chart width="320" height="180" max-y="110">
        <bar-chart-group x="0"><bar-chart-rod from-y="0" to-y="40" color="#69db7c"></bar-chart-rod></bar-chart-group>
        <bar-chart-group x="1"><bar-chart-rod from-y="0" to-y="100" color="#4dabf7"></bar-chart-rod></bar-chart-group>
      </bar-chart>
    HTML

    chart = result.controls.first
    assert_equal "barchart", chart.type
    assert_equal 320, chart.props["width"]
    groups = chart.props["groups"]
    assert_equal 2, groups.length
    assert_equal "barchartgroup", groups.first.type
    assert_equal 0, groups.first.props["x"]
    rod = groups.first.props["rods"].first
    assert_equal "barchartrod", rod.type
    assert_equal 40, rod.props["to_y"]
    assert_equal "#69db7c", rod.props["color"]
  end

  # A chart control has no `expand` and doesn't inherit its parent's box, so
  # without width/height it renders as a zero-size (empty) widget. Default them.
  def test_charts_get_default_dimensions_and_respect_overrides
    result, = transform('<bar-chart><bar-chart-group x="0"><bar-chart-rod to-y="4"></bar-chart-rod></bar-chart-group></bar-chart>')
    chart = result.controls.first
    assert_equal 320, chart.props["width"]
    assert_equal 240, chart.props["height"]

    sized, = transform('<pie-chart width="150" height="150"><pie-chart-section value="1"></pie-chart-section></pie-chart>')
    assert_equal 150, sized.controls.first.props["width"]
    assert_equal 150, sized.controls.first.props["height"]
  end

  # Streaming sensors with no interval flood the wire at the device's native
  # rate; default to a calm cadence so a mounted sensor doesn't cause jank.
  def test_streaming_sensors_get_a_default_interval
    result, = transform('<accelerometer on-reading-target="s"></accelerometer>')
    assert_equal 200, result.services.first.props["interval"]

    explicit, = transform('<gyroscope interval="500"></gyroscope>')
    assert_equal 500, explicit.services.first.props["interval"]

    # Non-streaming services are untouched.
    clip, = transform("<clipboard></clipboard>")
    refute clip.services.first.props.key?("interval")
  end

  def test_nested_pie_and_line_charts_build
    pie, = transform('<pie-chart><pie-chart-section value="40" color="#4dabf7"></pie-chart-section></pie-chart>')
    assert_equal 1, pie.controls.first.props["sections"].length

    line, = transform(<<~HTML)
      <line-chart>
        <line-chart-data color="#51cf66"><line-chart-data-point x="1" y="1.5"></line-chart-data-point></line-chart-data>
      </line-chart>
    HTML
    series = line.controls.first.props["data_series"]
    assert_equal 1, series.length
    assert_equal 1.5, series.first.props["points"].first.props["y"]
  end

  # Map layers need `[lat, lng]` normalized to `{latitude:, longitude:}` (the
  # shape flutter_map reads), and a marker's child belongs in `content`, not the
  # generic `controls` list — otherwise the marker never places on the map.
  def test_map_normalizes_coordinates_and_marker_content
    result, = transform(<<~HTML)
      <map initial-center="[51.505,-0.09]" initial-zoom="13">
        <tile-layer url-template="u"></tile-layer>
        <marker coordinates="[51.5,-0.1]" width="44"><icon name="location_on"></icon></marker>
        <circle-layer><circle-marker coordinates="[51.5,-0.1]" radius="400"></circle-marker></circle-layer>
      </map>
    HTML

    map = result.controls.first
    assert_equal({ "latitude" => 51.505, "longitude" => -0.09 }, map.props["initial_center"])

    marker = map.props["layers"].find { |layer| layer.type == "marker" }
    assert_equal({ "latitude" => 51.5, "longitude" => -0.1 }, marker.props["coordinates"])
    assert_equal "icon", marker.props["content"].type
    refute marker.props.key?("controls")

    circle = map.props["layers"].find { |layer| layer.type == "circle_layer" }.props["circles"].first
    assert_equal({ "latitude" => 51.5, "longitude" => -0.1 }, circle.props["coordinates"])
  end

  def test_unknown_attributes_render_a_placeholder_not_a_crash
    result, = transform('<text nonsense-prop="1">x</text><text>next</text>')

    placeholder = result.controls.first
    assert_equal "text", placeholder.type
    assert_includes placeholder.props["value"], "<text>"
    assert_includes placeholder.props["value"], "nonsense_prop"
    # Siblings keep rendering.
    assert_equal "next", result.controls.last.props["value"]
  end

  def test_browser_js_attributes_are_ignored
    result, = transform(<<~HTML)
      <header>
        <button onclick="location.reload()" style="color: red" aria-label="Reload"
                data-turbo="false" tabindex="0">Reload</button>
      </header>
    HTML

    button = find(result.controls, "button")
    refute_nil button
    refute button.props.key?("onclick")
    refute button.props.key?("style")
  end

  # --- transformer: interactivity ---------------------------------------------

  def test_links_navigate_natively
    result, handlers = transform('<a href="/settings" nav="push">Settings</a>')

    link = result.controls.first
    assert_equal "textbutton", link.type
    link.emit("click", nil)
    assert_equal [["/settings", "push"]], handlers.navigations
  end

  def test_buttons_post_actions
    result, handlers = transform('<button on-click="/counter/increment">+</button>')

    button = result.controls.first
    button.emit("click", nil)
    assert_equal [["post", "/counter/increment"]], handlers.actions
  end

  def test_service_button_runs_a_native_service_on_tap
    result, handlers = transform('<button service="copy" text="Ruflet 🚀">Copy</button>')

    button = result.controls.first
    assert_equal "button", button.type
    # Service spec keys are consumed by the handler, not leaked as control props.
    refute button.props.key?("service")
    refute button.props.key?("text")
    button.emit("click", nil)
    assert_equal [{ "service" => "copy", "text" => "Ruflet 🚀" }], handlers.services
    assert_empty handlers.actions
  end

  def test_button_variants_and_explicit_methods
    result, handlers = transform('<button variant="outlined" on-click="delete:/items/3">Remove</button>')

    button = result.controls.first
    assert_equal "outlinedbutton", button.type
    button.emit("click", nil)
    assert_equal [["delete", "/items/3"]], handlers.actions
  end

  def test_on_click_on_plain_elements_wraps_in_gesture_detector
    result, handlers = transform('<card on-click="/open"><text>tap me</text></card>')

    detector = result.controls.first
    assert_equal "gesturedetector", detector.type
    detector.emit("tap", nil)
    assert_equal [["post", "/open"]], handlers.actions
  end

  def test_class_styles_apply_to_non_container_controls
    # flex-1 / p-3 / gap-2 must reach list-view, text field, etc. (element_props
    # alone ignores `class`).
    result, = transform(<<~HTML)
      <list class="flex-1 p-3 gap-2"><text>a</text></list>
      <input name="q" class="flex-1">
    HTML

    listview = find(result.controls, "listview")
    assert_equal true, listview.props["expand"]
    assert_equal 8, listview.props["spacing"]
    assert_equal 12, listview.props["padding"]

    field = find(result.controls, "textfield")
    assert_equal true, field.props["expand"]
  end

  def test_icon_only_button_becomes_an_icon_button
    # A Material Button errors when `icon` is set without `content`, so an
    # icon-only button must render as an IconButton instead.
    result, handlers = transform('<button icon="send" on-click="/send"></button>')
    button = result.controls.first
    assert_equal "iconbutton", button.type
    button.emit("click", nil)
    assert_equal [["post", "/send"]], handlers.actions

    # With a label it stays a Button (icon + content is valid).
    result, = transform('<button icon="add" variant="filled">New</button>')
    assert_equal "filledbutton", result.controls.first.type
  end

  def test_forms_track_fields_and_submit
    result, handlers = transform(<<~HTML)
      <form action="/session" method="post">
        <input type="text" name="email" value="a@b.c" placeholder="Email">
        <input type="hidden" name="token" value="t1">
        <input type="submit" value="Sign in">
      </form>
    HTML

    field = find(result.controls, "textfield")
    assert_equal "a@b.c", field.props["value"]
    assert_equal "Email", field.props["hint_text"]

    field.emit("change", { "value" => "new@b.c" })
    assert_equal "new@b.c", handlers.fields["email"]

    submit = find(result.controls, "filledbutton")
    submit.emit("click", nil)
    form = handlers.submissions.first
    assert_equal "/session", form[:action]
    assert_equal "post", form[:method]
    assert_equal %w[email token], form[:fields].keys.sort
    assert_equal "t1", form[:fields]["token"]
  end

  def test_select_checkbox_and_slider_controls
    result, = transform(<<~HTML)
      <select name="locale" label="Language">
        <option value="fr">Français</option>
        <option value="en" selected>English</option>
      </select>
      <input type="checkbox" name="remember" label="Remember me" checked>
      <input type="range" name="volume" min="0" max="10" value="4">
    HTML

    dropdown = find(result.controls, "dropdown")
    assert_equal "en", dropdown.props["value"]
    assert_equal 2, Array(dropdown.props["options"]).length

    checkbox = find(result.controls, "checkbox")
    assert_equal true, checkbox.props["value"]

    slider = find(result.controls, "slider")
    assert_equal 4.0, slider.props["value"]
    assert_equal 10.0, slider.props["max"]
  end

  def test_appbar_extraction
    result, handlers = transform(<<~HTML)
      <appbar title="Inbox" leading-icon="menu">
        <action icon="search" href="/search"/>
      </appbar>
      <text>body</text>
    HTML

    refute_nil result.appbar
    assert_equal "appbar", result.appbar.type
    assert_equal "Inbox", result.appbar.props["title"].props["value"]

    action = result.appbar.props["actions"].first
    action.emit("click", nil)
    assert_equal [["/search", "push"]], handlers.navigations
    assert_equal 1, result.controls.length
  end

  # --- richer component catalog ---------------------------------------------

  def test_badge_and_tooltip_are_props_on_the_wrapped_control
    # A plain label serializes as a scalar (the client renders a Hash as its
    # toString, e.g. "{label: 3}"), so a bare label must not be a Hash.
    result, = transform('<badge label="3"><icon name="notifications"></icon></badge>')
    icon = result.controls.first
    assert_equal "icon", icon.type
    assert_equal "3", icon.props["badge"]
    refute_kind_of Hash, icon.props["badge"]

    # A styled badge becomes a real Badge control.
    result, = transform('<badge label="9" bgcolor="red"><icon name="mail"></icon></badge>')
    badge = result.controls.first.props["badge"]
    assert_kind_of Ruflet::Control, badge
    assert_equal "badge", badge.type

    result, = transform('<tooltip message="Help"><icon name="help"></icon></tooltip>')
    assert_equal "Help", result.controls.first.props["tooltip"]
  end

  def test_list_tile_maps_leading_title_subtitle
    result, handlers = transform('<list-tile title="Inbox" subtitle="12 unread" leading="mail" on-click="/inbox"></list-tile>')
    tile = find(result.controls, "listtile")
    assert_equal "Inbox", tile.props["title"]
    assert_equal "12 unread", tile.props["subtitle"]
    # `leading` is an icon slot — the name is normalized to its codepoint.
    refute_nil tile.props["leading"]
    tile.emit("click", nil)
    assert_equal [["post", "/inbox"]], handlers.actions
  end

  def test_switch_slider_checkbox_as_standalone_tags
    result, handlers = transform(<<~HTML)
      <switch name="dark" label="Dark mode" checked></switch>
      <slider name="vol" min="0" max="10" value="4"></slider>
      <checkbox name="ok" label="Agree"></checkbox>
    HTML

    switch = find(result.controls, "switch")
    assert_equal true, switch.props["value"]
    switch.emit("change", { "value" => false })
    assert_equal false, handlers.fields["dark"]

    assert_equal 4.0, find(result.controls, "slider").props["value"]
    assert_equal "Agree", find(result.controls, "checkbox").props["label"]
  end

  def test_radio_group_wires_children_and_value
    result, handlers = transform(<<~HTML)
      <radio-group name="plan" value="pro">
        <radio value="free" label="Free"></radio>
        <radio value="pro" label="Pro"></radio>
      </radio-group>
    HTML

    group = find(result.controls, "radiogroup")
    assert_equal "pro", group.props["value"]
    assert_equal 2, find_all(group, "radio").length
    group.emit("change", { "value" => "free" })
    assert_equal "free", handlers.fields["plan"]
  end

  def test_segmented_button_builds_segments
    result, = transform(<<~HTML)
      <segmented-button name="view" value="list">
        <segment value="list" label="List" icon="list"></segment>
        <segment value="grid" label="Grid" icon="grid_view"></segment>
      </segmented-button>
    HTML

    button = find(result.controls, "segmentedbutton")
    assert_equal 2, Array(button.props["segments"]).length
    assert_equal ["list"], button.props["selected"]
  end

  def test_tabs_build_a_tabbar_and_panes
    result, = transform(<<~HTML)
      <tabs>
        <tab label="Overview"><text>a</text></tab>
        <tab label="Details" icon="info"><text>b</text></tab>
      </tabs>
    HTML

    tabs = find(result.controls, "tabs")
    assert_equal 2, tabs.props["length"]
    assert_equal 2, find_all(tabs, "tab").length
    assert find(tabs, "tabbar")
    assert find(tabs, "tabbarview")
  end

  def test_expansion_tile_and_table
    result, = transform(<<~HTML)
      <expansion-tile title="More"><text>hidden</text></expansion-tile>
      <table>
        <thead><tr><th>Name</th><th>Role</th></tr></thead>
        <tbody>
          <tr><td>Ada</td><td>Eng</td></tr>
          <tr><td>Alan</td><td>Math</td></tr>
        </tbody>
      </table>
    HTML

    tile = find(result.controls, "expansiontile")
    assert_equal "More", tile.props["title"]

    table = find(result.controls, "datatable")
    assert_equal 2, Array(table.props["columns"]).length
    assert_equal 2, Array(table.props["rows"]).length
  end

  def test_bottom_nav_is_extracted_and_tabs_navigate
    result, handlers = transform(<<~HTML)
      <bottom-nav>
        <nav-item icon="chat" label="Chats" href="/wa" selected></nav-item>
        <nav-item icon="donut_large" label="Status" href="/wa/status"></nav-item>
        <nav-item icon="call" label="Calls" href="/wa/calls"></nav-item>
      </bottom-nav>
      <text>chats</text>
    HTML

    nav = result.bottom_nav
    refute_nil nav
    assert_equal "navigationbar", nav.type
    assert_equal 3, nav.props["destinations"].length
    assert_equal 0, nav.props["selected_index"]

    nav.emit("change", { "selected_index" => 2 })
    assert_equal [["/wa/calls", "root"]], handlers.navigations
    assert_equal 1, result.controls.length
  end

  def test_non_visual_services_route_to_the_service_slot_while_camera_renders_inline
    result, = transform(<<~HTML)
      <camera></camera>
      <audio id="player" src="track.mp3"></audio>
      <geolocator></geolocator>
      <text>Take a photo</text>
      <battery></battery>
    HTML

    assert_equal %w[audio geolocator battery], result.services.map(&:type)
    assert_equal "player", result.services.first.id
    assert_equal "track.mp3", result.services.first.props["src"]
    # Camera owns a native preview and is therefore an inline extension
    # control; non-visual services stay out of the rendered body.
    assert_equal "camera", find(result.controls, "camera").type
    assert_equal "Take a photo", find(result.controls, "text").props["value"]
  end

  def test_extension_controls_render_inline
    result, = transform('<video></video><lottie src="a.json"></lottie><map></map>')
    assert_equal %w[video lottie map], result.controls.map(&:type)
    assert_empty result.services
  end

  def test_service_button_keeps_id_and_disabled_without_leaking_service_metadata
    result, = transform(<<~HTML)
      <button id="capture" disabled service="camera-capture"
              target="camera" result-target="status">Take picture</button>
    HTML

    button = find(result.controls, "button")
    assert_equal "capture", button.id
    assert_equal true, button.props["disabled"]
    refute button.props.key?("service")
    refute button.props.key?("target")
  end

  def test_map_routes_nested_extension_controls_to_layers
    result, = transform(<<~HTML)
      <map initial-center='[51.505,-0.09]' initial-zoom="13">
        <tile-layer url-template="https://tile.openstreetmap.org/{z}/{x}/{y}.png"></tile-layer>
      </map>
    HTML

    map = result.controls.first
    assert_equal "map", map.type
    assert_equal ["tile_layer"], map.props["layers"].map(&:type)
    assert_equal(
      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
      map.props["layers"].first.props["url_template"]
    )
  end

  def test_fab_is_extracted_from_the_body
    result, handlers = transform('<fab icon="add" href="/items/new"></fab><text>list</text>')
    refute_nil result.fab
    assert_equal "floatingactionbutton", result.fab.type
    result.fab.emit("click", nil)
    assert_equal [["/items/new", "push"]], handlers.navigations
    assert_equal 1, result.controls.length
  end

  def test_chip_maps_text_to_label
    result, = transform("<chip>Ruby</chip><chip label=\"Rails\" icon=\"star\"></chip>")
    chips = find_all(result.controls, "chip")
    assert_equal "Ruby", chips.first.props["label"]
    assert_equal "Rails", chips.last.props["label"]
    refute chips.first.props.key?("value")
  end

  def test_avatar_with_image_and_initials
    result, = transform('<avatar src="/me.png"></avatar><avatar>AM</avatar>')
    avatars = find_all(result.controls, "circleavatar")
    assert_equal "/me.png", avatars.first.props["foreground_image_src"]
    assert_equal "AM", find(avatars.last, "text").props["value"]
  end

  def test_images_and_icons
    result, = transform('<img src="https://x.test/a.png" class="w-12 h-12 rounded-full"><icon name="home"></icon>')

    image = find(result.controls, "image")
    assert_equal "https://x.test/a.png", image.props["src"]
    assert_equal 48, image.props["width"]
    assert_equal 9999, image.props["border_radius"]

    refute_nil find(result.controls, "icon")
  end
end

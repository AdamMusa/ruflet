# frozen_string_literal: true

require "json"
require "set"

module Ruflet
  module Rails
    module HtmlDsl
      # Turns parsed HTML DSL markup into real Ruflet controls.
      #
      # Known tags map to first-class controls (column, row, text, button,
      # inputs, ...). Any other tag falls through to the full ruflet_core
      # control registry (`<progress-bar value="0.4">` builds a ProgressBar),
      # so the whole widget catalog is reachable from markup.
      #
      # `handlers` is the running app (HtmlApp): it receives navigation,
      # actions, form submissions, and field changes.
      class Transformer
        Result = Struct.new(:controls, :appbar, :fab, :bottom_nav, :services, :on_load, :title, keyword_init: true)

        HEADING_STYLES = {
          "h1" => { size: 32, weight: "bold" },
          "h2" => { size: 28, weight: "bold" },
          "h3" => { size: 24, weight: "w600" },
          "h4" => { size: 20, weight: "w600" },
          "h5" => { size: 18, weight: "w600" },
          "h6" => { size: 16, weight: "w600" }
        }.freeze

        TEXT_TAGS = %w[text span p label h1 h2 h3 h4 h5 h6].freeze
        # Tags that own their tap handling; never wrap them in a gesture detector.
        SELF_CLICKING_TAGS = %w[a button input select textarea form list-tile fab].freeze
        CONTAINER_TAGS = %w[div section article main header footer aside container].freeze
        SKIPPED_TAGS = %w[head meta link title base br template].freeze

        # Non-visual platform services (sensors, storage, permissions, …). Declared in
        # markup, they mount on the page's service registry rather than in the
        # visible control tree. Audio is also a service in the Explorer client
        # (it has no createWidget implementation); video/charts remain ordinary
        # inline controls.
        SERVICE_TAGS = %w[
          audio audio-recorder barometer battery clipboard connectivity
          file-picker flashlight geolocator gyroscope accelerometer magnetometer
          haptic-feedback permission-handler screen-brightness secure-storage
          shake-detector share shared-preferences storage-paths url-launcher
          user-accelerometer wakelock semantics-service
        ].freeze
        SERVICE_TYPES = SERVICE_TAGS.map { |tag| tag.tr("-", "_") }.to_set.freeze

        # Attributes consumed by the DSL itself, never forwarded as props.
        RESERVED_ATTRIBUTES = %w[class href nav].freeze
        FIELD_ATTRIBUTES = %w[type name value label placeholder checked rows min max].freeze
        # Browser-only attributes carried by real-world HTML; never props.
        HTML_NOISE_ATTRIBUTES = %w[style role tabindex target rel lang dir translate draggable
                                   contenteditable autocapitalize autocorrect autocomplete
                                   spellcheck xmlns accept-charset enctype novalidate].freeze

        TEXT_STYLE_KEYS = %i[size weight color italic text_align font_family
                             max_lines no_wrap overflow selectable].freeze
        # Box/visual styles applied to a control (or its wrapping container).
        BOX_STYLE_KEYS = %i[padding margin bgcolor border_radius border shadow opacity
                            width height rotate scale top left right bottom blur
                            aspect_ratio clip_behavior gradient visible alignment animate].freeze
        # Every style key a control may pick up when its schema allows it. Excludes
        # :alignment (which is {x,y} for boxes but a main-axis string for flex).
        SCHEMA_STYLE_KEYS = %i[expand width height spacing fit bgcolor color size weight italic
                               text_align font_family max_lines no_wrap overflow selectable
                               padding margin border_radius border shadow opacity rotate scale
                               top left right bottom blur aspect_ratio clip_behavior gradient
                               visible animate].freeze

        # Attributes naming something the client fetches for itself (an image,
        # a sound, a video poster) rather than something Ruby resolves.
        ASSET_URL_ATTRIBUTE = /\A(?:src|url|poster)\z|-(?:src|url)\z/

        def initialize(handlers:, asset_base_url: nil)
          @handlers = handlers
          @asset_base_url = asset_base_url.to_s.sub(%r{/+\z}, "")
        end

        # Screens are dispatched in-process, but media is not: the client loads
        # an image or a sound itself, over HTTP, so those URLs are the one place
        # that still needs a real host. A root-relative path ("/assets/logo.png",
        # which is what the Rails asset pipeline returns) is resolved against the
        # host the client connected on. Anything already absolute — an external
        # CDN, a data: URI, a protocol-relative "//host/x" — is left alone, and
        # so is a bare name, which the client resolves against its bundled
        # assets directory.
        def resolve_asset_url(value)
          return value unless value.is_a?(String)
          return value if @asset_base_url.empty?
          return value unless value.start_with?("/")
          return value if value.start_with?("//")

          "#{@asset_base_url}#{value}"
        end

        def transform(html)
          nodes = Parser.parse(html)
          @result = Result.new(controls: [], appbar: nil, fab: nil, bottom_nav: nil, services: [],
                               on_load: [], title: nil)
          scan_document_metadata(nodes)

          @result.controls = build_children(content_nodes(nodes), form: nil)
          @result
        end

        private

        # --- document scanning --------------------------------------------------

        def scan_document_metadata(nodes)
          each_element(nodes) do |element|
            @result.title = element.text if element.tag == "title" && @result.title.nil?
          end
        end

        def each_element(nodes, &block)
          nodes.each do |node|
            next unless node.element?

            block.call(node)
            each_element(node.children, &block)
          end
        end

        # Unwrap html/body wrappers so a full Rails layout and a bare partial
        # both work as screen sources.
        def content_nodes(nodes)
          html = nodes.find { |node| node.element? && node.tag == "html" }
          nodes = html.children if html
          body = nodes.find { |node| node.element? && node.tag == "body" }
          body ? body.children : nodes
        end

        # --- tree building ------------------------------------------------------

        def build_children(nodes, form:)
          nodes.filter_map { |node| build_node(node, form: form) }
        end

        def build_node(node, form:)
          return build_text_run(node.value) if node.text?

          element = node
          return nil if SKIPPED_TAGS.include?(element.tag)
          return extract_appbar(element) if element.tag == "appbar"
          return extract_fab(element) if element.tag == "fab"
          return extract_bottom_nav(element) if element.tag == "bottom-nav"
          return extract_service(element) if SERVICE_TYPES.include?(element.tag.tr("-", "_"))

          control = build_element(element, form: form)
          return nil unless control

          finalize(control, element)
        rescue ArgumentError => e
          # One bad element must not take down the screen (a stray attribute,
          # an unknown icon, a page of plain web HTML): render a visible
          # placeholder in its spot and keep building.
          build_error_placeholder(node, e)
        end

        def build_error_placeholder(node, error)
          tag = node.element? ? node.tag : "text"
          text("⚠ <#{tag}> #{error.message}", color: "#b91c1c", size: 12)
        end

        def build_text_run(value)
          stripped = value.strip
          stripped.empty? ? nil : text(collapse_whitespace(stripped))
        end

        def build_element(element, form:)
          styles = Styles.parse(element["class"])
          case element.tag
          when *TEXT_TAGS then build_text(element, styles)
          when *CONTAINER_TAGS then build_container(element, styles, form: form)
          when "column", "row" then build_flex(element, styles, form: form)
          when "stack" then stack(build_children(element.children, form: form), **control_props(element, "stack"))
          when "list", "list-view" then list_view(build_children(element.children, form: form),
                                                  **control_props(element, "listview"))
          when "grid", "grid-view" then grid_view(build_children(element.children, form: form),
                                                  **control_props(element, "gridview"))
          when "card" then build_card(element, styles, form: form)
          when "center" then center_of(element, form: form)
          when "spacer" then container(expand: true)
          when "hr", "divider" then divider(**element_props(element))
          when "markdown" then markdown(element.text, **element_props(element))
          when "img", "image" then build_image(element, styles)
          when "icon" then icon(element["name"] || element.text, **element_props(element, except: %w[name]))
          when "a" then build_link(element, styles, form: form)
          when "button" then build_button(element, form: form)
          when "input" then build_input(element, form: form)
          when "textarea" then build_textarea(element, form: form)
          when "select" then build_select(element, form: form)
          when "form" then build_form(element, styles)
          when "ul", "ol" then build_list(element, styles, form: form)
          when "badge" then build_badge(element, form: form)
          when "tooltip" then build_tooltip(element, form: form)
          when "list-tile" then build_list_tile(element)
          when "expansion-tile" then build_expansion_tile(element, form: form)
          when "tabs" then build_tabs(element, styles, form: form)
          when "segmented-button" then build_segmented_button(element, form: form)
          when "radio-group" then build_radio_group(element, styles, form: form)
          when "radio" then build_radio(element)
          when "switch" then build_toggle(element, form: form, builder: :switch)
          when "checkbox" then build_toggle(element, form: form, builder: :checkbox)
          when "slider" then build_slider(element, form: form)
          when "textfield", "text-field" then build_textfield(element, form: form,
                                                              multiline: element.key?("multiline"))
          when "table" then build_table(element, form: form)
          when "avatar" then build_avatar(element)
          when "chip" then build_chip(element)
          when "progress" then progress_bar(**element_props(element))
          else
            build_generic(element, form: form)
          end
        end

        def build_text(element, styles)
          props = { value: apply_text_transform(collapse_whitespace(element.text), styles[:text_transform]) }
          props.merge!(HEADING_STYLES[element.tag] || {})
          props.merge!(styles.slice(*TEXT_STYLE_KEYS))
          style = text_style_map(styles)
          props[:style] = style unless style.empty?
          props.merge!(element_props(element))
          wrap_in_box(text(**props), styles)
        end

        # letter-spacing / line-height / decoration live in a nested TextStyle;
        # the client copyWiths top-level size/color over it, so both coexist.
        def text_style_map(styles)
          map = {}
          map["letter_spacing"] = styles[:letter_spacing] if styles.key?(:letter_spacing)
          map["height"] = styles[:line_height] if styles[:line_height]
          map["decoration"] = styles[:decoration] if styles[:decoration]
          map
        end

        def apply_text_transform(value, transform)
          case transform
          when "uppercase" then value.upcase
          when "lowercase" then value.downcase
          when "capitalize" then value.gsub(/\b\w/, &:upcase)
          else value
          end
        end

        def build_container(element, styles, form:)
          children = build_children(element.children, form: form)
          content = children.length == 1 ? children.first : column(children, **flex_props(styles))
          props = element_props(element)
          props[:content] = content if content
          props[:alignment] = { x: 0, y: 0 } if styles[:main_alignment] == "center" &&
                                                styles[:cross_alignment] == "center"
          container(**box_props(styles), **props)
        end

        def build_flex(element, styles, form:)
          children = build_children(element.children, form: form)
          builder = element.tag == "column" ? :column : :row
          control = send(builder, children, **flex_props(styles, axis: element.tag),
                                            **element_props(element))
          wrap_in_box(control, styles)
        end

        def build_card(element, styles, form:)
          children = build_children(element.children, form: form)
          content = children.length == 1 ? children.first : column(children, **flex_props(styles))
          content = container(content: content, padding: styles[:padding] || 16)
          card(content, **element_props(element))
        end

        def center_of(element, form:)
          children = build_children(element.children, form: form)
          content = children.length == 1 ? children.first : column(children, tight: true)
          container(content: content, alignment: { x: 0, y: 0 }, expand: true)
        end

        def build_image(element, styles)
          props = element_props(element, except: %w[src alt])
          props[:semantics_label] = element["alt"] if element["alt"]
          props.merge!(styles.slice(:width, :height, :border_radius, :fit, :opacity,
                                    :aspect_ratio, :rotate, :scale))
          image(resolve_asset_url(element["src"]), **props)
        end

        def build_list(element, styles, form:)
          items = element.elements.select { |child| child.tag == "li" }.map do |item|
            children = build_children(item.children, form: form)
            children.length == 1 ? children.first : row(children, spacing: 6)
          end
          column(items, **flex_props(styles, axis: "column"), **element_props(element))
        end

        # --- interactive elements ----------------------------------------------

        def build_link(element, styles, form:)
          href = element["href"].to_s
          mode = element["nav"] || "push"
          on_click = navigation_handler(href, mode)
          label_nodes = element.children
          nested = element.elements

          if nested.empty?
            props = styles.slice(*TEXT_STYLE_KEYS)
            text_button(content: text(collapse_whitespace(element.text), **props), on_click: on_click)
          else
            children = build_children(label_nodes, form: form)
            content = children.length == 1 ? children.first : column(children, tight: true)
            gesture_detector(content: wrap_in_box(content, styles), on_tap: on_click)
          end
        end

        BUTTON_VARIANTS = {
          "filled" => :filled_button, "tonal" => :filled_tonal_button,
          "outlined" => :outlined_button, "text" => :text_button, "elevated" => :button
        }.freeze

        def build_button(element, form:)
          label = collapse_whitespace(element.text)
          icon = element["icon"]
          on_click =
            if element["service"]
              register_on_load(element)
              service_handler(element)
            elsif element["on-click"]
              action_handler(element["on-click"])
            elsif element["href"]
              navigation_handler(element["href"], element["nav"] || "push")
            elsif form
              submit_handler(form)
            end

          # A service button's arbitrary attributes are native method
          # arguments, not button props. Keep visual styling from `class`, but
          # never leak a future service argument into the strict Button schema.
          # Service metadata is not part of Button's schema, but `id` and
          # `disabled` still belong to the button itself. Camera uses both: the
          # capture action starts disabled and is enabled by id after init.
          skip = if element["service"]
                   element.attrs.keys - %w[id disabled]
                 else
                   %w[icon variant type name value]
                 end

          # An icon with no label must be an IconButton: the Material Button
          # control renders an ErrorControl when `icon` is set without `content`.
          if icon && label.empty?
            props = control_props(element, "iconbutton", except: skip)
            props[:on_click] = on_click if on_click
            return icon_button(icon, **props)
          end

          builder = BUTTON_VARIANTS[element["variant"]] || :button
          props = control_props(element, "filledbutton", except: skip)
          props[:icon] = icon if icon
          props[:on_click] = on_click if on_click
          send(builder, label.empty? ? nil : label, **props)
        end

        # `<button service="copy" text="…">` — tapping runs a native platform
        # service (clipboard, share, haptics, flashlight, launch, …). The whole
        # element's attributes are passed as the spec.
        def service_handler(element)
          spec = service_spec(element)
          handlers = @handlers
          ->(_event) { handlers.service(spec) }
        end

        def service_spec(element)
          element.attrs.transform_values { |value| coerce_value(value) }
        end

        # `<button service="battery" result-target="x" on-load>` runs the service
        # once when the screen appears, the way Studio calls `refresh_info` at
        # build time to populate a panel before any tap. Collected here and run
        # by HtmlApp after the screen mounts.
        def register_on_load(element)
          @result.on_load << service_spec(element) if element.attrs.key?("on-load")
        end

        def build_input(element, form:)
          type = (element["type"] || "text").downcase
          name = element["name"]

          case type
          when "checkbox"
            build_toggle(element, form: form, builder: :checkbox)
          when "range"
            build_slider(element, form: form)
          when "radio"
            build_radio(element)
          when "submit"
            props = { on_click: form ? submit_handler(form) : nil }.compact
            filled_button(element["value"] || "Submit", **props)
          when "hidden"
            register_field(form, name, element["value"])
            nil
          else
            build_textfield(element, form: form, password: type == "password",
                                     keyboard_type: keyboard_for(type))
          end
        end

        def build_textfield(element, form:, password: false, keyboard_type: nil, multiline: false)
          props = control_props(element, "textfield", except: FIELD_ATTRIBUTES)
          props[:label] = element["label"] if element["label"]
          props[:hint_text] = element["placeholder"] if element["placeholder"]
          props[:password] = true if password
          props[:keyboard_type] = keyboard_type if keyboard_type
          if multiline
            props[:multiline] = true
            props[:min_lines] = (element["rows"] || 3).to_i
          end
          props[:on_change] = field_handler(element["name"])
          props.delete(:on_change) if props[:on_change].nil?
          register_field(form, element["name"], element["value"])
          text_field(element["value"], **props)
        end

        def build_textarea(element, form:)
          element.attrs["value"] ||= element.text unless element.text.empty?
          build_textfield(element, form: form, multiline: true)
        end

        def build_select(element, form:)
          options = element.elements.select { |child| child.tag == "option" }.map do |option|
            dropdown_option(option["value"] || option.text, text: option.text)
          end
          selected = element.elements.find { |child| child.tag == "option" && child.key?("selected") }
          value = element["value"] || selected&.[]("value") || selected&.text
          register_field(form, element["name"], value)
          props = { value: value, label: element["label"],
                    on_select: field_handler(element["name"]) }.compact
          dropdown(options, **props, **control_props(element, "dropdown", except: FIELD_ATTRIBUTES))
        end

        def build_form(element, styles)
          form = {
            action: element["action"].to_s,
                        fields: {}
          }
          children = build_children(element.children, form: form)
          wrap_in_box(column(children, **flex_props(styles, axis: "column")), styles)
        end

        def keyboard_for(type)
          { "email" => "email", "number" => "number", "tel" => "phone", "url" => "url" }[type]
        end

        # --- stateful components --------------------------------------------------

        # <switch name="dark" label="Dark mode" checked> / <checkbox ...> —
        # named toggles report their value like form fields.
        def build_toggle(element, form:, builder:)
          name = element["name"]
          checked = element.key?("checked")
          props = { label: element["label"], value: checked, on_change: field_handler(name) }.compact
          register_field(form, name, checked)
          send(builder, **props, **element_props(element, except: FIELD_ATTRIBUTES))
        end

        def build_slider(element, form:)
          name = element["name"]
          props = { value: element["value"]&.to_f, min: (element["min"] || 0).to_f,
                    max: (element["max"] || 100).to_f, on_change: field_handler(name) }.compact
          attach_declared_events(element, props, registry_props("slider"))
          register_field(form, name, element["value"])
          slider(**props, **element_props(element, except: FIELD_ATTRIBUTES))
        end

        def build_radio(element)
          props = { value: element["value"], label: element["label"] }.compact
          radio(**props, **element_props(element, except: FIELD_ATTRIBUTES))
        end

        # <radio-group name="plan" value="pro"><radio value="free" label="Free">...</radio-group>
        def build_radio_group(element, styles, form:)
          name = element["name"]
          children = build_children(element.children, form: form)
          register_field(form, name, element["value"])
          props = { value: element["value"], on_change: field_handler(name) }.compact
          radio_group(column(children, **flex_props(styles)),
                      **props, **element_props(element, except: FIELD_ATTRIBUTES))
        end

        # <segmented-button name="view" value="list"><segment value="list" label="List" icon="list"/>...
        def build_segmented_button(element, form:)
          segments = element.elements.select { |child| child.tag == "segment" }.map do |seg|
            props = { label: seg["label"] || (seg.text.empty? ? nil : seg.text), icon: seg["icon"] }.compact
            segment(seg["value"], **props)
          end
          name = element["name"]
          props = { on_change: field_handler(name) }.compact
          props.merge!(element_props(element, except: FIELD_ATTRIBUTES))
          if element["value"]
            props[:selected] = [element["value"]]
          else
            props[:allow_empty_selection] = true unless props.key?(:allow_empty_selection)
          end
          register_field(form, name, element["value"])
          segmented_button(segments, **props)
        end

        # --- composite components -------------------------------------------------

        # <badge label="3"><icon name="notifications"/></badge> — badge is a
        # prop on the wrapped control, not a control of its own. The client
        # accepts either a scalar label or a full Badge control (a bare Hash
        # renders as its `toString`, e.g. "{label: 3}"), so build accordingly.
        def build_badge(element, form:)
          children = build_children(element.children, form: form)
          content = children.length == 1 ? children.first : (children.empty? ? nil : column(children, tight: true))
          label = element["label"].to_s
          return text(label) if content.nil?

          styling = element_props(element, except: %w[label])
          content.props["badge"] =
            if styling.empty?
              label
            else
              badge(label, **styling)
            end
          content
        end

        # <tooltip message="Explanation"><icon name="help"/></tooltip>
        def build_tooltip(element, form:)
          children = build_children(element.children, form: form)
          content = children.length == 1 ? children.first : column(children, tight: true)
          return nil if content.nil?

          content.props["tooltip"] = (element["message"] || element["text"]).to_s
          content
        end

        # <list-tile title="Inbox" subtitle="12 unread" leading="mail" href="/inbox">
        def build_list_tile(element)
          props = element_props(element, except: %w[title subtitle leading trailing icon])
          props[:title] = element["title"] if element["title"]
          props[:subtitle] = element["subtitle"] if element["subtitle"]
          leading = element["leading"] || element["icon"]
          props[:leading] = leading if leading
          props[:trailing] = element["trailing"] if element["trailing"]
          handler =
            if element["on-click"]
              action_handler(element["on-click"])
            elsif element["href"]
              navigation_handler(element["href"], element["nav"] || "push")
            end
          props[:on_click] = handler if handler
          list_tile(**props)
        end

        # <expansion-tile title="Details" subtitle="...">children…</expansion-tile>
        def build_expansion_tile(element, form:)
          children = build_children(element.children, form: form)
          props = element_props(element, except: %w[title subtitle leading icon])
          props[:title] = element["title"].to_s
          props[:subtitle] = element["subtitle"] if element["subtitle"]
          leading = element["leading"] || element["icon"]
          props[:leading] = leading if leading
          expansion_tile(children, **props)
        end

        # <tabs><tab label="One" icon="home">…</tab><tab label="Two">…</tab></tabs>
        # The client's Tabs is a controller: it hosts a TabBar plus a
        # TabBarView with one pane per tab.
        def build_tabs(element, styles, form:)
          tab_elements = element.elements.select { |child| child.tag == "tab" }
          return nil if tab_elements.empty?

          labels = tab_elements.map do |tab_element|
            props = {}
            props[:icon] = tab_element["icon"] if tab_element["icon"]
            tab(tab_element["label"].to_s, **props)
          end
          panes = tab_elements.map do |tab_element|
            column(build_children(tab_element.children, form: form), spacing: 0, scroll: "auto")
          end
          props = element_props(element)
          props[:expand] = true unless props.key?(:expand)
          props[:expand] = true if styles[:expand]
          tabs(
            column([tab_bar(labels), tab_bar_view(panes, expand: true)], spacing: 0, expand: true),
            length: tab_elements.length,
            **props
          )
        end

        # Plain HTML tables become native DataTables:
        # <table><thead><tr><th>…</th></tr></thead><tbody><tr><td>…</td></tr></tbody></table>
        def build_table(element, form:)
          rows = collect_table_rows(element)
          header = rows.find { |tr| tr.elements.any? { |cell| cell.tag == "th" } }
          body_rows = rows - [header]

          columns = table_cells(header).map { |th| data_column(text(th.text, weight: "w600")) }
          if columns.empty? && body_rows.any?
            columns = Array.new(table_cells(body_rows.first).length) { data_column(text("")) }
          end

          data_rows = body_rows.map do |tr|
            cells = table_cells(tr).map { |td| data_cell(table_cell_content(td, form: form)) }
            data_row(cells)
          end
          data_table(columns, rows: data_rows, **element_props(element))
        end

        def collect_table_rows(element)
          element.elements.flat_map do |child|
            case child.tag
            when "tr" then [child]
            when "thead", "tbody", "tfoot" then child.elements.select { |tr| tr.tag == "tr" }
            else []
            end
          end
        end

        def table_cells(tr)
          return [] unless tr

          tr.elements.select { |cell| %w[th td].include?(cell.tag) }
        end

        def table_cell_content(cell, form:)
          children = build_children(cell.children, form: form)
          case children.length
          when 0 then text("")
          when 1 then children.first
          else row(children, spacing: 6)
          end
        end

        # <chip label="Ruby"> or <chip>Ruby</chip> — Chip needs `label`, and
        # a bare `on-click` becomes its native click action.
        def build_chip(element)
          props = element_props(element, except: %w[label icon])
          props[:label] = element["label"] || collapse_whitespace(element.text)
          props[:leading] = element["icon"] if element["icon"]
          if element["on-click"]
            props[:on_click] = action_handler(element["on-click"])
          elsif element["href"]
            props[:on_click] = navigation_handler(element["href"], element["nav"] || "push")
          end
          chip(**props)
        end

        # <avatar src="/me.png"> or <avatar class="bg-violet-500">AM</avatar>
        def build_avatar(element)
          styles = Styles.parse(element["class"])
          props = element_props(element, except: %w[src alt])
          props[:foreground_image_src] = resolve_asset_url(element["src"]) if element["src"]
          props[:bgcolor] = styles[:bgcolor] if styles[:bgcolor]
          initials = collapse_whitespace(element.text)
          content = initials.empty? ? nil : text(initials, color: styles[:color] || "#ffffff", weight: "bold")
          circle_avatar(content, **props)
        end

        # <fab icon="add" href="/items/new"> — mounts as the screen's
        # FloatingActionButton, like <appbar>.
        def extract_fab(element)
          props = element_props(element, except: %w[icon label])
          props[:icon] = element["icon"] if element["icon"]
          label = element["label"] || collapse_whitespace(element.text)
          props[:content] = text(label) unless label.to_s.empty?
          handler =
            if element["on-click"]
              action_handler(element["on-click"])
            elsif element["href"]
              navigation_handler(element["href"], element["nav"] || "push")
            end
          props[:on_click] = handler if handler
          @result.fab = floating_action_button(**props)
          nil
        end

        # <bottom-nav>
        #   <nav-item icon="chat" label="Chats" href="/chats" selected></nav-item>
        #   <nav-item icon="call" label="Calls" href="/calls"></nav-item>
        # </bottom-nav>
        # Mounts as the screen's NavigationBar; a destination tap resets to that
        # URL as a new root (tab semantics), like the WebView shell's bottomnav.
        def extract_bottom_nav(element)
          items = element.elements.select { |el| el.tag == "nav-item" }
          return nil if items.length < 2

          destinations = items.filter_map do |item|
            icon = item["icon"].to_s
            next if icon.empty?

            navigation_bar_destination(icon: icon, label: item["label"].to_s)
          end
          return nil if destinations.length < 2

          urls = items.map { |item| item["href"].to_s }
          handlers = @handlers
          @result.bottom_nav = navigation_bar(
            destinations: destinations,
            selected_index: items.index { |item| item.key?("selected") } || 0,
            on_change: lambda do |event|
              url = urls[nav_event_index(event)].to_s
              handlers.navigate(url, "root") unless url.empty?
            end
          )
          nil
        end

        def nav_event_index(event)
          data = event.respond_to?(:data) ? event.data : event
          return (data["selected_index"] || data["value"] || data["i"] || 0).to_i if data.is_a?(Hash)

          data.to_i
        end

        # A non-visual platform service (`<camera>`, `<geolocator>`, `<battery>`,
        # …). It mounts on the page's service registry instead of the visible
        # tree, so it registers with the client without rendering anything.
        # Streaming sensors emit continuously. With no `interval` the client
        # pushes readings at the device's native rate — tens to hundreds per
        # second — and each one round-trips a status update, flooding the wire
        # and making the screen janky. Default to Studio's calm 200ms cadence
        # unless the author sets their own.
        STREAMING_SENSORS = %w[
          accelerometer gyroscope magnetometer barometer useraccelerometer
        ].to_set.freeze
        SENSOR_DEFAULT_INTERVAL = 200

        def extract_service(element)
          type = element.tag.tr("-", "_")
          props = element_props(element)
          props[:interval] ||= SENSOR_DEFAULT_INTERVAL if STREAMING_SENSORS.include?(type.delete("_"))
          attach_declared_events(element, props, registry_props(type))
          service = Ruflet::UI::ControlFactory.build(type, **props)
          @result.services << service
          nil
        end

        # --- generic control passthrough ----------------------------------------

        # Any tag without a dedicated builder maps straight onto the ruflet_core
        # control registry, so the whole Ruflet catalog is reachable from
        # markup. Text and child controls are routed into whichever prop the
        # control's schema actually accepts (content / controls / label /
        # title), instead of blindly assuming `value` — most controls have no
        # `value`, and a wrong prop would fail strict-schema validation.
        TEXT_SLOTS = %w[content label title text message value].freeze

        # Chart controls carry their data in named props, not `content`/`controls`.
        # Nested chart tags (`<bar-chart-group>`, `<line-chart-data>`, …) build the
        # matching control, and this maps each one into the slot its parent expects
        # — so a whole chart can be authored as plain nested HTML.
        CHART_SLOT_FOR_CHILD = {
          "barchartgroup" => :groups,
          "barchartrod" => :rods,
          "barchartrodstackitem" => :rod_stack_items,
          "linechartdata" => :data_series,
          "linechartdatapoint" => :points,
          "piechartsection" => :sections,
          "candlestickchartspot" => :spots,
          "scatterchartspot" => :spots,
          "radardataset" => :data_sets,
          "radardatasetentry" => :entries,
          "radarcharttitle" => :titles,
          "chartaxislabel" => :labels
        }.freeze

        # Extension controls whose nested controls live in a named collection.
        # These cannot use the generic `children` array because their Flutter
        # renderers explicitly read the named property (Map reads `layers`,
        # MarkerLayer reads `markers`, and so on).
        CHILD_SLOT_FOR_PARENT = {
          "map" => :layers,
          "marker_layer" => :markers,
          "markerlayer" => :markers,
          "circle_layer" => :circles,
          "circlelayer" => :circles,
          "polyline_layer" => :polylines,
          "polylinelayer" => :polylines,
          "polygon_layer" => :polygons,
          "polygonlayer" => :polygons
        }.freeze

        # Chart controls have no `expand` and don't inherit their parent's box:
        # a chart with no width/height renders as an empty (zero-size) widget.
        # Studio always sizes charts explicitly; default to studio-typical dims
        # so a chart authored without them still shows. Authors can override.
        CHART_TYPES = %w[
          barchart linechart piechart scatterchart candlestickchart radarchart
        ].to_set.freeze
        CHART_DEFAULT_WIDTH = 320
        CHART_DEFAULT_HEIGHT = 240

        # Map controls that wrap a single child in `content` (not the generic
        # `controls` list): a Marker holds one icon/widget, the way Studio's
        # `marker(content: icon(...))` does.
        CONTENT_CHILD_TYPES = %w[marker].to_set.freeze

        # Props that hold a `[lat, lng]` pair. Studio's `marker`/`circle_marker`/
        # `map` builders normalise these to `{latitude:, longitude:}`; the Map
        # control constructor does it for `initial_center` but the layer controls
        # don't, so a raw array reaches the client and the marker never places.
        # Normalise them here so every map control gets Studio's wire shape.
        MAP_COORDINATE_PROPS = %i[coordinates initial_center center].freeze

        def build_generic(element, form:)
          type = element.tag.tr("-", "_")
          allowed = registry_props(type)
          props = element_props(element).merge(schema_style_props(element, type))
          apply_chart_defaults(type, props)
          normalize_map_coordinates(props)
          attach_declared_events(element, props, allowed)
          child_elements = element.elements

          if child_elements.empty?
            assign_text_content(props, allowed, collapse_whitespace(element.text))
            return Ruflet::UI::ControlFactory.build(type, **props)
          end

          children = build_children(element.children, form: form)
          if CONTENT_CHILD_TYPES.include?(type)
            props[:content] = children.length == 1 ? children.first : column(children)
            return Ruflet::UI::ControlFactory.build(type, **props)
          end
          if (slot = CHILD_SLOT_FOR_PARENT[type])
            props[slot] = children
            return Ruflet::UI::ControlFactory.build(type, **props)
          end
          slotted = chart_slots(children)
          unless slotted.empty?
            slotted.each { |slot, controls| props[slot] = controls }
            return Ruflet::UI::ControlFactory.build(type, **props)
          end
          assign_child_content(type, props, allowed, children)
        end

        # Translate extension callbacks from ERB attributes into native event
        # handlers. This is the HTML equivalent of Studio's Ruby lambdas.
        # Example: on-tap-target="map-status" on-tap-prefix="Map tap: ".
        def attach_declared_events(element, props, allowed)
          event_names = element.attrs.keys.filter_map do |attribute|
            match = attribute.match(/\Aon-(.+)-(?:target|service)\z/)
            match && match[1]
          end.uniq

          event_names.each do |event_name|
            prop_name = "on_#{event_name.tr('-', '_')}"
            next if allowed && !allowed.include?(prop_name)

            prefix = "on-#{event_name}-"
            spec = {
              "target" => element["#{prefix}target"],
              "message" => element["#{prefix}message"],
              "prefix" => element["#{prefix}prefix"],
              "control" => element["#{prefix}control"],
              "property" => element["#{prefix}property"],
              # An event can re-run a whole service (Studio's battery refreshes on
              # every `on_state_change`), reporting into `result-target`.
              "service" => element["#{prefix}service"],
              "result-target" => element["#{prefix}result-target"] || element["#{prefix}target"]
            }.compact
            handlers = @handlers
            props[prop_name.to_sym] = ->(event) { handlers.control_event(spec, event) }
          end
        end

        def apply_chart_defaults(type, props)
          return unless CHART_TYPES.include?(type.delete("_"))

          props[:width] ||= CHART_DEFAULT_WIDTH
          props[:height] ||= CHART_DEFAULT_HEIGHT
        end

        def normalize_map_coordinates(props)
          MAP_COORDINATE_PROPS.each do |key|
            props[key] = map_coordinate(props[key]) if props.key?(key)
          end
        end

        # Mirror ruflet_core's `map_coordinates`: accept `[lat, lng]` or a hash
        # with lat/lng-ish keys and emit the `{latitude:, longitude:}` shape the
        # client's flutter_map layers expect.
        def map_coordinate(value)
          case value
          when Array
            value.length >= 2 ? { "latitude" => value[0], "longitude" => value[1] } : value
          when Hash
            lat = value["latitude"] || value[:latitude] || value["lat"] || value[:lat]
            lng = value["longitude"] || value[:longitude] || value["lng"] ||
                  value[:lng] || value["lon"] || value[:lon]
            lat.nil? || lng.nil? ? value : { "latitude" => lat, "longitude" => lng }
          else
            value
          end
        end

        # Group chart-primitive children by the named prop their parent reads them
        # from. Returns {} when none are chart primitives, so non-chart controls
        # fall through to the usual content/controls routing.
        def chart_slots(children)
          children.each_with_object({}) do |child, slots|
            next unless child.is_a?(Ruflet::Control)

            slot = CHART_SLOT_FOR_CHILD[child.type]
            (slots[slot] ||= []) << child if slot
          end
        end

        # Route leaf text into the best available string/content slot.
        def assign_text_content(props, allowed, value)
          return if value.empty? || props.key?(:value)

          if allowed.nil? || allowed.include?("content")
            props[:content] = text(value)
          elsif (slot = (TEXT_SLOTS & allowed.to_a).first)
            props[slot.to_sym] = value
          elsif allowed.include?("controls")
            props[:controls] = [text(value)]
          end
        end

        # Route child controls into `controls` (list-like) or `content`
        # (single-child) depending on what the control accepts.
        def assign_child_content(type, props, allowed, children)
          if allowed.nil?
            control = Ruflet::UI::ControlFactory.build(type, **props)
            children.each { |child| control.children << child }
            return control
          end

          list_slot = allowed.include?("controls")
          content_slot = allowed.include?("content")
          if list_slot && !(children.length == 1 && content_slot)
            props[:controls] = children
          elsif content_slot
            props[:content] = children.length == 1 ? children.first : column(children)
          elsif list_slot
            props[:controls] = children
          elsif allowed.include?("children")
            props[:children] = children
          else
            control = Ruflet::UI::ControlFactory.build(type, **props)
            children.each { |child| control.children << child }
            return control
          end
          Ruflet::UI::ControlFactory.build(type, **props)
        end

        # Allowed property names for a registry type, or nil when the control
        # uses a non-strict schema (attach children directly). Mirrors how
        # Ruflet::Control derives its schema, without touching ruflet_core.
        def registry_props(type)
          @registry_props_cache ||= {}
          return @registry_props_cache[type] if @registry_props_cache.key?(type)

          klass = Ruflet::UI::ControlFactory::CLASS_MAP[type]
          names =
            if klass.nil?
              []
            elsif klass.const_defined?(:KEYWORDS)
              klass::KEYWORDS
            else
              params = klass.instance_method(:initialize).parameters.select { |kind, _| %i[key keyreq].include?(kind) }
              params.any? { |_, name| name.nil? } ? [] : params.map { |_, name| name }
            end
          set = names.empty? ? nil : names.map(&:to_s).to_set
          @registry_props_cache[type] = set
        end

        # --- appbar ---------------------------------------------------------------

        # `<appbar title="Inbox" leading-icon="menu">` with optional
        # `<action icon="search" href="/search"/>` children becomes the native
        # AppBar of the screen.
        def extract_appbar(element)
          actions = element.elements.select { |child| child.tag == "action" }.filter_map do |action|
            next if action["icon"].to_s.empty?

            icon_button(action["icon"], on_click: appbar_action_handler(action))
          end

          leading = nil
          leading_icon = element["leading-icon"]
          if leading_icon
            leading_mode = element["leading-nav"] || "back"
            leading = icon_button(leading_icon, on_click: navigation_handler(element["leading-href"].to_s,
                                                                             leading_mode))
          end

          args = {}
          args[:title] = text(element["title"].to_s)
          if leading
            args[:leading] = leading
            args[:automatically_imply_leading] = false
          end
          args[:actions] = actions unless actions.empty?
          args[:bgcolor] = Styles.color_for(element["bgcolor"]) || element["bgcolor"] if element["bgcolor"]
          @result.appbar = appbar(**args)
          nil
        end

        def appbar_action_handler(action)
          if action["on-click"]
            action_handler(action["on-click"])
          else
            navigation_handler(action["href"].to_s, action["nav"] || "push")
          end
        end

        # --- events / handlers ----------------------------------------------------

        def navigation_handler(url, mode)
          handlers = @handlers
          ->(_event) { handlers.navigate(url, mode) }
        end

        # `on-click="post:/counter/increment"`, `on-click="/refresh"` (POST by
        # default), `on-click="get:/search"`.
        # An on-click names the screen path whose method to run. It used to
        # carry an HTTP verb ("post:/x"); nothing dispatches a request now, so
        # a leading verb is stripped rather than obeyed.
        def action_handler(spec)
          url = spec.to_s.sub(%r{\A(?:get|post|put|patch|delete):}i, "")
          handlers = @handlers
          ->(_event) { handlers.action(url: url) }
        end

        def submit_handler(form)
          handlers = @handlers
          ->(_event) { handlers.submit_form(form) }
        end

        def field_handler(name)
          return nil if name.to_s.empty?

          handlers = @handlers
          ->(event) { handlers.field_changed(name, event_value(event)) }
        end

        def register_field(form, name, initial)
          return if name.to_s.empty?

          form[:fields][name] = initial if form
          @handlers.field_changed(name, initial) if @handlers.respond_to?(:field_changed)
        end


        def event_value(event)
          data = event.respond_to?(:data) ? event.data : event
          # Not `||`: a switch reports value `false`, which `||` would discard.
          if data.is_a?(Hash)
            return data["value"] if data.key?("value")
            return data[:value] if data.key?(:value)
          end
          data
        end

        # Generic `on-click` on non-interactive elements gets a tap wrapper.
        def finalize(control, element)
          spec = element["on-click"] || element["on-tap"]
          return control unless spec
          return control if SELF_CLICKING_TAGS.include?(element.tag)

          gesture_detector(content: control, on_tap: action_handler(spec))
        end

        # --- props & styling -------------------------------------------------------

        # Remaining element attributes become control props: kebab-case turns
        # into snake_case, values parse as JSON scalars/structures when they
        # look like one.
        def element_props(element, except: [])
          skip = RESERVED_ATTRIBUTES + except
          element.attrs.each_with_object({}) do |(name, value), props|
            next if skip.include?(name) || HTML_NOISE_ATTRIBUTES.include?(name)
            next if name.start_with?("on-", "data-", "aria-")
            # Browser JS handlers (onclick, onchange, ...) are not DSL events.
            next if name.match?(/\Aon[a-z]+\z/)

            value = resolve_asset_url(value) if name.match?(ASSET_URL_ATTRIBUTE)
            props[name.tr("-", "_").to_sym] = coerce_value(value)
          end
        end

        # Style-derived props (from `class`) that a given control actually
        # accepts. Lets non-container controls — list/grid/inputs/buttons — pick
        # up `flex-1`, `w-64`, `p-3`, `gap-2`, `bg-*`, etc. (element_props only
        # forwards raw attributes, never the parsed class).
        def schema_style_props(element, type)
          styles = Styles.parse(element["class"])
          return {} if styles.empty?

          allowed = registry_props(type)
          styles.slice(*SCHEMA_STYLE_KEYS).select { |key, _| allowed.nil? || allowed.include?(key.to_s) }
        end

        # element_props plus the schema-valid style props for `type`.
        def control_props(element, type, except: [])
          element_props(element, except: except).merge(schema_style_props(element, type))
        end

        def coerce_value(value)
          case value
          when "true", "" then true
          when "false" then false
          when /\A-?\d+\z/ then value.to_i
          when /\A-?\d+\.\d+\z/ then value.to_f
          when /\A[\[{]/
            begin
              JSON.parse(value)
            rescue JSON::ParserError
              value
            end
          else
            value
          end
        end

        def flex_props(styles, axis: "column")
          props = {}
          props[:spacing] = styles[:spacing] if styles[:spacing]
          props[:run_spacing] = styles[:run_spacing] if styles[:run_spacing]
          props[:scroll] = styles[:scroll] if styles[:scroll]
          props[:expand] = true if styles[:expand]
          props[:wrap] = true if styles[:wrap]
          if styles[:main_alignment]
            props[:alignment] = styles[:main_alignment]
          end
          if styles[:cross_alignment]
            key = axis == "row" ? :vertical_alignment : :horizontal_alignment
            props[key] = styles[:cross_alignment]
          end
          props
        end

        def box_props(styles)
          props = styles.slice(*BOX_STYLE_KEYS)
          props[:expand] = true if styles[:expand]
          props
        end

        # Text/flex controls carry no box styling of their own; give them a
        # container wrapper when the class list asks for one.
        def wrap_in_box(control, styles)
          boxed = box_props(styles)
          boxed.delete(:expand)
          return control if boxed.empty?

          boxed[:expand] = true if styles[:expand]
          container(content: control, **boxed)
        end

        def collapse_whitespace(text)
          text.to_s.gsub(/\s+/, " ").strip
        end
      end
    end
  end
end

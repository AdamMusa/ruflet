# frozen_string_literal: true

require_relative "event"
require "ruby_native_protocol"
require_relative "control"
require_relative "ui/control_methods"
require_relative "ui/widget_builder"
require_relative "icons/material_icon_lookup"
require_relative "icons/cupertino_icon_lookup"
require "set"
require "cgi"

module RubyNative
  class Page
    include UI::ControlMethods

    PAGE_PROP_KEYS = %w[route title vertical_alignment horizontal_alignment].freeze

    attr_reader :session_id, :client_details, :views

    def initialize(session_id:, client_details:, sender:)
      @session_id = session_id
      @client_details = client_details
      @sender = sender
      @control_index = {}
      @wire_index = {}
      @next_wire_id = 100
      @view_id = 20
      @root_controls = []
      @views = []
      @page_event_handlers = {}
      @view_props = {}
      @page_props = { "route" => (client_details["route"] || "/") }
    end

    def set_view_props(props)
      split_props(normalize_props(props || {}))
      self
    end

    def title
      @page_props["title"]
    end

    def title=(value)
      @page_props["title"] = value
    end

    def route
      @page_props["route"]
    end

    def route=(value)
      @page_props["route"] = value
    end

    def vertical_alignment
      @page_props["vertical_alignment"] || @view_props["vertical_alignment"]
    end

    def vertical_alignment=(value)
      v = normalize_value("vertical_alignment", value)
      @page_props["vertical_alignment"] = v
      @view_props["vertical_alignment"] = v
    end

    def horizontal_alignment
      @page_props["horizontal_alignment"] || @view_props["horizontal_alignment"]
    end

    def horizontal_alignment=(value)
      v = normalize_value("horizontal_alignment", value)
      @page_props["horizontal_alignment"] = v
      @view_props["horizontal_alignment"] = v
    end

    def bgcolor
      @view_props["bgcolor"]
    end

    def bgcolor=(value)
      @view_props["bgcolor"] = normalize_value("bgcolor", value)
    end

    def add(*controls, appbar: nil, floating_action_button: nil, navigation_bar: nil, dialog: nil, snack_bar: nil, bottom_sheet: nil)
      controls = controls.flatten
      visited = Set.new
      controls.each { |c| register_control_tree(c, visited) }
      @root_controls = controls
      @view_props["appbar"] = appbar if appbar
      @view_props["floating_action_button"] = floating_action_button if floating_action_button
      @view_props["navigation_bar"] = navigation_bar if navigation_bar
      @view_props["dialog"] = dialog if dialog
      @view_props["snack_bar"] = snack_bar if snack_bar
      @view_props["bottom_sheet"] = bottom_sheet if bottom_sheet
      @view_props.each_value { |value| register_embedded_value(value, visited) }

      send_view_patch

      self
    end

    def views=(value)
      @views = Array(value).compact
      self
    end

    def go(route, **query_params)
      @page_props["route"] = build_route(route, query_params)
      dispatch_page_event(name: "route_change", data: @page_props["route"])
      send_view_patch
      self
    end

    def on_route_change=(handler)
      @page_event_handlers["route_change"] = handler
    end

    def on_view_pop=(handler)
      @page_event_handlers["view_pop"] = handler
    end

    def on(event_name, &block)
      @page_event_handlers[event_name.to_s.sub(/\Aon_/, "")] = block
      self
    end

    def mount(&block)
      builder = WidgetBuilder.new
      builder.instance_eval(&block)
      add(*builder.children)
    end

    def appbar(**props, &block)
      return @view_props["appbar"] if props.empty? && !block

      WidgetBuilder.new.appbar(**props, &block)
    end

    def appbar=(value)
      @view_props["appbar"] = value
    end

    def floating_action_button(**props, &block)
      return @view_props["floating_action_button"] if props.empty? && !block

      WidgetBuilder.new.floating_action_button(**props, &block)
    end

    def floating_action_button=(value)
      @view_props["floating_action_button"] = value
    end

    def dialog
      @view_props["dialog"]
    end

    def dialog=(value)
      @view_props["dialog"] = value
    end

    def snack_bar
      @view_props["snack_bar"]
    end

    def snack_bar=(value)
      @view_props["snack_bar"] = value
    end

    def snackbar
      snack_bar
    end

    def snackbar=(value)
      self.snack_bar = value
    end

    def bottom_sheet
      @view_props["bottom_sheet"]
    end

    def bottom_sheet=(value)
      @view_props["bottom_sheet"] = value
    end

    def bottomsheet
      bottom_sheet
    end

    def bottomsheet=(value)
      self.bottom_sheet = value
    end

    def update(control_or_id = nil, **props)
      if control_or_id.nil? && props.empty?
        send_view_patch
        return self
      end

      if page_control_target?(control_or_id)
        split_props(normalize_props(props))
        send_view_patch
        return self
      end

      control = resolve_control(control_or_id)
      return self unless control

      patch = normalize_props(props)
      if %w[button elevatedbutton textbutton filledbutton].include?(control.type) && patch.key?("text")
        patch["content"] = patch.delete("text")
      end

      patch_ops = patch.map { |k, v| [0, 0, k, v] }

      send_message(Protocol::ACTIONS[:patch_control], {
        "id" => control.wire_id,
        "patch" => [[0], *patch_ops]
      })

      self
    end

    def patch_page(control_id, **props)
      update(control_id, **props)
    end

    def dispatch_event(target:, name:, data:)
      if page_control_target?(target)
        if name.to_s == "route_change"
          route_from_event = extract_route(data)
          @page_props["route"] = route_from_event if route_from_event
        end
        dispatch_page_event(name: name, data: data)
        return
      end

      control = @wire_index[target.to_i] || @control_index[target.to_s]
      return unless control

      event = Event.new(name: name, target: target, raw_data: data, page: self, control: control)
      control.emit(name, event)
    end

    private

    def build_widget(type, **props, &block) = WidgetBuilder.new.control(type, **props, &block)

    def split_props(props)
      props.each do |k, v|
        if k == "vertical_alignment" || k == "horizontal_alignment"
          @page_props[k] = v
          @view_props[k] = v
        elsif PAGE_PROP_KEYS.include?(k)
          @page_props[k] = v
        else
          @view_props[k] = v
        end
      end
    end

    def send_message(action, payload)
      @sender.call(action, payload)
    end

    def send_view_patch
      refresh_control_indexes!
      view_patches = if @views.any?
                       @views.map(&:to_patch)
                     else
                       [implicit_view_patch]
                     end

      send_message(Protocol::ACTIONS[:patch_control], {
        "id" => 1,
        "patch" => [
          [0],
          [0, 0, "views", view_patches]
        ]
      })

      send_page_props_patch
    end

    def send_page_props_patch
      page_patch_ops = @page_props.map { |k, v| [0, 0, k, v] }
      return if page_patch_ops.empty?

      send_message(Protocol::ACTIONS[:patch_control], {
        "id" => 1,
        "patch" => [[0], *page_patch_ops]
      })
    end

    def register_control_tree(control, visited = Set.new)
      return unless control
      return if visited.include?(control.object_id)

      visited << control.object_id
      assign_wire_id(control)
      control.runtime_page = self if control.respond_to?(:runtime_page=)
      @control_index[control.id.to_s] = control
      @wire_index[control.wire_id] = control
      control.children.each { |child| register_control_tree(child, visited) }
      control.props.each_value { |value| register_embedded_value(value, visited) }
    end

    def implicit_view_patch
      view_patch = {
        "_c" => "View",
        "_i" => @view_id,
        "route" => (@page_props["route"] || @client_details["route"] || "/"),
        # Required by Flet layout engine so children with `expand` inside View
        # are wrapped with Expanded/Flexible on the Flutter side.
        "_internals" => { "host_expanded" => true }
      }
      @view_props.each { |k, v| view_patch[k] = serialize_patch_value(v) }
      view_patch["controls"] = @root_controls.map(&:to_patch)
      view_patch
    end

    def refresh_control_indexes!
      @control_index.clear
      @wire_index.clear
      visited = Set.new

      if @views.any?
        @views.each { |view| register_control_tree(view, visited) }
      else
        @root_controls.each { |control| register_control_tree(control, visited) }
        @view_props.each_value { |value| register_embedded_value(value, visited) }
      end
    end

    def register_embedded_value(value, visited)
      case value
      when Control
        register_control_tree(value, visited)
      when Array
        value.each { |v| register_embedded_value(v, visited) }
      when Hash
        value.each_value { |v| register_embedded_value(v, visited) }
      end
    end

    def assign_wire_id(control)
      return if control.wire_id

      control.wire_id = @next_wire_id
      @next_wire_id += 1
    end

    def resolve_control(control_or_id)
      if control_or_id.respond_to?(:wire_id)
        control_or_id
      elsif control_or_id.to_s.match?(/^\d+$/)
        @wire_index[control_or_id.to_i]
      else
        @control_index[control_or_id.to_s]
      end
    end

    def normalize_props(hash)
      hash.each_with_object({}) do |(k, v), result|
        key = k.to_s
        result[key] = normalize_value(key, v)
      end
    end

    def normalize_value(key, value)
      if icon_prop_key?(key) && (value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Integer))
        codepoint = RubyNative::MaterialIconLookup.codepoint_for(value)
        codepoint = RubyNative::CupertinoIconLookup.codepoint_for(value) if codepoint.nil? || codepoint == value
        return codepoint unless codepoint.nil?
      end

      return value.value if value.is_a?(RubyNative::IconData)
      value.is_a?(Symbol) ? value.to_s : value
    end

    def build_route(route, query_params = {})
      base = route.to_s
      return base if query_params.nil? || query_params.empty?

      query = query_params.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join("&")
      separator = base.include?("?") ? "&" : "?"
      "#{base}#{separator}#{query}"
    end

    def extract_route(data)
      case data
      when String
        data
      when Hash
        data["route"] || data[:route]
      else
        nil
      end
    end

    def dispatch_page_event(name:, data:)
      handler = @page_event_handlers[name.to_s.sub(/\Aon_/, "")]
      return unless handler.respond_to?(:call)

      event = Event.new(name: name.to_s, target: 1, raw_data: data, page: self, control: nil)
      handler.call(event)
    end

    def page_control_target?(control_or_id)
      control_or_id == 1 || control_or_id.to_s == "1" || control_or_id.to_s == "page"
    end

    def serialize_patch_value(value)
      case value
      when Control
        value.to_patch
      when RubyNative::IconData
        value.value
      when Array
        value.map { |v| serialize_patch_value(v) }
      when Hash
        value.transform_values { |v| serialize_patch_value(v) }
      else
        value
      end
    end

    def icon_prop_key?(key)
      key == "icon" || key.end_with?("_icon")
    end
  end
end

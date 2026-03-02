# RUFLET_RUNTIME_ZIP_V1
# -- MRuby module_function shim (override to support no-arg form)
class Module
  if method_defined?(:module_function) || private_method_defined?(:module_function)
    alias __ruflet_orig_module_function module_function
  end

  def module_function(*names)
    if names.empty?
      @__ruflet_module_function__ = true
      return
    end
    begin
      __ruflet_orig_module_function(*names) if defined?(__ruflet_orig_module_function)
    rescue StandardError
      nil
    end
    names.each do |name|
      begin
        define_singleton_method(name, instance_method(name))
        private name
      rescue StandardError
        nil
      end
    end
  end

  def method_added(name)
    if @__ruflet_module_function__
      begin
        define_singleton_method(name, instance_method(name))
        private name
      rescue StandardError
        nil
      end
    end
    super if defined?(super)
  end
end

# -- MRuby compatibility: provide Module#constant_prefix_for if missing
class Module
  unless method_defined?(:constant_prefix_for) || private_method_defined?(:constant_prefix_for)
    def constant_prefix_for(base_name)
      base_name.to_s.upcase
    end
    private :constant_prefix_for
  end
end

# -- packages/ruflet/lib/ruflet_protocol/ruflet/protocol.rb

module Ruflet
  module Protocol
    ACTIONS = {
      register_client: 1,
      patch_control: 2,
      control_event: 3,
      update_control: 4,
      invoke_control_method: 5,
      session_crashed: 6,

      # Legacy JSON protocol aliases kept for compatibility.
      register_web_client: "registerWebClient",
      page_event_from_web: "pageEventFromWeb",
      update_control_props: "updateControlProps"
    }.freeze

    module_function

    def pack_message(action:, payload:)
      [action, payload]
    end

    def normalize_register_payload(payload)
      page = payload["page"] || {}
      {
        "session_id" => payload["session_id"],
        "page_name" => payload["page_name"] || "",
        "route" => page["route"] || "/",
        "width" => page["width"],
        "height" => page["height"],
        "platform" => page["platform"],
        "platform_brightness" => page["platform_brightness"],
        "media" => page["media"] || {}
      }
    end

    def normalize_control_event_payload(payload)
      {
        "target" => payload["target"] || payload["eventTarget"],
        "name" => payload["name"] || payload["eventName"],
        "data" => payload["data"] || payload["eventData"]
      }
    end

    def normalize_update_control_payload(payload)
      {
        "id" => payload["id"] || payload["target"] || payload["eventTarget"],
        "props" => payload["props"].is_a?(Hash) ? payload["props"] : {}
      }
    end

    def register_response(session_id:)
      {
        "session_id" => session_id,
        "page_patch" => {},
        "error" => nil
      }
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/colors.rb

module Ruflet
  module Colors
    SEMANTIC_COLORS = {
      PRIMARY: "primary",
      ON_PRIMARY: "onprimary",
      PRIMARY_CONTAINER: "primarycontainer",
      ON_PRIMARY_CONTAINER: "onprimarycontainer",
      PRIMARY_FIXED: "primaryfixed",
      PRIMARY_FIXED_DIM: "primaryfixeddim",
      ON_PRIMARY_FIXED: "onprimaryfixed",
      ON_PRIMARY_FIXED_VARIANT: "onprimaryfixedvariant",
      SECONDARY: "secondary",
      ON_SECONDARY: "onsecondary",
      SECONDARY_CONTAINER: "secondarycontainer",
      ON_SECONDARY_CONTAINER: "onsecondarycontainer",
      SECONDARY_FIXED: "secondaryfixed",
      SECONDARY_FIXED_DIM: "secondaryfixeddim",
      ON_SECONDARY_FIXED: "onsecondaryfixed",
      ON_SECONDARY_FIXED_VARIANT: "onsecondaryfixedvariant",
      TERTIARY: "tertiary",
      ON_TERTIARY: "ontertiary",
      TERTIARY_CONTAINER: "tertiarycontainer",
      ON_TERTIARY_CONTAINER: "ontertiarycontainer",
      TERTIARY_FIXED: "tertiaryfixed",
      TERTIARY_FIXED_DIM: "tertiaryfixeddim",
      ON_TERTIARY_FIXED: "ontertiaryfixed",
      ON_TERTIARY_FIXED_VARIANT: "ontertiaryfixedvariant",
      ERROR: "error",
      ON_ERROR: "onerror",
      ERROR_CONTAINER: "errorcontainer",
      ON_ERROR_CONTAINER: "onerrorcontainer",
      SURFACE: "surface",
      ON_SURFACE: "onsurface",
      ON_SURFACE_VARIANT: "onsurfacevariant",
      SURFACE_TINT: "surfacetint",
      SURFACE_DIM: "surfacedim",
      SURFACE_BRIGHT: "surfacebright",
      SURFACE_CONTAINER: "surfacecontainer",
      SURFACE_CONTAINER_LOW: "surfacecontainerlow",
      SURFACE_CONTAINER_LOWEST: "surfacecontainerlowest",
      SURFACE_CONTAINER_HIGH: "surfacecontainerhigh",
      SURFACE_CONTAINER_HIGHEST: "surfacecontainerhighest",
      OUTLINE: "outline",
      OUTLINE_VARIANT: "outlinevariant",
      SHADOW: "shadow",
      SCRIM: "scrim",
      INVERSE_SURFACE: "inversesurface",
      ON_INVERSE_SURFACE: "oninversesurface",
      INVERSE_PRIMARY: "inverseprimary"
    }.freeze

    BASE_PRIMARY = %w[
      amber blue bluegrey brown cyan deeporange deeppurple green grey indigo lightblue
      lightgreen lime orange pink purple red teal yellow
    ].freeze
    BASE_ACCENT = %w[
      amber blue cyan deeporange deeppurple green indigo lightblue lightgreen lime
      orange pink purple red teal yellow
    ].freeze
    PRIMARY_SHADES = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900].freeze
    ACCENT_SHADES = [100, 200, 400, 700].freeze

    FIXED_COLORS = {
      BLACK: "black",
      BLACK_12: "black12",
      BLACK_26: "black26",
      BLACK_38: "black38",
      BLACK_45: "black45",
      BLACK_54: "black54",
      BLACK_87: "black87",
      WHITE: "white",
      WHITE_10: "white10",
      WHITE_12: "white12",
      WHITE_24: "white24",
      WHITE_30: "white30",
      WHITE_38: "white38",
      WHITE_54: "white54",
      WHITE_60: "white60",
      WHITE_70: "white70",
      TRANSPARENT: "transparent"
    }.freeze

    DEPRECATED_ALIASES = {
      BLACK12: :BLACK_12,
      BLACK26: :BLACK_26,
      BLACK38: :BLACK_38,
      BLACK45: :BLACK_45,
      BLACK54: :BLACK_54,
      BLACK87: :BLACK_87,
      WHITE10: :WHITE_10,
      WHITE12: :WHITE_12,
      WHITE24: :WHITE_24,
      WHITE30: :WHITE_30,
      WHITE38: :WHITE_38,
      WHITE54: :WHITE_54,
      WHITE60: :WHITE_60,
      WHITE70: :WHITE_70
    }.freeze

    def with_opacity(opacity, color)
      value = Float(opacity)
      raise ArgumentError, "opacity must be between 0.0 and 1.0 inclusive, got #{opacity}" unless value.between?(0.0, 1.0)

      "#{normalize_color(color)},#{value}"
    end

    def random(exclude: nil, weights: nil)
      choices = all_values.dup
      excluded = Array(exclude).map { |c| normalize_color(c) }
      choices.reject! { |c| excluded.include?(c) }
      return nil if choices.empty?

      if weights && !weights.empty?
        expanded = choices.flat_map do |color|
          weight = weights.fetch(color, weights.fetch(color.to_sym, 1)).to_i rescue 1
          weight = 1 if weight <= 0
          [color] * weight
        end
        return expanded.sample
      end

      choices.sample
    end

    def all_values
      @all_values ||= constants(false)
                      .map { |c| const_get(c) }
                      .select { |v| v.is_a?(String) }
                      .uniq
                      .freeze
    end

    def self.normalize_color(color)
      return color.to_s if color.is_a?(Symbol)
      return color if color.is_a?(String)
      return color.to_s unless color.respond_to?(:to_s)

      color.to_s
    end

    BASE_PREFIX = {
      "amber" => "AMBER",
      "blue" => "BLUE",
      "bluegrey" => "BLUE_GREY",
      "brown" => "BROWN",
      "cyan" => "CYAN",
      "deeporange" => "DEEP_ORANGE",
      "deeppurple" => "DEEP_PURPLE",
      "green" => "GREEN",
      "grey" => "GREY",
      "indigo" => "INDIGO",
      "lightblue" => "LIGHT_BLUE",
      "lightgreen" => "LIGHT_GREEN",
      "lime" => "LIME",
      "orange" => "ORANGE",
      "pink" => "PINK",
      "purple" => "PURPLE",
      "red" => "RED",
      "teal" => "TEAL",
      "yellow" => "YELLOW"
    }.freeze

    def self.constant_prefix_for(base_name)
      BASE_PREFIX.fetch(base_name) { base_name.upcase }
    end

    SEMANTIC_COLORS.each { |k, v| const_set(k, v) }
    FIXED_COLORS.each { |k, v| const_set(k, v) }

    BASE_PRIMARY.each do |base|
      prefix = self.constant_prefix_for(base)
      const_set(prefix, base)
      PRIMARY_SHADES.each do |shade|
        const_set("#{prefix}_#{shade}", "#{base}#{shade}")
      end
    end

    BASE_ACCENT.each do |base|
      prefix = "#{self.constant_prefix_for(base)}_ACCENT"
      const_set(prefix, "#{base}accent")
      ACCENT_SHADES.each do |shade|
        const_set("#{prefix}_#{shade}", "#{base}accent#{shade}")
      end
    end

    DEPRECATED_ALIASES.each do |alias_name, target|
      const_set(alias_name, const_get(target))
    end

    constants(false).each do |name|
      next if respond_to?(name)

      define_singleton_method(name) { const_get(name) }
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/icon_data.rb


module Ruflet
  class IconData
    attr_reader :value

    def initialize(value)
      @value = normalize(value)
    end

    def ==(other)
      other_value = other.is_a?(IconData) ? other.value : self.class.new(other).value
      if value.is_a?(Integer) && other_value.is_a?(Integer)
        value == other_value
      elsif value.is_a?(String) && other_value.is_a?(String)
        value.casecmp?(other_value)
      else
        value == other_value
      end
    end

    def eql?(other)
      self == other
    end

    def hash
      value.is_a?(String) ? value.downcase.hash : value.hash
    end

    def to_s
      value.to_s
    end

    private

    def normalize(input)
      return input.value if input.is_a?(IconData)
      if input.is_a?(Integer)
        codepoint = Ruflet::MaterialIconLookup.codepoint_for(input)
        codepoint = Ruflet::CupertinoIconLookup.codepoint_for(input) if codepoint == input
        return codepoint
      end

      raw = input.to_s.strip
      return raw if raw.empty?

      codepoint = Ruflet::MaterialIconLookup.codepoint_for(raw)
      codepoint = Ruflet::CupertinoIconLookup.codepoint_for(raw) if codepoint.nil?
      return codepoint unless codepoint.nil?

      raw
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/icons/material_icons.rb


module Ruflet
  module MaterialIcons
    module_function

    ICONS = begin
      source = Ruflet::MaterialIconLookup.icon_map
      if source.empty?
        {
          HOME: "home",
          SETTINGS: "settings",
          SEARCH: "search",
          ADD: "add",
          CLOSE: "close"
        }
      else
        source.keys.each_with_object({}) do |name, result|
          text = name.to_s.gsub(/[^a-zA-Z0-9]/, "_").gsub(/_+/, "_").sub(/\A_/, "").sub(/_\z/, "")
          text = "ICON_#{text}" if text.match?(/\A\d/)
          result[text.upcase.to_sym] = name
        end
      end.freeze
    end

    ICONS.each do |const_name, icon_name|
      next if const_defined?(const_name, false)

      const_set(const_name, Ruflet::IconData.new(icon_name))
    end

    def [](name)
      key = name.to_s.upcase.to_sym
      return const_get(key) if const_defined?(key, false)

      Ruflet::IconData.new(name.to_s)
    end

    def all
      ICONS.keys.map { |k| const_get(k) }
    end

    def random
      all.sample || Ruflet::IconData.new(Ruflet::MaterialIconLookup.fallback_codepoint)
    end

    def names
      ICONS.values
    end

  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/icons/material_icon_lookup.rb

module Ruflet
  module MaterialIconLookup
    module_function

    def codepoint_for(value)
      return value if value.is_a?(Integer)

      text = value.to_s.strip
      return nil if text.empty?

      numeric = parse_numeric(text)
      return numeric unless numeric.nil?

      icons = icon_map
      candidate_names(text).each do |name|
        codepoint = icons[name]
        return codepoint unless codepoint.nil?
      end

      nil
    end

    def fallback_codepoint
      icons = icon_map
      icons["HELP_OUTLINE"] || icons["HELP"] || icons["QUESTION_MARK"] || 0
    end

    def icon_map
      @icon_map ||= load_icon_map
    end

    def candidate_names(name)
      raw = name.to_s.strip
      return [] if raw.empty?

      underscored = raw.gsub(/\s+|-/, "_").downcase
      stripped = underscored.sub(/\Aicons\./, "")
      upper = stripped.upcase

      [raw, raw.upcase, underscored, stripped, upper].uniq
    end

    def parse_numeric(text)
      return text.to_i(16) if text.match?(/\A0x[0-9a-fA-F]+\z/)
      return text.to_i if text.match?(/\A\d+\z/)

      nil
    end

    def load_icon_map
      path = flet_material_icons_json_file
      if path && File.file?(path)
        return parse_icons_json(path)
      end

      dart_list = flet_material_icons_dart_file
      if dart_list && File.file?(dart_list)
        return parse_flet_icons_dart(dart_list, icon_prefix: "Icons.", set_id: 1)
      end

      {}
    end

    def flet_material_icons_json_file
      candidate_from_flet_checkout("sdk/python/packages/flet/src/flet/controls/material/icons.json")
    end

    def flet_material_icons_dart_file
      candidate_from_flet_checkout("packages/flet/lib/src/utils/material_icons.dart")
    end

    def candidate_from_flet_checkout(relative_path)
      flet_root = File.join(Dir.home, ".pub-cache", "git")
      return nil unless Dir.exist?(flet_root)

      entries = Dir.children(flet_root).select { |e| e.start_with?("flet-") }
      return nil if entries.empty?

      candidates = entries.map { |e| File.join(flet_root, e, relative_path) }.select { |p| File.file?(p) }
      return nil if candidates.empty?

      candidates.max_by { |p| File.mtime(p) rescue Time.at(0) }
    end

    def parse_icons_json(path)
      parsed = JSON.parse(File.read(path))
      parsed.each_with_object({}) do |(k, v), out|
        out[k.to_s.upcase] = v.to_i
      end
    end

    def parse_flet_icons_dart(path, icon_prefix:, set_id:)
      mapping = {}
      index = 0
      pattern = /^\s*#{Regexp.escape(icon_prefix)}([a-zA-Z0-9_]+),/

      File.foreach(path) do |line|
        next unless (match = line.match(pattern))

        encoded = (set_id << 16) | index
        mapping[match[1].upcase] = encoded
        index += 1
      end

      mapping
    end

  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/icons/cupertino/cupertino_icons.rb


module Ruflet
  module CupertinoIcons
    module_function

    ICONS = begin
      source = Ruflet::CupertinoIconLookup.icon_map
      if source.empty?
        {
          HOME: "house",
          SEARCH: "search",
          SETTINGS: "gear",
          ADD: "add",
          CLOSE: "clear"
        }
      else
        source.keys.each_with_object({}) do |name, result|
          text = name.to_s.gsub(/[^a-zA-Z0-9]/, "_").gsub(/_+/, "_").sub(/\A_/, "").sub(/_\z/, "")
          text = "ICON_#{text}" if text.match?(/\A\d/)
          result[text.upcase.to_sym] = name
        end
      end.freeze
    end

    ICONS.each do |const_name, icon_name|
      next if const_defined?(const_name, false)

      const_set(const_name, Ruflet::IconData.new(icon_name))
    end

    def [](name)
      key = name.to_s.upcase.to_sym
      return const_get(key) if const_defined?(key, false)

      Ruflet::IconData.new(name.to_s)
    end

    def all
      ICONS.keys.map { |k| const_get(k) }
    end

    def random
      all.sample || Ruflet::IconData.new(Ruflet::CupertinoIconLookup.fallback_codepoint)
    end

    def names
      ICONS.values
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/icons/cupertino_icon_lookup.rb

module Ruflet
  module CupertinoIconLookup
    module_function

    def codepoint_for(value)
      return value if value.is_a?(Integer)

      text = value.to_s.strip
      return nil if text.empty?

      numeric = parse_numeric(text)
      return numeric unless numeric.nil?

      icons = icon_map
      candidate_names(text).each do |name|
        codepoint = icons[name]
        return codepoint unless codepoint.nil?
      end

      nil
    end

    def fallback_codepoint
      icons = icon_map
      icons["QUESTION_CIRCLE"] || icons["QUESTION"] || 0
    end

    def icon_map
      @icon_map ||= load_icon_map
    end

    def candidate_names(name)
      raw = name.to_s.strip
      return [] if raw.empty?

      underscored = raw.gsub(/\s+|-/, "_").downcase
      stripped = underscored.sub(/\Acupertinoicons\./i, "")
      upper = stripped.upcase

      [raw, raw.upcase, underscored, stripped, upper].uniq
    end

    def parse_numeric(text)
      return text.to_i(16) if text.match?(/\A0x[0-9a-fA-F]+\z/)
      return text.to_i if text.match?(/\A\d+\z/)

      nil
    end

    def load_icon_map
      path = flet_cupertino_icons_json_file
      if path && File.file?(path)
        return parse_icons_json(path)
      end

      dart_list = flet_cupertino_icons_dart_file
      if dart_list && File.file?(dart_list)
        return parse_flet_icons_dart(dart_list, icon_prefix: "CupertinoIcons.", set_id: 2)
      end

      {}
    end

    def flet_cupertino_icons_json_file
      candidate_from_flet_checkout("sdk/python/packages/flet/src/flet/controls/cupertino/cupertino_icons.json")
    end

    def flet_cupertino_icons_dart_file
      candidate_from_flet_checkout("packages/flet/lib/src/utils/cupertino_icons.dart")
    end

    def candidate_from_flet_checkout(relative_path)
      flet_root = File.join(Dir.home, ".pub-cache", "git")
      return nil unless Dir.exist?(flet_root)

      entries = Dir.children(flet_root).select { |e| e.start_with?("flet-") }
      return nil if entries.empty?

      candidates = entries.map { |e| File.join(flet_root, e, relative_path) }.select { |p| File.file?(p) }
      return nil if candidates.empty?

      candidates.max_by { |p| File.mtime(p) rescue Time.at(0) }
    end

    def parse_icons_json(path)
      parsed = JSON.parse(File.read(path))
      parsed.each_with_object({}) do |(k, v), out|
        out[k.to_s.upcase] = v.to_i
      end
    end

    def parse_flet_icons_dart(path, icon_prefix:, set_id:)
      mapping = {}
      index = 0
      pattern = /^\s*#{Regexp.escape(icon_prefix)}([a-zA-Z0-9_]+),/

      File.foreach(path) do |line|
        next unless (match = line.match(pattern))

        encoded = (set_id << 16) | index
        mapping[match[1].upcase] = encoded
        index += 1
      end

      mapping
    end

  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/control.rb

begin
rescue LoadError
  nil
end

module Ruflet
  class Control
    TYPE_MAP = UI::ControlRegistry::TYPE_MAP
    EVENT_PROPS = UI::ControlRegistry::EVENT_PROPS
    HOST_EXPANDED_TYPES = %w[view row column].freeze

    attr_reader :type, :id, :props, :children
    attr_accessor :wire_id, :runtime_page

    def initialize(type:, id: nil, **props)
      @type = type.to_s.downcase
      @id = (id || props.delete(:id) || "ctrl_#{self.class.generate_id}").to_s
      @children = []
      @handlers = {}
      @wire_id = nil
      @props = normalize_props(extract_handlers(preprocess_props(props)))
    end

    def on(event_name, &block)
      name = normalized_event_name(event_name)
      @handlers[name] = block
      @props["on_#{name}"] = true
      runtime_page&.update(self, "on_#{name}": true) if wire_id
      self
    end

    def emit(event_name, event)
      handler = @handlers[normalized_event_name(event_name)]
      return false unless handler

      handler.call(event)
      true
    end

    def has_handler?(event_name)
      @handlers.key?(normalized_event_name(event_name))
    end

    def to_patch
      patch = {
        "_c" => TYPE_MAP.fetch(type, type.split("_").map(&:capitalize).join),
        "_i" => wire_id
      }

      internals = {}
      internals["host_positioned"] = true if type == "stack"
      internals["host_expanded"] = true if HOST_EXPANDED_TYPES.include?(type)
      patch["_internals"] = internals unless internals.empty?

      props.each { |k, v| patch[k] = serialize_value(v) }
      patch["controls"] = children.map(&:to_patch) unless children.empty?
      patch
    end

    private

    class << self
      def generate_id
        if defined?(SecureRandom) && SecureRandom.respond_to?(:hex)
          SecureRandom.hex(4)
        else
          format("%08x", rand(0..0xffff_ffff))
        end
      end
    end

    def serialize_value(value)
      case value
      when Control
        value.to_patch
      when Ruflet::IconData
        value.value
      when Array
        value.map { |v| serialize_value(v) }
      when Hash
        value.transform_values { |v| serialize_value(v) }
      else
        value
      end
    end

    def extract_handlers(input)
      output = input.dup

      EVENT_PROPS.each do |prop, event_name|
        string_prop = prop.to_s
        next unless output.key?(prop) || output.key?(string_prop)

        handler = output.key?(prop) ? output.delete(prop) : output.delete(string_prop)
        @handlers[event_name] = handler if handler.respond_to?(:call)
        output["on_#{event_name}"] = true
      end

      output
    end

    def normalize_props(hash)
      hash.each_with_object({}) do |(k, v), result|
        key = k.to_s
        mapped_key = key
        value =
          if v.is_a?(Symbol)
            v.to_s
          elsif v.is_a?(Ruflet::IconData)
            v.value
          else
            v
          end
        value = normalize_icon_prop(mapped_key, value)
        value = normalize_color_prop(mapped_key, value)

        result[mapped_key] = value
      end
    end

    def preprocess_props(props)
      props
    end

    def normalize_color_prop(key, value)
      return value unless value.is_a?(String)
      return value.downcase if color_prop_key?(key)

      value
    end

    def color_prop_key?(key)
      key == "color" || key == "bgcolor" || key.end_with?("_color")
    end

    def normalize_icon_prop(key, value)
      return value unless icon_prop_key?(key)
      codepoint = resolve_icon_codepoint(value)
      codepoint.nil? ? value : codepoint
    end

    def icon_prop_key?(key)
      key == "icon" || key.end_with?("_icon")
    end

    def resolve_icon_codepoint(value)
      return nil unless value.is_a?(Integer) || value.is_a?(Symbol) || value.is_a?(String)

      codepoint = Ruflet::MaterialIconLookup.codepoint_for(value)
      if codepoint.nil? || (value.is_a?(Integer) && codepoint == value)
        cupertino = Ruflet::CupertinoIconLookup.codepoint_for(value)
        codepoint = cupertino unless cupertino.nil?
      end
      codepoint
    end

    def normalized_event_name(event_name)
      event_name.to_s.sub(/\Aon_/, "")
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/event.rb


module Ruflet
  class Event
    attr_reader :name, :target, :raw_data, :data, :page, :control

    def initialize(name:, target:, raw_data:, page:, control:)
      @name = name
      @target = target
      @raw_data = raw_data
      @data = parse_data(raw_data)
      @page = page
      @control = control
    end

    private

    def parse_data(raw)
      return raw unless raw.is_a?(String)

      JSON.parse(raw)
    rescue JSON::ParserError
      raw
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/cupertino_action_sheet_control.rb

module Ruflet
  module UI
    module Controls
      class CupertinoActionSheetControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_action_sheet", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/cupertino_alert_dialog_control.rb

module Ruflet
  module UI
    module Controls
      class CupertinoAlertDialogControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_alert_dialog", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/cupertino_button_control.rb

module Ruflet
  module UI
    module Controls
      class CupertinoButtonControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_button", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/cupertino_dialog_action_control.rb

module Ruflet
  module UI
    module Controls
      class CupertinoDialogActionControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_dialog_action", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/cupertino_filled_button_control.rb

module Ruflet
  module UI
    module Controls
      class CupertinoFilledButtonControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_filled_button", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/cupertino_navigation_bar_control.rb

module Ruflet
  module UI
    module Controls
      class CupertinoNavigationBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_navigation_bar", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/cupertino_slider_control.rb

module Ruflet
  module UI
    module Controls
      class CupertinoSliderControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_slider", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/cupertino_switch_control.rb

module Ruflet
  module UI
    module Controls
      class CupertinoSwitchControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_switch", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/cupertino_text_field_control.rb

module Ruflet
  module UI
    module Controls
      class CupertinoTextFieldControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_text_field", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/alert_dialog_control.rb

module Ruflet
  module UI
    module Controls
      class AlertDialogControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "alertdialog", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/app_bar_control.rb

module Ruflet
  module UI
    module Controls
      class AppBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "appbar", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/bottom_sheet_control.rb

module Ruflet
  module UI
    module Controls
      class BottomSheetControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "bottomsheet", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/button_control.rb

module Ruflet
  module UI
    module Controls
      class ButtonControl < Ruflet::Control
        def initialize(id: nil, type: "button", **props)
          super(type: type, id: id, **props)
        end

        private

        def preprocess_props(props)
          mapped = props.dup
          if mapped.key?(:text) || mapped.key?("text")
            value = mapped.delete(:text) || mapped.delete("text")
            mapped[:content] = value unless mapped.key?(:content) || mapped.key?("content")
          end
          mapped
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/checkbox_control.rb

module Ruflet
  module UI
    module Controls
      class CheckboxControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "checkbox", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/column_control.rb

module Ruflet
  module UI
    module Controls
      class ColumnControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "column", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/container_control.rb

module Ruflet
  module UI
    module Controls
      class ContainerControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "container", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/drag_target_control.rb

module Ruflet
  module UI
    module Controls
      class DragTargetControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "dragtarget", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/draggable_control.rb

module Ruflet
  module UI
    module Controls
      class DraggableControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "draggable", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/elevated_button_control.rb

module Ruflet
  module UI
    module Controls
      class ElevatedButtonControl < ButtonControl
        def initialize(id: nil, **props)
          super(type: "elevatedbutton", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/filled_button_control.rb

module Ruflet
  module UI
    module Controls
      class FilledButtonControl < ButtonControl
        def initialize(id: nil, **props)
          super(type: "filledbutton", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/floating_action_button_control.rb

module Ruflet
  module UI
    module Controls
      class FloatingActionButtonControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "floatingactionbutton", id: id, **props)
        end

        private

        def preprocess_props(props)
          normalized = props.dup

          # Accept both correct and common-misspelled foreground color keys.
          if !normalized.key?(:color) && !normalized.key?("color")
            fg = normalized.delete(:foreground_color) || normalized.delete("foreground_color")
            fg ||= normalized.delete(:forground_color) || normalized.delete("forground_color")
            normalized[:color] = fg if fg
          end

          normalized
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/gesture_detector_control.rb

module Ruflet
  module UI
    module Controls
      class GestureDetectorControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "gesturedetector", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/icon_button_control.rb

module Ruflet
  module UI
    module Controls
      class IconButtonControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "iconbutton", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/icon_control.rb

module Ruflet
  module UI
    module Controls
      class IconControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "icon", id: id, **props)
        end

        private

        def preprocess_props(props)
          mapped = props.dup
          if mapped.key?(:name) || mapped.key?("name")
            value = mapped.delete(:name) || mapped.delete("name")
            mapped[:icon] = value unless mapped.key?(:icon) || mapped.key?("icon")
          end
          mapped
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/image_control.rb

module Ruflet
  module UI
    module Controls
      class ImageControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "image", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/markdown_control.rb

module Ruflet
  module UI
    module Controls
      class MarkdownControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "markdown", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/navigation_bar_control.rb

module Ruflet
  module UI
    module Controls
      class NavigationBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "navigationbar", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/navigation_bar_destination_control.rb

module Ruflet
  module UI
    module Controls
      class NavigationBarDestinationControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "navigationbardestination", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/radio_control.rb

module Ruflet
  module UI
    module Controls
      class RadioControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "radio", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/radio_group_control.rb

module Ruflet
  module UI
    module Controls
      class RadioGroupControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "radiogroup", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/row_control.rb

module Ruflet
  module UI
    module Controls
      class RowControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "row", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/snack_bar_control.rb

module Ruflet
  module UI
    module Controls
      class SnackBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "snackbar", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/stack_control.rb

module Ruflet
  module UI
    module Controls
      class StackControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "stack", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/tab_bar_control.rb

module Ruflet
  module UI
    module Controls
      class TabBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "tabbar", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/tab_bar_view_control.rb

module Ruflet
  module UI
    module Controls
      class TabBarViewControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "tabbarview", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/tab_control.rb

module Ruflet
  module UI
    module Controls
      class TabControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "tab", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/tabs_control.rb


module Ruflet
  module UI
    module Controls
      class TabsControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "tabs", id: id, **props)
        end

        private

        # Normalize shorthand tabs payload into Flet's expected structure:
        # Tabs(length, content: Column(TabBar, TabBarView))
        def preprocess_props(props)
          mapped = props.dup
          tabs = mapped.delete(:tabs) || mapped.delete("tabs")
          return mapped if tabs.nil?
          return mapped unless tabs.is_a?(Array)
          return mapped if mapped.key?(:content) || mapped.key?("content")

          tab_controls = []
          view_controls = []

          tabs.each do |tab|
            unless tab.is_a?(Ruflet::Control) && tab.type == "tab"
              # Keep TabBar and TabBarView lengths aligned.
              tab_controls << Ruflet::UI::Controls::TabControl.new(label: tab)
              view_controls << Ruflet::UI::Controls::ColumnControl.new(controls: [])
              next
            end

            label = tab.props["label"]
            icon = tab.props["icon"]
            header_tab = Ruflet::UI::Controls::TabControl.new(label: label, icon: icon)
            tab_controls << header_tab

            content = tab.props["content"]
            view_controls << (content.is_a?(Ruflet::Control) ? content : Ruflet::UI::Controls::ColumnControl.new(controls: []))
          end

          tab_bar = Ruflet::UI::Controls::TabBarControl.new(tabs: tab_controls)
          tab_bar_view_props = { controls: view_controls }
          # Only opt into flexed TabBarView when developer explicitly sizes Tabs.
          if mapped.key?(:expand) || mapped.key?("expand") || mapped.key?(:height) || mapped.key?("height")
            tab_bar_view_props[:expand] = 1
          end
          tab_bar_view = Ruflet::UI::Controls::TabBarViewControl.new(**tab_bar_view_props)
          content = Ruflet::UI::Controls::ColumnControl.new(expand: true, spacing: 0, controls: [tab_bar, tab_bar_view])

          mapped[:length] = tab_controls.length unless mapped.key?(:length) || mapped.key?("length")
          mapped[:content] = content
          mapped
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/text_button_control.rb

module Ruflet
  module UI
    module Controls
      class TextButtonControl < ButtonControl
        def initialize(id: nil, **props)
          super(type: "textbutton", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/text_control.rb

module Ruflet
  module UI
    module Controls
      class TextControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "text", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/text_field_control.rb

module Ruflet
  module UI
    module Controls
      class TextFieldControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "textfield", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/view_control.rb

module Ruflet
  module UI
    module Controls
      class ViewControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "view", id: id, **props)
        end
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/control_registry.rb

module Ruflet
  module UI
    module ControlRegistry

      TYPE_MAP = MaterialControlRegistry::TYPE_MAP.merge(CupertinoControlRegistry::TYPE_MAP).freeze
      EVENT_PROPS = MaterialControlRegistry::EVENT_PROPS.merge(CupertinoControlRegistry::EVENT_PROPS).freeze
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/cupertino_control_registry.rb

module Ruflet
  module UI
    module CupertinoControlRegistry
      TYPE_MAP = {
        "cupertino_button" => "CupertinoButton",
        "cupertinobutton" => "CupertinoButton",
        "cupertino_filled_button" => "CupertinoFilledButton",
        "cupertinofilledbutton" => "CupertinoFilledButton",
        "cupertino_text_field" => "CupertinoTextField",
        "cupertinotextfield" => "CupertinoTextField",
        "cupertino_switch" => "CupertinoSwitch",
        "cupertinoswitch" => "CupertinoSwitch",
        "cupertino_slider" => "CupertinoSlider",
        "cupertinoslider" => "CupertinoSlider",
        "cupertino_alert_dialog" => "CupertinoAlertDialog",
        "cupertinoalertdialog" => "CupertinoAlertDialog",
        "cupertino_action_sheet" => "CupertinoActionSheet",
        "cupertinoactionsheet" => "CupertinoActionSheet",
        "cupertino_dialog_action" => "CupertinoDialogAction",
        "cupertinodialogaction" => "CupertinoDialogAction",
        "cupertino_navigation_bar" => "CupertinoNavigationBar",
        "cupertinonavigationbar" => "CupertinoNavigationBar"
      }.freeze

      EVENT_PROPS = {
        on_click: "click",
        on_change: "change",
        on_submit: "submit",
        on_dismiss: "dismiss"
      }.freeze
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/material_control_registry.rb

module Ruflet
  module UI
    module MaterialControlRegistry
      TYPE_MAP = {
        "text" => "Text",
        "column" => "Column",
        "row" => "Row",
        "stack" => "Stack",
        "view" => "View",
        "container" => "Container",
        "checkbox" => "Checkbox",
        "radio" => "Radio",
        "radiogroup" => "RadioGroup",
        "radio_group" => "RadioGroup",
        "alertdialog" => "AlertDialog",
        "alert_dialog" => "AlertDialog",
        "snackbar" => "SnackBar",
        "snack_bar" => "SnackBar",
        "bottomsheet" => "BottomSheet",
        "bottom_sheet" => "BottomSheet",
        "markdown" => "Markdown",
        "textbutton" => "TextButton",
        "text_button" => "TextButton",
        "filledbutton" => "FilledButton",
        "filled_button" => "FilledButton",
        "gesturedetector" => "GestureDetector",
        "gesture_detector" => "GestureDetector",
        "draggable" => "Draggable",
        "dragtarget" => "DragTarget",
        "drag_target" => "DragTarget",
        "textfield" => "TextField",
        "text_field" => "TextField",
        "button" => "Button",
        "elevatedbutton" => "Button",
        "elevated_button" => "Button",
        "iconbutton" => "IconButton",
        "icon_button" => "IconButton",
        "icon" => "Icon",
        "image" => "Image",
        "appbar" => "AppBar",
        "app_bar" => "AppBar",
        "floatingactionbutton" => "FloatingActionButton",
        "floating_action_button" => "FloatingActionButton",
        "tabs" => "Tabs",
        "tab" => "Tab",
        "tabbar" => "TabBar",
        "tab_bar" => "TabBar",
        "tabbarview" => "TabBarView",
        "tab_bar_view" => "TabBarView",
        "navigationbar" => "NavigationBar",
        "navigation_bar" => "NavigationBar",
        "navigationbardestination" => "NavigationBarDestination",
        "navigation_bar_destination" => "NavigationBarDestination"
      }.freeze

      EVENT_PROPS = {
        on_click: "click",
        on_change: "change",
        on_action: "action",
        on_submit: "submit",
        on_dismiss: "dismiss",
        on_tap: "tap",
        on_double_tap: "double_tap",
        on_long_press: "long_press",
        on_hover: "hover",
        on_pan_start: "pan_start",
        on_pan_update: "pan_update",
        on_pan_end: "pan_end",
        on_scale_start: "scale_start",
        on_scale_update: "scale_update",
        on_scale_end: "scale_end",
        on_vertical_drag_start: "vertical_drag_start",
        on_vertical_drag_update: "vertical_drag_update",
        on_vertical_drag_end: "vertical_drag_end",
        on_horizontal_drag_start: "horizontal_drag_start",
        on_horizontal_drag_update: "horizontal_drag_update",
        on_horizontal_drag_end: "horizontal_drag_end",
        on_accept: "accept",
        on_will_accept: "will_accept",
        on_accept_with_details: "accept_with_details",
        on_move: "move",
        on_leave: "leave"
      }.freeze
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/cupertino_control_factory.rb


module Ruflet
  module UI
    module CupertinoControlFactory
      module_function

      CLASS_MAP = {
        "cupertino_button" => Controls::CupertinoButtonControl,
        "cupertinobutton" => Controls::CupertinoButtonControl,
        "cupertino_filled_button" => Controls::CupertinoFilledButtonControl,
        "cupertinofilledbutton" => Controls::CupertinoFilledButtonControl,
        "cupertino_text_field" => Controls::CupertinoTextFieldControl,
        "cupertinotextfield" => Controls::CupertinoTextFieldControl,
        "cupertino_switch" => Controls::CupertinoSwitchControl,
        "cupertinoswitch" => Controls::CupertinoSwitchControl,
        "cupertino_slider" => Controls::CupertinoSliderControl,
        "cupertinoslider" => Controls::CupertinoSliderControl,
        "cupertino_alert_dialog" => Controls::CupertinoAlertDialogControl,
        "cupertinoalertdialog" => Controls::CupertinoAlertDialogControl,
        "cupertino_action_sheet" => Controls::CupertinoActionSheetControl,
        "cupertinoactionsheet" => Controls::CupertinoActionSheetControl,
        "cupertino_dialog_action" => Controls::CupertinoDialogActionControl,
        "cupertinodialogaction" => Controls::CupertinoDialogActionControl,
        "cupertino_navigation_bar" => Controls::CupertinoNavigationBarControl,
        "cupertinonavigationbar" => Controls::CupertinoNavigationBarControl
      }.freeze
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/material_control_factory.rb


module Ruflet
  module UI
    module MaterialControlFactory
      module_function

      CLASS_MAP = {
        "text" => Controls::TextControl,
        "view" => Controls::ViewControl,
        "column" => Controls::ColumnControl,
        "row" => Controls::RowControl,
        "stack" => Controls::StackControl,
        "container" => Controls::ContainerControl,
        "gesturedetector" => Controls::GestureDetectorControl,
        "gesture_detector" => Controls::GestureDetectorControl,
        "draggable" => Controls::DraggableControl,
        "dragtarget" => Controls::DragTargetControl,
        "drag_target" => Controls::DragTargetControl,
        "textfield" => Controls::TextFieldControl,
        "text_field" => Controls::TextFieldControl,
        "button" => Controls::ButtonControl,
        "elevatedbutton" => Controls::ElevatedButtonControl,
        "elevated_button" => Controls::ElevatedButtonControl,
        "textbutton" => Controls::TextButtonControl,
        "text_button" => Controls::TextButtonControl,
        "filledbutton" => Controls::FilledButtonControl,
        "filled_button" => Controls::FilledButtonControl,
        "iconbutton" => Controls::IconButtonControl,
        "icon_button" => Controls::IconButtonControl,
        "icon" => Controls::IconControl,
        "image" => Controls::ImageControl,
        "appbar" => Controls::AppBarControl,
        "app_bar" => Controls::AppBarControl,
        "floatingactionbutton" => Controls::FloatingActionButtonControl,
        "floating_action_button" => Controls::FloatingActionButtonControl,
        "checkbox" => Controls::CheckboxControl,
        "radio" => Controls::RadioControl,
        "radiogroup" => Controls::RadioGroupControl,
        "radio_group" => Controls::RadioGroupControl,
        "alertdialog" => Controls::AlertDialogControl,
        "alert_dialog" => Controls::AlertDialogControl,
        "snackbar" => Controls::SnackBarControl,
        "snack_bar" => Controls::SnackBarControl,
        "bottomsheet" => Controls::BottomSheetControl,
        "bottom_sheet" => Controls::BottomSheetControl,
        "markdown" => Controls::MarkdownControl,
        "tabs" => Controls::TabsControl,
        "tab" => Controls::TabControl,
        "tabbar" => Controls::TabBarControl,
        "tab_bar" => Controls::TabBarControl,
        "tabbarview" => Controls::TabBarViewControl,
        "tab_bar_view" => Controls::TabBarViewControl,
        "navigationbar" => Controls::NavigationBarControl,
        "navigation_bar" => Controls::NavigationBarControl,
        "navigationbardestination" => Controls::NavigationBarDestinationControl,
        "navigation_bar_destination" => Controls::NavigationBarDestinationControl
      }.freeze
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/control_factory.rb


module Ruflet
  module UI
    module ControlFactory
      module_function

      CLASS_MAP = MaterialControlFactory::CLASS_MAP.merge(CupertinoControlFactory::CLASS_MAP).freeze

      def build(type, id: nil, **props)
        normalized_type = type.to_s.downcase
        klass = CLASS_MAP[normalized_type]
        raise ArgumentError, "Unsupported control type: #{normalized_type}" unless klass

        klass.new(id: id, **props)
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/control_methods.rb


module Ruflet
  module UI
    module ControlMethods
      include MaterialControlMethods
      include CupertinoControlMethods

      def control(type, **props, &block) = build_widget(type, **props, &block)
      def widget(type, **props, &block) = build_widget(type, **props, &block)
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/cupertino_control_methods.rb

module Ruflet
  module UI
    module CupertinoControlMethods
      def cupertino_button(**props) = build_widget(:cupertino_button, **props)
      def cupertinobutton(**props) = cupertino_button(**props)
      def cupertino_filled_button(**props) = build_widget(:cupertino_filled_button, **props)
      def cupertinofilledbutton(**props) = cupertino_filled_button(**props)
      def cupertino_text_field(**props) = build_widget(:cupertino_text_field, **props)
      def cupertinotextfield(**props) = cupertino_text_field(**props)
      def cupertino_switch(**props) = build_widget(:cupertino_switch, **props)
      def cupertinoswitch(**props) = cupertino_switch(**props)
      def cupertino_slider(**props) = build_widget(:cupertino_slider, **props)
      def cupertinoslider(**props) = cupertino_slider(**props)
      def cupertino_alert_dialog(**props) = build_widget(:cupertino_alert_dialog, **props)
      def cupertinoalertdialog(**props) = cupertino_alert_dialog(**props)
      def cupertino_action_sheet(**props) = build_widget(:cupertino_action_sheet, **props)
      def cupertinoactionsheet(**props) = cupertino_action_sheet(**props)
      def cupertino_dialog_action(**props) = build_widget(:cupertino_dialog_action, **props)
      def cupertinodialogaction(**props) = cupertino_dialog_action(**props)
      def cupertino_navigation_bar(**props) = build_widget(:cupertino_navigation_bar, **props)
      def cupertinonavigationbar(**props) = cupertino_navigation_bar(**props)
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/material_control_methods.rb

module Ruflet
  module UI
    module MaterialControlMethods
      def view(**props, &block) = build_widget(:view, **props, &block)
      def column(**props, &block) = build_widget(:column, **props, &block)

      def center(**props, &block)
        mapped = props.dup
        defaults = { expand: true, alignment: { x: 0, y: 0 } }

        if block
          nested = WidgetBuilder.new
          block_result = nested.instance_eval(&block)
          child =
            if nested.children.any?
              nested.children.first
            elsif block_result.is_a?(Ruflet::Control)
              block_result
            end
          mapped[:content] = child if child
        end

        build_widget(:container, **normalize_container_props(defaults.merge(mapped)))
      end

      def row(**props, &block) = build_widget(:row, **props, &block)
      def stack(**props, &block) = build_widget(:stack, **props, &block)
      def container(**props, &block) = build_widget(:container, **normalize_container_props(props), &block)
      def gesture_detector(**props, &block) = build_widget(:gesturedetector, **props, &block)
      def gesturedetector(**props, &block) = gesture_detector(**props, &block)
      def draggable(**props, &block) = build_widget(:draggable, **props, &block)
      def drag_target(**props, &block) = build_widget(:dragtarget, **props, &block)
      def dragtarget(**props, &block) = drag_target(**props, &block)

      def text(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:text, **mapped)
      end

      def button(**props) = build_widget(:button, **props)
      def elevated_button(**props) = build_widget(:elevatedbutton, **props)
      def elevatedbutton(**props) = elevated_button(**props)
      def text_button(**props) = build_widget(:textbutton, **props)
      def textbutton(**props) = text_button(**props)
      def filled_button(**props) = build_widget(:filledbutton, **props)
      def filledbutton(**props) = filled_button(**props)

      def icon_button(**props) = build_widget(:iconbutton, **props)
      def iconbutton(**props) = icon_button(**props)
      def text_field(**props) = build_widget(:textfield, **props)
      def textfield(**props) = text_field(**props)
      def checkbox(**props) = build_widget(:checkbox, **props)
      def radio(**props) = build_widget(:radio, **props)
      def radio_group(**props) = build_widget(:radiogroup, **props)
      def radiogroup(**props) = radio_group(**props)
      def alert_dialog(**props) = build_widget(:alertdialog, **props)
      def alertdialog(**props) = alert_dialog(**props)
      def snack_bar(**props) = build_widget(:snackbar, **props)
      def snackbar(**props) = snack_bar(**props)
      def bottom_sheet(**props) = build_widget(:bottomsheet, **props)
      def bottomsheet(**props) = bottom_sheet(**props)

      def markdown(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:markdown, **mapped)
      end

      def icon(**props) = build_widget(:icon, **props)

      def image(src = nil, **props)
        mapped = props.dup
        mapped[:src] = src unless src.nil?
        build_widget(:image, **mapped)
      end

      def app_bar(**props) = build_widget(:appbar, **props)
      def appbar(**props) = app_bar(**props)
      def floating_action_button(**props) = build_widget(:floatingactionbutton, **props)
      def floatingactionbutton(**props) = floating_action_button(**props)
      def tabs(**props, &block) = build_widget(:tabs, **props, &block)
      def tab(**props, &block) = build_widget(:tab, **props, &block)
      def tab_bar(**props, &block) = build_widget(:tabbar, **props, &block)
      def tabbar(**props, &block) = tab_bar(**props, &block)
      def tab_bar_view(**props, &block) = build_widget(:tabbarview, **props, &block)
      def tabbarview(**props, &block) = tab_bar_view(**props, &block)
      def navigation_bar(**props, &block) = build_widget(:navigationbar, **props, &block)
      def navigationbar(**props, &block) = navigation_bar(**props, &block)
      def navigation_bar_destination(**props, &block) = build_widget(:navigationbardestination, **props, &block)
      def navigationbardestination(**props, &block) = navigation_bar_destination(**props, &block)

      def fab(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:floatingactionbutton, **mapped)
      end

      private

      # Flet container alignment expects a vector-like object ({x:, y:}),
      # not a plain string. Keep common shorthand compatible.
      def normalize_container_props(props)
        mapped = props.dup
        alignment = mapped[:alignment] || mapped["alignment"]
        if alignment == "center" || alignment == :center
          mapped[:alignment] = { x: 0, y: 0 }
          mapped.delete("alignment")
        end
        mapped
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/shared_control_forwarders.rb

module Ruflet
  module UI
    module SharedControlForwarders
      def control(type, **props, &block) = control_delegate.control(type, **props, &block)
      def widget(type, **props, &block) = control_delegate.widget(type, **props, &block)
      def view(**props, &block) = control_delegate.view(**props, &block)
      def column(**props, &block) = control_delegate.column(**props, &block)
      def center(**props, &block) = control_delegate.center(**props, &block)
      def row(**props, &block) = control_delegate.row(**props, &block)
      def stack(**props, &block) = control_delegate.stack(**props, &block)
      def container(**props, &block) = control_delegate.container(**props, &block)
      def gesture_detector(**props, &block) = control_delegate.gesture_detector(**props, &block)
      def gesturedetector(**props, &block) = control_delegate.gesturedetector(**props, &block)
      def draggable(**props, &block) = control_delegate.draggable(**props, &block)
      def drag_target(**props, &block) = control_delegate.drag_target(**props, &block)
      def dragtarget(**props, &block) = control_delegate.dragtarget(**props, &block)
      def text(value = nil, **props) = control_delegate.text(value, **props)
      def button(**props) = control_delegate.button(**props)
      def elevated_button(**props) = control_delegate.elevated_button(**props)
      def elevatedbutton(**props) = control_delegate.elevatedbutton(**props)
      def text_button(**props) = control_delegate.text_button(**props)
      def textbutton(**props) = control_delegate.textbutton(**props)
      def filled_button(**props) = control_delegate.filled_button(**props)
      def filledbutton(**props) = control_delegate.filledbutton(**props)
      def icon_button(**props) = control_delegate.icon_button(**props)
      def iconbutton(**props) = control_delegate.iconbutton(**props)
      def text_field(**props) = control_delegate.text_field(**props)
      def textfield(**props) = control_delegate.textfield(**props)
      def checkbox(**props) = control_delegate.checkbox(**props)
      def radio(**props) = control_delegate.radio(**props)
      def radio_group(**props) = control_delegate.radio_group(**props)
      def radiogroup(**props) = control_delegate.radiogroup(**props)
      def alert_dialog(**props) = control_delegate.alert_dialog(**props)
      def alertdialog(**props) = control_delegate.alertdialog(**props)
      def snack_bar(**props) = control_delegate.snack_bar(**props)
      def snackbar(**props) = control_delegate.snackbar(**props)
      def bottom_sheet(**props) = control_delegate.bottom_sheet(**props)
      def bottomsheet(**props) = control_delegate.bottomsheet(**props)
      def markdown(value = nil, **props) = control_delegate.markdown(value, **props)
      def icon(**props) = control_delegate.icon(**props)
      def image(src = nil, **props) = control_delegate.image(src, **props)
      def fab(content = nil, **props) = control_delegate.fab(content, **props)
      def app_bar(**props) = control_delegate.app_bar(**props)
      def appbar(**props) = control_delegate.appbar(**props)
      def floating_action_button(**props) = control_delegate.floating_action_button(**props)
      def floatingactionbutton(**props) = control_delegate.floatingactionbutton(**props)
      def tabs(**props, &block) = control_delegate.tabs(**props, &block)
      def tab(**props, &block) = control_delegate.tab(**props, &block)
      def tab_bar(**props, &block) = control_delegate.tab_bar(**props, &block)
      def tabbar(**props, &block) = control_delegate.tabbar(**props, &block)
      def tab_bar_view(**props, &block) = control_delegate.tab_bar_view(**props, &block)
      def tabbarview(**props, &block) = control_delegate.tabbarview(**props, &block)
      def navigation_bar(**props, &block) = control_delegate.navigation_bar(**props, &block)
      def navigationbar(**props, &block) = control_delegate.navigationbar(**props, &block)
      def navigation_bar_destination(**props, &block) = control_delegate.navigation_bar_destination(**props, &block)
      def navigationbardestination(**props, &block) = control_delegate.navigationbardestination(**props, &block)
      def cupertino_button(**props) = control_delegate.cupertino_button(**props)
      def cupertinobutton(**props) = control_delegate.cupertinobutton(**props)
      def cupertino_filled_button(**props) = control_delegate.cupertino_filled_button(**props)
      def cupertinofilledbutton(**props) = control_delegate.cupertinofilledbutton(**props)
      def cupertino_text_field(**props) = control_delegate.cupertino_text_field(**props)
      def cupertinotextfield(**props) = control_delegate.cupertinotextfield(**props)
      def cupertino_switch(**props) = control_delegate.cupertino_switch(**props)
      def cupertinoswitch(**props) = control_delegate.cupertinoswitch(**props)
      def cupertino_slider(**props) = control_delegate.cupertino_slider(**props)
      def cupertinoslider(**props) = control_delegate.cupertinoslider(**props)
      def cupertino_alert_dialog(**props) = control_delegate.cupertino_alert_dialog(**props)
      def cupertinoalertdialog(**props) = control_delegate.cupertinoalertdialog(**props)
      def cupertino_action_sheet(**props) = control_delegate.cupertino_action_sheet(**props)
      def cupertinoactionsheet(**props) = control_delegate.cupertinoactionsheet(**props)
      def cupertino_dialog_action(**props) = control_delegate.cupertino_dialog_action(**props)
      def cupertinodialogaction(**props) = control_delegate.cupertinodialogaction(**props)
      def cupertino_navigation_bar(**props) = control_delegate.cupertino_navigation_bar(**props)
      def cupertinonavigationbar(**props) = control_delegate.cupertinonavigationbar(**props)

      private

      def control_delegate
        raise NotImplementedError, "control_delegate must be implemented by the including/extended context"
      end
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/ui/widget_builder.rb


module Ruflet
  class WidgetBuilder
    include UI::ControlMethods

    attr_reader :children

    def initialize
      @children = []
    end

    def widget(type, **props, &block)
      control(type, **props, &block)
    end

    def control(type, **props, &block)
      mapped_props = props.dup
      prop_children = mapped_props.delete(:controls) || mapped_props.delete("controls")

      node = UI::ControlFactory.build(type, **mapped_props)
      if block
        nested = WidgetBuilder.new
        block_result = nested.instance_eval(&block)
        if block_result.is_a?(Control) && !nested.children.any? { |c| c.object_id == block_result.object_id }
          nested.children << block_result
        end
        node.children.concat(nested.children)
      end

      if prop_children
        Array(prop_children).each do |child|
          node.children << child if child.is_a?(Control)
        end
      end

      @children << node
      node
    end

    def build_widget(type, **props, &block) = control(type, **props, &block)

    private
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/page.rb

begin
rescue LoadError
  class Set
    def initialize
      @index = {}
    end

    def include?(value)
      @index.key?(value)
    end

    def <<(value)
      @index[value] = true
      self
    end
  end
end

begin
rescue LoadError
  module CGI
    module_function

    def escape(text)
      value = text.to_s
      value.gsub(/[^a-zA-Z0-9_.~-]/) { |ch| "%%%02X" % ch.ord }
    end
  end
end

module Ruflet
  class Page
    include UI::ControlMethods

    PAGE_PROP_KEYS = %w[route title vertical_alignment horizontal_alignment].freeze
    DIALOG_PROP_KEYS = %w[dialog snack_bar bottom_sheet].freeze
    BUTTON_TEXT_TYPES = %w[button elevatedbutton textbutton filledbutton].freeze

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
      @dialogs = []
      @page_event_handlers = {}
      @view_props = {}
      @page_props = { "route" => (client_details["route"] || "/") }
      @overlay_container = Ruflet::Control.new(
        type: "overlay",
        id: "_overlay",
        controls: []
      )
      @dialogs_container = Ruflet::Control.new(
        type: "dialogs",
        id: "_dialogs",
        controls: []
      )
      refresh_overlay_container!
      refresh_dialogs_container!
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
      @dialog = dialog if dialog
      @snack_bar = snack_bar if snack_bar
      @bottom_sheet = bottom_sheet if bottom_sheet

      refresh_dialogs_container!
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

    def dialog = @dialog

    def dialog=(value)
      @dialog = value
      refresh_dialogs_container!
    end

    def snack_bar(**props, &block)
      return @snack_bar if props.empty? && !block

      super
    end

    def snack_bar=(value)
      @snack_bar = value
      refresh_dialogs_container!
    end

    def snackbar(**props, &block)
      snack_bar(**props, &block)
    end

    def snackbar=(value)
      self.snack_bar = value
    end

    def bottom_sheet(**props, &block)
      return @bottom_sheet if props.empty? && !block

      super
    end

    def bottom_sheet=(value)
      @bottom_sheet = value
      refresh_dialogs_container!
    end

    def bottomsheet(**props, &block)
      bottom_sheet(**props, &block)
    end

    def bottomsheet=(value)
      self.bottom_sheet = value
    end

    def show_dialog(dialog_control)
      return self unless dialog_control

      return self if dialog_open?(dialog_control)

      dialog_control.props["open"] = true
      @dialogs << dialog_control unless @dialogs.include?(dialog_control)
      refresh_dialogs_container!
      send_view_patch unless @dialogs_container.wire_id
      push_dialogs_update!
      self
    end

    def pop_dialog
      dialog_control = latest_open_dialog
      return nil unless dialog_control

      dialog_control.props["open"] = false
      refresh_dialogs_container!
      push_dialogs_update!
      dialog_control
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
      if BUTTON_TEXT_TYPES.include?(control.type) && patch.key?("text")
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

    def apply_client_update(control_or_id, props)
      control = resolve_control(control_or_id)
      return self unless control

      patch = normalize_props(props || {})
      patch.each { |k, v| control.props[k] = v }

      remove_dialog_tracking(control) if patch.key?("open") && patch["open"] == false

      self
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

      if name.to_s == "dismiss" && remove_dialog_tracking(control)
        push_dialogs_update!
      end
    end

    private

    def build_widget(type, **props, &block) = WidgetBuilder.new.control(type, **props, &block)

    def split_props(props)
      props.each do |k, v|
        assign_split_prop(k, v)
      end
    end

    def send_message(action, payload)
      @sender.call(action, payload)
    end

    def send_view_patch
      refresh_control_indexes!
      view_patches = build_view_patches
      page_patch_ops = build_page_patch_ops

      send_message(Protocol::ACTIONS[:patch_control], {
        "id" => 1,
        "patch" => [
          [0],
          [0, 0, "views", view_patches],
          *page_patch_ops
        ]
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
      @page_props.each_value { |value| register_embedded_value(value, visited) }
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
        codepoint = resolve_icon_codepoint(value)
        return codepoint unless codepoint.nil?
      end

      return value.value if value.is_a?(Ruflet::IconData)
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
      when Ruflet::IconData
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

    def refresh_dialogs_container!
      dialog_controls = (@dialogs + dialog_slots).uniq
      @dialogs_container.props["controls"] = dialog_controls
      @page_props["_dialogs"] = @dialogs_container
    end

    def refresh_overlay_container!
      @page_props["_overlay"] = @overlay_container
    end

    def push_dialogs_update!
      refresh_control_indexes!

      if @dialogs_container.wire_id
        send_message(Protocol::ACTIONS[:patch_control], {
          "id" => @dialogs_container.wire_id,
          "patch" => [[0], [0, 0, "controls", serialize_patch_value(@dialogs_container.props["controls"])]]
        })
      else
        send_view_patch
      end
    end

    def dialog_slots
      [@dialog, @snack_bar, @bottom_sheet].compact
    end

    def latest_open_dialog
      @dialogs.reverse.find { |d| d.props["open"] != false }
    end

    def dialog_open?(dialog_control)
      @dialogs.include?(dialog_control) && dialog_control.props["open"] == true
    end

    def remove_dialog_tracking(control)
      return false unless @dialogs.include?(control)

      @dialogs.delete(control)
      refresh_dialogs_container!
      true
    end

    def assign_split_prop(key, value)
      if key == "vertical_alignment" || key == "horizontal_alignment"
        @page_props[key] = value
        @view_props[key] = value
      elsif DIALOG_PROP_KEYS.include?(key)
        instance_variable_set("@#{key}", value)
        refresh_dialogs_container!
      elsif PAGE_PROP_KEYS.include?(key)
        @page_props[key] = value
      else
        @view_props[key] = value
      end
    end

    def build_view_patches
      if @views.any?
        @views.map(&:to_patch)
      else
        [implicit_view_patch]
      end
    end

    def build_page_patch_ops
      @page_props.map { |k, v| [0, 0, k, serialize_patch_value(v)] }
    end

    def resolve_icon_codepoint(value)
      codepoint = Ruflet::MaterialIconLookup.codepoint_for(value)
      if codepoint.nil? || codepoint == value
        codepoint = Ruflet::CupertinoIconLookup.codepoint_for(value)
      end
      codepoint
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/app.rb

module Ruflet
  class App
    def initialize(host: "0.0.0.0", port: 8550)
      @host = host
      @port = port
    end

    def run
      manifest_out = ENV["RUFLET_MANIFEST_OUT"].to_s
      unless manifest_out.empty?
        route = ENV["RUFLET_MANIFEST_ROUTE"].to_s
        route = "/" if route.empty?
        manifest = Ruflet::ManifestCompiler.compile_app(self, route: route)
        Ruflet::ManifestCompiler.write_file(manifest_out, manifest)
        puts manifest_out
        return manifest_out
      end

      Ruflet.run(host: @host, port: @port) do |page|
        view(page)
      end
    end

    def view(_page)
      raise NotImplementedError, "#{self.class} must implement #view(page)"
    end
  end
end


# -- packages/ruflet/lib/ruflet_ui/ruflet/dsl.rb


module Ruflet
  module DSL
    module_function

    def _pending_app
      @_pending_app ||= App.new(host: "0.0.0.0", port: 8550)
    end

    def _reset_pending_app!
      @_pending_app = App.new(host: "0.0.0.0", port: 8550)
    end

    def app(host: "0.0.0.0", port: 8550, &block)
      return App.new(host: host, port: port).tap { |a| a.instance_eval(&block) } if block

      pending = _pending_app
      pending.set_endpoint!(host: host, port: port)
      _reset_pending_app!
      pending
    end

    def page(**props, &block) = _pending_app.page(**props, &block)
    def control(type, **props, &block) = _pending_app.control(type, **props, &block)
    def widget(type, **props, &block) = _pending_app.widget(type, **props, &block)
    def column(**props, &block) = _pending_app.column(**props, &block)
    def center(**props, &block) = _pending_app.center(**props, &block)
    def row(**props, &block) = _pending_app.row(**props, &block)
    def stack(**props, &block) = _pending_app.stack(**props, &block)
    def container(**props, &block) = _pending_app.container(**props, &block)
    def gesture_detector(**props, &block) = _pending_app.gesture_detector(**props, &block)
    def gesturedetector(**props, &block) = _pending_app.gesturedetector(**props, &block)
    def draggable(**props, &block) = _pending_app.draggable(**props, &block)
    def drag_target(**props, &block) = _pending_app.drag_target(**props, &block)
    def dragtarget(**props, &block) = _pending_app.dragtarget(**props, &block)
    def text(value = nil, **props) = _pending_app.text(value, **props)
    def button(**props) = _pending_app.button(**props)
    def elevated_button(**props) = _pending_app.elevated_button(**props)
    def elevatedbutton(**props) = _pending_app.elevatedbutton(**props)
    def text_field(**props) = _pending_app.text_field(**props)
    def textfield(**props) = _pending_app.textfield(**props)
    def icon(**props) = _pending_app.icon(**props)
    def image(src = nil, **props) = _pending_app.image(src, **props)
    def icon_button(**props) = _pending_app.icon_button(**props)
    def iconbutton(**props) = _pending_app.iconbutton(**props)
    def app_bar(**props) = _pending_app.app_bar(**props)
    def appbar(**props) = _pending_app.appbar(**props)
    def text_button(**props) = _pending_app.text_button(**props)
    def textbutton(**props) = _pending_app.textbutton(**props)
    def filled_button(**props) = _pending_app.filled_button(**props)
    def filledbutton(**props) = _pending_app.filledbutton(**props)
    def checkbox(**props) = _pending_app.checkbox(**props)
    def radio(**props) = _pending_app.radio(**props)
    def radio_group(**props) = _pending_app.radio_group(**props)
    def radiogroup(**props) = _pending_app.radiogroup(**props)
    def alert_dialog(**props) = _pending_app.alert_dialog(**props)
    def alertdialog(**props) = _pending_app.alertdialog(**props)
    def snack_bar(**props) = _pending_app.snack_bar(**props)
    def snackbar(**props) = _pending_app.snackbar(**props)
    def bottom_sheet(**props) = _pending_app.bottom_sheet(**props)
    def bottomsheet(**props) = _pending_app.bottomsheet(**props)
    def markdown(value = nil, **props) = _pending_app.markdown(value, **props)
    def floating_action_button(**props) = _pending_app.floating_action_button(**props)
    def floatingactionbutton(**props) = _pending_app.floatingactionbutton(**props)
    def tabs(**props, &block) = _pending_app.tabs(**props, &block)
    def tab(**props, &block) = _pending_app.tab(**props, &block)
    def tab_bar(**props, &block) = _pending_app.tab_bar(**props, &block)
    def tabbar(**props, &block) = _pending_app.tabbar(**props, &block)
    def tab_bar_view(**props, &block) = _pending_app.tab_bar_view(**props, &block)
    def tabbarview(**props, &block) = _pending_app.tabbarview(**props, &block)
    def navigation_bar(**props, &block) = _pending_app.navigation_bar(**props, &block)
    def navigationbar(**props, &block) = _pending_app.navigationbar(**props, &block)
    def navigation_bar_destination(**props, &block) = _pending_app.navigation_bar_destination(**props, &block)
    def navigationbardestination(**props, &block) = _pending_app.navigationbardestination(**props, &block)
    def fab(content = nil, **props) = _pending_app.fab(content, **props)
    def cupertino_button(**props) = _pending_app.cupertino_button(**props)
    def cupertinobutton(**props) = _pending_app.cupertinobutton(**props)
    def cupertino_filled_button(**props) = _pending_app.cupertino_filled_button(**props)
    def cupertinofilledbutton(**props) = _pending_app.cupertinofilledbutton(**props)
    def cupertino_text_field(**props) = _pending_app.cupertino_text_field(**props)
    def cupertinotextfield(**props) = _pending_app.cupertinotextfield(**props)
    def cupertino_switch(**props) = _pending_app.cupertino_switch(**props)
    def cupertinoswitch(**props) = _pending_app.cupertinoswitch(**props)
    def cupertino_slider(**props) = _pending_app.cupertino_slider(**props)
    def cupertinoslider(**props) = _pending_app.cupertinoslider(**props)
    def cupertino_alert_dialog(**props) = _pending_app.cupertino_alert_dialog(**props)
    def cupertinoalertdialog(**props) = _pending_app.cupertinoalertdialog(**props)
    def cupertino_action_sheet(**props) = _pending_app.cupertino_action_sheet(**props)
    def cupertinoactionsheet(**props) = _pending_app.cupertinoactionsheet(**props)
    def cupertino_dialog_action(**props) = _pending_app.cupertino_dialog_action(**props)
    def cupertinodialogaction(**props) = _pending_app.cupertinodialogaction(**props)
    def cupertino_navigation_bar(**props) = _pending_app.cupertino_navigation_bar(**props)
    def cupertinonavigationbar(**props) = _pending_app.cupertinonavigationbar(**props)

    class App
      include UI::ControlMethods

      attr_reader :page_props, :host, :port

      def initialize(host:, port:)
        @host = host
        @port = port
        @roots = []
        @stack = []
        @page_props = { "route" => "/" }
        @seq = 0
      end

      def set_endpoint!(host:, port:)
        @host = host
        @port = port
      end

      def page(**props, &block)
        @page_props.merge!(normalize_props(props))
        instance_eval(&block) if block
        self
      end

      def widget(type, **props, &block)
        control(type.to_s, **props, &block)
      end

      def control(type, **props, &block)
        mapped_props = props.dup
        prop_children = mapped_props.delete(:controls) || mapped_props.delete("controls")

        id = mapped_props.delete(:id)&.to_s || next_id(type)
        c = Ruflet::UI::ControlFactory.build(type.to_s, id: id, **normalize_props(mapped_props))
        attach(c)

        if block
          @stack.push(c)
          instance_eval(&block)
          @stack.pop
        end

        if prop_children
          Array(prop_children).each { |child| c.children << child if child.is_a?(Ruflet::Control) }
        end

        c
      end

      def run
        app_roots = @roots
        page_props = @page_props.dup

        Ruflet::Server.new(host: host, port: port) do |runtime_page|
          runtime_page.set_view_props(page_props)
          runtime_page.add(*app_roots)
        end.start
      end

      private

      def build_widget(type, **props, &block) = control(type.to_s, **props, &block)

      def attach(control)
        if @stack.empty?
          @roots << control
        else
          @stack.last.children << control
        end
      end

      def normalize_props(hash)
        hash.transform_keys(&:to_s).transform_values { |v| v.is_a?(Symbol) ? v.to_s : v }
      end

      def next_id(type)
        @seq += 1
        "#{type}_#{@seq}"
      end

    end
  end
end


# -- packages/ruflet/lib/ruflet_ui.rb


module Ruflet
  module MainAxisAlignment
    CENTER = "center"
    START = "start"
    FINISH = "end"
    SPACE_BETWEEN = "spaceBetween"
    SPACE_AROUND = "spaceAround"
    SPACE_EVENLY = "spaceEvenly"
  end

  module CrossAxisAlignment
    CENTER = "center"
    START = "start"
    FINISH = "end"
    STRETCH = "stretch"
  end

  module TextAlign
    LEFT = "left"
    RIGHT = "right"
    CENTER = "center"
    JUSTIFY = "justify"
    START = "start"
    FINISH = "end"
  end

  module Icons
    class << self
      def const_missing(name)
        if Ruflet::MaterialIcons.const_defined?(name, false)
          return Ruflet::MaterialIcons.const_get(name)
        end

        if Ruflet::CupertinoIcons.const_defined?(name, false)
          return Ruflet::CupertinoIcons.const_get(name)
        end

        super
      end

      def [](name)
        key = name.to_s.upcase.to_sym
        return Ruflet::MaterialIcons.const_get(key) if Ruflet::MaterialIcons.const_defined?(key, false)
        return Ruflet::CupertinoIcons.const_get(key) if Ruflet::CupertinoIcons.const_defined?(key, false)

        Ruflet::IconData.new(name.to_s)
      end
    end
  end

  class << self
    include UI::SharedControlForwarders

    def app(host: "0.0.0.0", port: 8550, &block)
      DSL.app(host: host, port: port, &block)
    end

    private

    def control_delegate
      WidgetBuilder.new
    end
  end

  module UI
    class << self
      include SharedControlForwarders

      def app(**opts, &block) = Ruflet.app(**opts, &block)
      def page(**props, &block) = Ruflet::DSL.page(**props, &block)

      private

      def control_delegate
        Ruflet::DSL
      end
    end
  end
end

module Kernel
  include Ruflet::UI::SharedControlForwarders

  private

  def app(**opts, &block) = Ruflet::DSL.app(**opts, &block)
  def page(**props, &block) = Ruflet::DSL.page(**props, &block)

  def control_delegate
    Ruflet::DSL
  end

  private(*Ruflet::UI::SharedControlForwarders.instance_methods(false))
end


# -- Ruflet MRuby Server
module Ruflet
  class WireCodec
    class << self
      def pack(value)
        case value
        when NilClass then "\xc0"
        when TrueClass then "\xc3"
        when FalseClass then "\xc2"
        when Integer then pack_integer(value)
        when Float then "\xcb" + [value].pack("G")
        when String then pack_string(value)
        when Symbol then pack_string(value.to_s)
        when Array then pack_array(value)
        when Hash then pack_map(value)
        else pack_string(value.to_s)
        end
      end

      def unpack(bytes)
        reader = ByteReader.new(bytes)
        read_value(reader)
      end

      private

      def pack_integer(value)
        if value >= 0
          return [value].pack("C") if value <= 0x7f
          return "\xcc" + [value].pack("C") if value <= 0xff
          return "\xcd" + [value].pack("n") if value <= 0xffff
          return "\xce" + [value].pack("N") if value <= 0xffff_ffff
          "\xcf" + [value].pack("Q>")
        else
          return [value & 0xff].pack("C") if value >= -32
          return "\xd0" + [value].pack("c") if value >= -128
          return "\xd1" + [value].pack("s>") if value >= -32_768
          return "\xd2" + [value].pack("l>") if value >= -2_147_483_648
          "\xd3" + [value].pack("q>")
        end
      end

      def pack_string(value)
        str = value.to_s
        len = str.bytesize
        if len <= 31
          [0xA0 | len].pack("C") + str
        elsif len <= 0xff
          "\xd9" + [len].pack("C") + str
        elsif len <= 0xffff
          "\xda" + [len].pack("n") + str
        else
          "\xdb" + [len].pack("N") + str
        end
      end

      def pack_array(value)
        len = value.length
        head = if len <= 15
                 [0x90 | len].pack("C")
               elsif len <= 0xffff
                 "\xdc" + [len].pack("n")
               else
                 "\xdd" + [len].pack("N")
               end
        body = ""
        value.each { |item| body += pack(item) }
        head + body
      end

      def pack_map(value)
        pairs = {}
        value.each { |k, v| pairs[k.to_s] = v }
        len = pairs.length
        head = if len <= 15
                 [0x80 | len].pack("C")
               elsif len <= 0xffff
                 "\xde" + [len].pack("n")
               else
                 "\xdf" + [len].pack("N")
               end
        body = ""
        pairs.each do |k, v|
          body += pack(k)
          body += pack(v)
        end
        head + body
      end

      def read_value(reader)
        marker = reader.read_u8
        return marker if marker <= 0x7f
        return marker - 256 if marker >= 0xe0
        case marker
        when 0xc0 then nil
        when 0xc2 then false
        when 0xc3 then true
        when 0xcc then reader.read_u8
        when 0xcd then reader.read_u16
        when 0xce then reader.read_u32
        when 0xcf then reader.read_u64
        when 0xd0 then reader.read_i8
        when 0xd1 then reader.read_i16
        when 0xd2 then reader.read_i32
        when 0xd3 then reader.read_i64
        when 0xca then reader.read_f32
        when 0xcb then reader.read_f64
        when 0xd9 then reader.read_string(reader.read_u8)
        when 0xda then reader.read_string(reader.read_u16)
        when 0xdb then reader.read_string(reader.read_u32)
        when 0xdc then read_array(reader, reader.read_u16)
        when 0xdd then read_array(reader, reader.read_u32)
        when 0xde then read_map(reader, reader.read_u16)
        when 0xdf then read_map(reader, reader.read_u32)
        else
          if (marker & 0xf0) == 0x90
            read_array(reader, marker & 0x0f)
          elsif (marker & 0xf0) == 0x80
            read_map(reader, marker & 0x0f)
          elsif (marker & 0xe0) == 0xa0
            reader.read_string(marker & 0x1f)
          else
            raise "Unsupported MessagePack marker: 0x#{marker.to_s(16)}"
          end
        end
      end

      def read_array(reader, size)
        out = []
        i = 0
        while i < size
          out << read_value(reader)
          i += 1
        end
        out
      end

      def read_map(reader, size)
        out = {}
        i = 0
        while i < size
          key = read_value(reader)
          out[key.to_s] = read_value(reader)
          i += 1
        end
        out
      end
    end

    class ByteReader
      def initialize(bytes)
        @data = bytes.to_s
        @offset = 0
      end

      def read_u8
        value = @data.getbyte(@offset)
        raise "Unexpected EOF" if value.nil?
        @offset += 1
        value
      end

      def read_exact(size)
        chunk = @data[@offset, size]
        raise "Unexpected EOF" if chunk.nil? || chunk.bytesize != size
        @offset += size
        chunk
      end

      def read_u16; read_exact(2).unpack("n").first; end
      def read_u32; read_exact(4).unpack("N").first; end
      def read_u64; read_exact(8).unpack("Q>").first; end
      def read_i8; read_exact(1).unpack("c").first; end
      def read_i16; read_exact(2).unpack("s>").first; end
      def read_i32; read_exact(4).unpack("l>").first; end
      def read_i64; read_exact(8).unpack("q>").first; end
      def read_f32; read_exact(4).unpack("g").first; end
      def read_f64; read_exact(8).unpack("G").first; end
      def read_string(size); read_exact(size); end
    end
  end

  class WebSocketConnection
    def initialize(socket)
      @socket = socket
    end

    def session_key
      @socket.object_id
    end

    def send_binary(payload)
      send_frame(0x2, payload.to_s)
    end

    def read_message
      frame = read_frame
      return nil if frame.nil?
      opcode = frame[:opcode]
      payload = frame[:payload]
      return close if opcode == 0x8
      return read_message if opcode == 0x9 && (send_frame(0xA, payload) || true)
      return read_message if opcode == 0xA
      return payload if opcode == 0x1 || opcode == 0x2
      read_message
    end

    def close
      @socket.close
    rescue StandardError
      nil
    end

    private

    def read_frame
      header = read_exact(2)
      return nil if header.nil?
      b1 = header.getbyte(0)
      b2 = header.getbyte(1)
      masked = (b2 & 0x80) != 0
      payload_len = b2 & 0x7f
      payload_len = read_exact(2).unpack("n").first if payload_len == 126
      payload_len = read_exact(8).unpack("Q>").first if payload_len == 127
      masking_key = masked ? read_exact(4) : nil
      payload = payload_len == 0 ? "" : read_exact(payload_len)
      return nil if payload.nil?
      payload = unmask(payload, masking_key) if masked
      { opcode: (b1 & 0x0f), payload: payload }
    end

    def send_frame(opcode, payload)
      bytes = payload.to_s
      len = bytes.bytesize
      header = [0x80 | (opcode & 0x0f)].pack("C")
      if len <= 125
        header += [len].pack("C")
      elsif len <= 0xffff
        header += [126].pack("C") + [len].pack("n")
      else
        header += [127].pack("C") + [len].pack("Q>")
      end
      @socket.write(header)
      @socket.write(bytes) unless bytes.empty?
    end

    def unmask(payload, mask)
      out = ""
      i = 0
      max = payload.bytesize
      while i < max
        out += [(payload.getbyte(i) ^ mask.getbyte(i % 4))].pack("C")
        i += 1
      end
      out
    end

    def read_exact(length)
      chunk = ""
      while chunk.bytesize < length
        part = @socket.read(length - chunk.bytesize)
        return nil if part.nil? || part.empty?
        chunk += part
      end
      chunk
    end
  end

  class Server
    WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    def initialize(host: "0.0.0.0", port: 8550, &app_block)
      @host = host
      @port = port
      @app_block = app_block
      @sessions = {}
      @running = false
      @server_socket = nil
    end

    def start
      @server_socket = TCPServer.new(@host, @port)
      @running = true
      while @running
        socket = @server_socket.accept
        handle_socket(socket) if socket
      end
    rescue Interrupt
      nil
    ensure
      stop
    end

    def stop
      @running = false
      @server_socket.close if @server_socket
      @server_socket = nil
    rescue StandardError
      nil
    end

    private

    def handle_socket(socket)
      ws = nil
      begin
        path, headers = read_http_upgrade_request(socket)
        return unless websocket_upgrade_request?(path, headers)
        send_handshake_response(socket, headers["sec-websocket-key"])
        ws = Ruflet::WebSocketConnection.new(socket)
        while (raw = ws.read_message)
          action, payload = decode_incoming(raw)
          payload ||= {}
          case action
          when Protocol::ACTIONS[:register_client], Protocol::ACTIONS[:register_web_client]
            on_register_client(ws, payload)
          when Protocol::ACTIONS[:control_event], Protocol::ACTIONS[:page_event_from_web]
            on_control_event(ws, payload)
          when Protocol::ACTIONS[:update_control], Protocol::ACTIONS[:update_control_props]
            on_update_control(ws, payload)
          end
        end
      rescue StandardError
        nil
      ensure
        ws.close if ws
        socket.close if socket
      end
    end

    def read_http_upgrade_request(socket)
      request_line = socket.gets("\r\n")
      raise "Invalid HTTP request" if request_line.nil?
      method, path, = request_line.strip.split(" ", 3)
      raise "Unsupported HTTP method: #{method}" unless method == "GET"
      headers = {}
      loop do
        line = socket.gets("\r\n")
        break if line.nil? || line == "\r\n"
        key, value = line.split(":", 2)
        next if key.nil? || value.nil?
        headers[key.strip.downcase] = value.strip
      end
      [path, headers]
    end

    def websocket_upgrade_request?(path, headers)
      return false unless path == "/ws"
      return false unless headers["upgrade"] && headers["upgrade"].downcase == "websocket"
      return false unless headers["connection"] && headers["connection"].downcase.index("upgrade")
      return false if headers["sec-websocket-key"].to_s.empty?
      true
    end

    def send_handshake_response(socket, key)
      accept = [sha1_digest("#{key}#{WEBSOCKET_GUID}")].pack("m0")
      socket.write("HTTP/1.1 101 Switching Protocols\r\n")
      socket.write("Upgrade: websocket\r\n")
      socket.write("Connection: Upgrade\r\n")
      socket.write("Sec-WebSocket-Accept: #{accept}\r\n")
      socket.write("\r\n")
    end

    def decode_incoming(raw)
      parsed = Ruflet::WireCodec.unpack(raw.to_s)
      if parsed.is_a?(Array) && parsed.length >= 2
        [parsed[0], parsed[1]]
      elsif parsed.is_a?(Hash)
        [parsed["action"], parsed["payload"]]
      else
        [nil, nil]
      end
    end

    def on_register_client(ws, payload)
      normalized = Protocol.normalize_register_payload(payload)
      session_id = normalized["session_id"].to_s.empty? ? "ruflet-#{rand(0xffffffff).to_s(16)}" : normalized["session_id"]

      page = Ruflet::Page.new(
        session_id: session_id,
        client_details: normalized,
        sender: lambda { |action, data| ws.send_binary(Ruflet::WireCodec.pack([action, data])) }
      )
      @sessions[ws.session_key] = page

      initial = [Protocol::ACTIONS[:register_client], Protocol.register_response(session_id: session_id)]
      ws.send_binary(Ruflet::WireCodec.pack(initial))
      @app_block.call(page) if @app_block
      page.update
    end

    def on_control_event(ws, payload)
      page = @sessions[ws.session_key]
      return unless page
      event = Protocol.normalize_control_event_payload(payload)
      return if event["target"].nil? || event["name"].to_s.empty?
      page.dispatch_event(target: event["target"], name: event["name"], data: event["data"])
    end

    def on_update_control(ws, payload)
      page = @sessions[ws.session_key]
      return unless page
      update = Protocol.normalize_update_control_payload(payload)
      return if update["id"].nil?
      page.apply_client_update(update["id"], update["props"] || {})
    end

    def sha1_digest(data)
      bytes = data.to_s
      bit_len = bytes.bytesize * 8
      bytes += "\x80"
      bytes += "\x00" while (bytes.bytesize % 64) != 56
      hi = (bit_len >> 32) & 0xffffffff
      lo = bit_len & 0xffffffff
      bytes += [hi, lo].pack("N2")

      h0 = 0x67452301
      h1 = 0xEFCDAB89
      h2 = 0x98BADCFE
      h3 = 0x10325476
      h4 = 0xC3D2E1F0

      idx = 0
      while idx < bytes.bytesize
        chunk = bytes[idx, 64]
        idx += 64
        c = chunk.bytes
        w = Array.new(80, 0)
        i = 0
        while i < 16
          j = i * 4
          w[i] = ((c[j] << 24) | (c[j + 1] << 16) | (c[j + 2] << 8) | c[j + 3]) & 0xffffffff
          i += 1
        end
        while i < 80
          v = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]
          w[i] = ((v << 1) | (v >> 31)) & 0xffffffff
          i += 1
        end
        a = h0
        b = h1
        c2 = h2
        d = h3
        e = h4
        i = 0
        while i < 80
          if i < 20
            f = ((b & c2) | ((~b) & d)) & 0xffffffff
            k = 0x5A827999
          elsif i < 40
            f = (b ^ c2 ^ d) & 0xffffffff
            k = 0x6ED9EBA1
          elsif i < 60
            f = ((b & c2) | (b & d) | (c2 & d)) & 0xffffffff
            k = 0x8F1BBCDC
          else
            f = (b ^ c2 ^ d) & 0xffffffff
            k = 0xCA62C1D6
          end
          temp = ((((a << 5) | (a >> 27)) & 0xffffffff) + f + e + k + w[i]) & 0xffffffff
          e = d
          d = c2
          c2 = ((b << 30) | (b >> 2)) & 0xffffffff
          b = a
          a = temp
          i += 1
        end
        h0 = (h0 + a) & 0xffffffff
        h1 = (h1 + b) & 0xffffffff
        h2 = (h2 + c2) & 0xffffffff
        h3 = (h3 + d) & 0xffffffff
        h4 = (h4 + e) & 0xffffffff
      end
      [h0, h1, h2, h3, h4].pack("N5")
    end
  end

  module_function

  def run(entrypoint = nil, host: "0.0.0.0", port: 8550, &block)
    callback = entrypoint || block
    raise ArgumentError, "Ruflet.run requires a callable entrypoint or block" unless callback.respond_to?(:call)
    Server.new(host: host, port: port) { |page| callback.call(page) }.start
  end
end

# -- App Entry
class MainApp < Ruflet::App
  def view(page)
    page.title = "Navigation: Go + Replace"

    page.on_route_change = ->(_e) { render(page) }
    page.on_view_pop = ->(_e) { handle_back(page) }

    render(page)
  end

  private

  def render(page)
    route = route_path(page.route)

    if route == "/replace"
      page.views = [replace_view(page)]
    elsif route == "/go"
      # Keep Home in stack so back navigation returns to Home.
      page.views = [home_view(page), go_view(page)]
    else
      page.views = [home_view(page)]
    end

    page.update
  end

  def handle_back(page)
    # Replace flow keeps single-page stack; back always returns home.
    page.go("/")
  end

  def home_view(page)
    page.view(
      route: "/",
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: "Home", size: 18)
      ),
      padding: 16,
      controls: [
        page.text(value: "Home Screen", size: 24),
        page.text(value: "Tap to go to Replace screen using page.go()."),
        page.button(
          text: "Go to Go Screen (with back nav)",
          on_click: ->(_e) { page.go("/go", nav: "go") }
        ),
        page.button(
          text: "Go to Replace",
          on_click: ->(_e) { page.go("/replace", nav: "go") }
        )
      ]
    )
  end

  def replace_view(page)
    page.view(
      route: "/replace",
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: "Replace", size: 18)
      ),
      padding: 16,
      controls: [
        page.text(value: "Replace Screen", size: 24),
        page.text(value: "Current route: #{page.route}"),
        page.text(value: "Use replace below to return Home without back stack."),
        page.button(
          text: "Replace with Home",
          on_click: ->(_e) { page.go("/", nav: "replace") }
        )
      ]
    )
  end

  def go_view(page)
    page.view(
      route: "/go",
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: "Go Screen", size: 18)
      ),
      padding: 16,
      controls: [
        page.text(value: "Go Screen", size: 24),
        page.text(value: "Opened via page.go('/go')."),
        page.text(value: "Back navigation should return to Home."),
        page.button(
          text: "Go Back Home",
          on_click: ->(_e) { page.go("/", nav: "go") }
        )
      ]
    )
  end

  def route_path(route)
    route.to_s.split("?").first
  end
end

MainApp.new.run


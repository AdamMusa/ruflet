# frozen_string_literal: true

module Ruflet
  # Work the client performs itself the moment a control is tapped, before it
  # sends the click to Ruby (Flet 1.0's ClientAction).
  #
  # Browsers only let a page write to the clipboard, open a new tab, show a
  # file picker or the share sheet while they are still handling the user's
  # tap. A click handler in Ruby answers after that permission has lapsed, so
  # `page.launch_url`, `page.set_clipboard`, `page.pick_files` and
  # `page.share_text` called from `on_click` are silently dropped on the web
  # (on iOS Safari above all). Attach the action to the control instead:
  #
  #   button("Docs", action: Ruflet.client_action(:launch_url, url: "https://ruflet.dev",
  #                                                             web_window_name: "_blank"))
  #   icon_button(icon: "copy", action: Ruflet.client_action(:copy_to_clipboard, text: token))
  #   button("Upload", action: Ruflet.client_action(:pick_files, allow_multiple: true),
  #                    on_action_result: ->(e) { e.files })
  #
  # A control takes one action or a list of them; the client starts them in
  # order inside the tap and then sends `click` as usual. Each action's
  # outcome comes back as the control's `on_action_result` event (see
  # Events::ActionResultEvent): the picked files, the share status, or the
  # error the client hit. Arguments must be known before the tap.
  #
  # On the wire an action is the plain hash Flet sends, with the service
  # named by its wire type instead of a page-scoped id:
  #   { "service" => "UrlLauncher", "method" => "launch_url",
  #     "args" => { "url" => "https://ruflet.dev", "web_only_window_name" => "_blank" } }
  # `args` are exactly what the matching page method sends to that service.
  class ClientAction
    FILE_TYPES = %w[any media image video audio custom].freeze
    LAUNCH_MODES = %w[
      platform_default in_app_web_view in_app_browser_view
      external_application external_non_browser_application
    ].freeze

    # Ruby name => the service method that performs it, and each Ruby option
    # with the wire argument it becomes and how it is checked.
    ACTIONS = {
      "launch_url" => {
        service: "UrlLauncher", method: "launch_url", required: %w[url],
        options: { "url" => %w[url url], "web_window_name" => %w[web_only_window_name string],
                   "mode" => %w[mode launch_mode] }
      },
      "copy_to_clipboard" => {
        service: "Clipboard", method: "set", required: %w[text],
        options: { "text" => %w[data text] }
      },
      "pick_files" => {
        service: "FilePicker", method: "pick_files", required: [],
        defaults: { "file_type" => "any", "allow_multiple" => false, "with_data" => false },
        options: { "dialog_title" => %w[dialog_title string], "initial_directory" => %w[initial_directory string],
                   "file_type" => %w[file_type file_type], "allowed_extensions" => %w[allowed_extensions extensions],
                   "allow_multiple" => %w[allow_multiple boolean], "with_data" => %w[with_data boolean] }
      },
      "share_text" => {
        service: "Share", method: "share_text", required: %w[text],
        options: { "text" => %w[text string], "title" => %w[title string], "subject" => %w[subject string] }
      },
      "share_uri" => {
        service: "Share", method: "share_uri", required: %w[uri],
        options: { "uri" => %w[uri url] }
      },
      "share_files" => {
        service: "Share", method: "share_files", required: %w[files],
        options: { "files" => %w[files files], "text" => %w[text string], "title" => %w[title string],
                   "subject" => %w[subject string] }
      }
    }.freeze

    # Flet's and the page methods' spellings of the same actions and options.
    TYPE_ALIASES = { "open_url" => "launch_url", "set_clipboard" => "copy_to_clipboard" }.freeze
    OPTION_ALIASES = {
      "launch_url" => { "target" => "web_window_name", "web_only_window_name" => "web_window_name" },
      "copy_to_clipboard" => { "data" => "text", "value" => "text" }
    }.freeze

    attr_reader :type, :options

    class << self
      # The wire value of a control's `action`: one action hash, or a list of
      # them. Takes ClientAction objects, `{ type: :launch_url, url: ... }`
      # hashes and wire hashes (what a control's props hold), alone or in an
      # Array. Raises ArgumentError on anything else.
      def wire(value)
        return nil if value.nil?
        if value.is_a?(Array)
          raise ArgumentError, "action list must not be empty" if value.empty?

          return value.map { |item| coerce(item).to_h }
        end

        coerce(value).to_h
      end

      def coerce(value)
        return value if value.is_a?(ClientAction)
        unless value.is_a?(Hash)
          raise ArgumentError,
                "action must be a Ruflet.client_action(...), a Hash or an Array of them, not #{value.inspect}"
        end

        options = value.each_with_object({}) { |(key, item), out| out[key.to_s] = item }
        return from_wire(options) if options.key?("service")

        type = options.delete("type")
        raise ArgumentError, "action Hash needs a :type (one of #{ACTIONS.keys.join(", ")})" if type.nil?

        new(type, **options.each_with_object({}) { |(key, item), out| out[key.to_sym] = item })
      end

      # The Ruby name of the action a service method performs ("pick_files"
      # for FilePicker.pick_files), or nil.
      def type_for(service, method)
        ACTIONS.each { |name, spec| return name if spec[:service] == service.to_s && spec[:method] == method.to_s }
        nil
      end

      private

      def from_wire(hash)
        type = type_for(hash["service"], hash["method"])
        if type.nil?
          raise ArgumentError, "action #{hash["service"]}.#{hash["method"]} is not a client action"
        end

        args = hash["args"] || {}
        raise ArgumentError, "action args must be a Hash, not #{args.inspect}" unless args.is_a?(Hash)

        by_arg = ACTIONS[type][:options].each_with_object({}) { |(option, check), out| out[check[0]] = option }
        options = args.each_with_object({}) do |(arg, item), out|
          option = by_arg[arg.to_s]
          raise ArgumentError, "unknown argument #{arg.inspect} for client action :#{type}" if option.nil?

          out[option.to_sym] = item
        end
        new(type, **options)
      end
    end

    def initialize(type, **options)
      name = type.to_s
      name = TYPE_ALIASES.fetch(name, name)
      @spec = ACTIONS[name]
      if @spec.nil?
        raise ArgumentError, "unknown client action #{type.inspect} (expected one of #{ACTIONS.keys.join(", ")})"
      end

      @type = name
      @options = normalize_options(options)
      freeze
    end

    def service = @spec[:service]
    def method_name = @spec[:method]

    # The arguments the service method receives on the client.
    def args
      result = {}
      (@spec[:defaults] || {}).each { |arg, value| result[arg] = value }
      @spec[:options].each do |option, check|
        result[check[0]] = @options[option] if @options.key?(option)
      end
      result
    end

    def to_h
      { "service" => service, "method" => method_name, "args" => args }
    end

    def ==(other)
      other.is_a?(ClientAction) && other.to_h == to_h
    end
    alias eql? ==

    def hash = to_h.hash

    def inspect = "#<Ruflet::ClientAction #{@type} #{@options.inspect}>"

    private

    def normalize_options(options)
      aliases = OPTION_ALIASES.fetch(@type, {})
      normalized = {}
      options.each do |key, value|
        option = key.to_s
        option = aliases.fetch(option, option)
        check = @spec[:options][option]
        raise ArgumentError, "unknown keyword :#{key} for client action :#{@type}" if check.nil?
        if normalized.key?(option)
          raise ArgumentError, "client action :#{@type} got :#{option} twice (through an alias)"
        end
        next if value.nil?

        normalized[option] = check_value(option, check[1], value)
      end
      @spec[:required].each do |option|
        raise ArgumentError, "client action :#{@type} requires :#{option}" unless normalized.key?(option)
      end
      normalized
    end

    def check_value(option, kind, value)
      case kind
      when "url"
        return value if value.is_a?(String) && !value.strip.empty?

        invalid(option, "a non-empty String", value)
      when "string"
        return value if value.is_a?(String)
        return value.to_s if value.is_a?(Symbol)

        invalid(option, "a String", value)
      when "text"
        return value.to_s unless value.is_a?(Hash) || value.is_a?(Array)

        invalid(option, "text", value)
      when "boolean"
        return value if value == true || value == false

        invalid(option, "true or false", value)
      when "launch_mode"
        mode = enum_name(value)
        return mode if !mode.nil? && LAUNCH_MODES.any? { |name| name.delete("_") == mode.delete("_") }

        invalid(option, "one of #{LAUNCH_MODES.join(", ")}", value)
      when "file_type"
        type = enum_name(value)
        return type if !type.nil? && FILE_TYPES.include?(type)

        invalid(option, "one of #{FILE_TYPES.join(", ")}", value)
      when "extensions"
        if value.is_a?(Array) && value.all? { |ext| ext.is_a?(String) || ext.is_a?(Symbol) }
          return value.map(&:to_s)
        end

        invalid(option, "an Array of Strings", value)
      when "files"
        return value.map { |file| share_file(file) } if value.is_a?(Array) && !value.empty?
        return [share_file(value)] if value.is_a?(String) || value.is_a?(Hash)

        invalid(option, "a path, a file Hash or a non-empty Array of them", value)
      else
        value
      end
    end

    def enum_name(value)
      return nil unless value.is_a?(String) || value.is_a?(Symbol)

      value.to_s.downcase
    end

    # A file to share: a path, or { path:/data:, name:, mime_type: } as
    # page.share_files takes it. Byte arrays become a binary String.
    def share_file(file)
      return { "path" => file } if file.is_a?(String) && !file.empty?
      unless file.is_a?(Hash)
        raise ArgumentError, "client action :share_files file must be a path or a Hash, not #{file.inspect}"
      end

      entry = file.each_with_object({}) do |(key, value), out|
        name = key.to_s
        unless %w[path data name mime_type].include?(name)
          raise ArgumentError, "unknown file key :#{name} for client action :share_files"
        end
        next if value.nil?

        out[name] = name == "data" && byte_array?(value) ? value.pack("C*").b : value
      end
      unless entry.key?("path") || entry.key?("data")
        raise ArgumentError, "client action :share_files file needs :path or :data"
      end

      entry
    end

    def byte_array?(value)
      value.is_a?(Array) && value.all? { |item| item.is_a?(Integer) && item >= 0 && item <= 255 }
    end

    def invalid(option, expected, value)
      raise ArgumentError, "client action :#{@type} :#{option} must be #{expected}, not #{value.inspect}"
    end
  end
end

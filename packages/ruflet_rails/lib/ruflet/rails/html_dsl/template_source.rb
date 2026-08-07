# frozen_string_literal: true

require "uri"

module Ruflet
  module Rails
    module HtmlDsl
      # The ERB file as the app.
      #
      # A normal Ruflet app is a Ruby file: handlers run in the session, mutate
      # state, and the page diffs and patches over the WebSocket. This puts an
      # ERB file in that slot. Templates under app/views describe the screen,
      # and a tap calls a method on the developer's own controller — directly,
      # in the session — after which the template re-renders and only the
      # changed controls are patched.
      #
      # There is no request: no routing, no middleware, no Rack env, and so no
      # "Started POST … Completed 200 OK" per tap. What that costs is the parts
      # of Rails that only exist because of a request — `session`, `flash`,
      # `cookies` and CSRF. State lives where a Ruflet app keeps it instead: in
      # the controller instance, which is held for the life of the session, so
      # an ordinary `@count` survives from one tap to the next.
      #
      # It satisfies the same interface as RackFetcher, so HtmlApp's
      # navigation, diffing, forms and services all work unchanged.
      class TemplateSource
        Response = RackFetcher::Response

        def initialize(view_paths: nil, layout: nil)
          @view_paths = view_paths
          @layout = layout
          @controllers = {}
        end

        def fetch(method, url, params: nil, headers: {})
          path = URI.parse(url.to_s).path.to_s
          screen = NativeScreens.resolve(path)
          return missing(url, path) unless screen

          controller = controller_for(screen[:controller])
          assign_params(controller, params, screen[:params])
          invoke(controller, screen[:action])

          Response.new(status: 200, body: render(screen, controller), url: url)
        rescue StandardError => e
          Response.new(status: 500, body: failure_markup(path, e), url: url)
        end

        private

        # One instance per controller class, for the life of the session. This
        # is what makes `@count` behave the way a local in a Ruflet Ruby app
        # does: it is simply still there on the next tap.
        def controller_for(klass)
          @controllers[klass] ||= build_controller(klass)
        end

        def build_controller(klass)
          instance = klass.new
          instance.singleton_class.include(ScreenContext)
          instance
        end

        def invoke(controller, action)
          return unless controller.respond_to?(action, true)

          controller.send(action)
        end

        # Params arrive from a form's fields and from trailing path segments
        # (/native/device/camera), not from a Rack env.
        def assign_params(controller, form_params, path_params)
          values = {}
          Array(path_params).each_with_index { |value, index| values[index.zero? ? "id" : "param#{index}"] = value }
          values["feature"] = path_params.first if path_params.respond_to?(:first) && path_params.first
          (form_params || {}).each { |key, value| values[key.to_s] = value }
          controller.ruflet_screen_params =
            if defined?(::ActiveSupport::HashWithIndifferentAccess)
              ::ActiveSupport::HashWithIndifferentAccess.new(values)
            else
              values
            end
        end

        # The screen a method belongs to. `counter_increment` has no template of
        # its own, so it re-renders `counter` — the screen the button was on.
        def render(screen, controller)
          name = template_for(screen)
          raise "No template for #{screen[:controller]}##{screen[:action]}" unless name

          # A fresh lookup context per render: partials in a screen
          # ("render \"nav\"") resolve relative to the controller's own view
          # folder, and a shared, mutated one leaks compiled partial methods
          # between view instances.
          lookup = build_lookup_context([controller_path(screen[:controller])])
          view = view_class.new(lookup, assigns_for(controller), nil)
          # The app's own helpers (ApplicationHelper and any controller-specific
          # ones) are what a screen reaches for as readily as the DSL's tags.
          helpers = screen[:controller].try(:_helpers)
          view.extend(helpers) if helpers
          view.render(template: name, layout: @layout)
        end

        def template_for(screen)
          prefix = controller_path(screen[:controller])
          candidates_for(screen[:action]).each do |action|
            name = "#{prefix}/#{action}"
            return name if lookup_context.exists?(action, [prefix])
          end
          nil
        end

        # counter_increment -> counter_increment, counter
        def candidates_for(action)
          parts = action.to_s.split("_")
          parts.length.downto(1).map { |take| parts.first(take).join("_") }
        end

        def controller_path(klass)
          klass.respond_to?(:controller_path) ? klass.controller_path : klass.name.sub(/Controller\z/, "").downcase
        end

        def assigns_for(controller)
          controller.instance_variables.each_with_object({}) do |name, out|
            key = name.to_s.delete_prefix("@")
            next if key.start_with?("ruflet_screen")

            out[key] = controller.instance_variable_get(name)
          end
        end

        # One view class for the session: a template compiles its partials into
        # the class that rendered it, so a fresh class per render leaves those
        # methods behind on the previous one.
        def view_class
          @view_class ||= ActionView::Base.with_empty_template_cache
        end

        def build_lookup_context(prefixes = [])
          ActionView::LookupContext.new(@view_paths || ::ActionController::Base.view_paths, {}, prefixes)
        end

        def lookup_context
          @lookup_context ||= build_lookup_context
        end

        def missing(url, path)
          Response.new(status: 404, body: <<~HTML, url: url)
            <column class="p-6 gap-2">
              <h3>No screen for #{ERB::Util.html_escape(path)}</h3>
              <text class="text-slate-500">No controller action matches this path.</text>
            </column>
          HTML
        end

        def failure_markup(path, error)
          <<~HTML
            <column class="p-6 gap-2">
              <h3>Screen failed</h3>
              <text class="text-slate-500">#{ERB::Util.html_escape(path)}</text>
              <text class="text-red-600">#{ERB::Util.html_escape("#{error.class}: #{error.message}")}</text>
            </column>
          HTML
        end

        # Gives a plain controller instance the few things a screen needs
        # without a request behind it.
        module ScreenContext
          attr_writer :ruflet_screen_params

          def params
            @ruflet_screen_params ||= {}
          end

          # There is no request, so a native screen is all there is.
          def ruflet_native_request?
            true
          end
        end
      end
    end
  end
end

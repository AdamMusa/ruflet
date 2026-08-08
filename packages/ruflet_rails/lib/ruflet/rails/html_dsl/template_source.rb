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
      class TemplateSource
        Response = Struct.new(:status, :body, :url, keyword_init: true)

        def initialize(view_paths: nil, layout: nil)
          @view_paths = view_paths
          @layout = layout
          @controllers = {}
          @session = indifferent({})
          @templates = {}
          @lookups = {}
        end

        def fetch(_method, url, params: nil)
          path = URI.parse(url.to_s).path.to_s
          screen = NativeScreens.resolve(path)
          return missing(url, path) unless screen

          controller = controller_for(screen[:controller])
          assign_params(controller, params, screen[:params])
          invoke(controller, screen[:action])

          # An action like #counter_increment changes state and then re-renders
          # counter.html.erb, whose ivars only #counter assigns. Without running
          # the screen's own action the template redraws from whatever the last
          # visit left behind — the tap works and the screen never moves.
          own = template_action(screen)
          invoke(controller, own) if own && own != screen[:action].to_s

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
          # One session for the connection, shared by every screen in it. A
          # controller keeps `session[:count]` working with no request behind
          # it, and screens can hand state to each other as they always have.
          instance.ruflet_screen_session = @session
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
          controller.ruflet_screen_params = indifferent(values)
        end

        def indifferent(values)
          return values unless defined?(::ActiveSupport::HashWithIndifferentAccess)

          ::ActiveSupport::HashWithIndifferentAccess.new(values)
        end

        # The screen a method belongs to. `counter_increment` has no template of
        # its own, so it re-renders `counter` — the screen the button was on.
        # Rendering the compiled template directly, rather than through
        # `view.render(template:)`, measures about four times faster: the long
        # way re-resolves the template and fires the render instrumentation on
        # every tap, and a screen re-renders on every tap.
        def render(screen, controller)
          prefix = controller_path(screen[:controller])
          action = template_action(screen)
          raise "No template for #{screen[:controller]}##{screen[:action]}" unless action

          view = view_class.new(lookup_for(prefix), assigns_for(controller), nil)
          # The app's own helpers (ApplicationHelper and any controller-specific
          # ones) are what a screen reaches for as readily as the DSL's tags.
          helpers = screen[:controller].try(:_helpers)
          view.extend(helpers) if helpers

          # Partials still go through view.render (that is how a template asks
          # for one), and each announces itself to the log subscriber. A screen
          # re-renders on every tap, so a partial-backed screen would narrate
          # every tap into the log. Nothing here is a request; there is nothing
          # for that line to tell anyone.
          silence_view_logging do
            next view.render(template: "#{prefix}/#{action}", layout: @layout) if @layout

            template_for_render(prefix, action).render(view, {})
          end
        end

        # Per-thread, so a concurrent web request keeps its own logging.
        def silence_view_logging(&block)
          logger = defined?(ActionView::Base.logger) ? ActionView::Base.logger : nil
          return yield unless logger.respond_to?(:silence)

          logger.silence(::Logger::ERROR, &block)
        rescue StandardError
          yield
        end

        # Holding the compiled template would otherwise defeat template
        # reloading, so re-resolve when the file changes. A stat costs a
        # fraction of what resolving again does.
        def template_for_render(prefix, action)
          key = "#{prefix}/#{action}"
          cached, stamp = @templates[key]
          return cached if cached && (current = template_mtime(cached)) && current == stamp

          # Only once the file has actually changed. Nothing here runs inside
          # Rails' reloader, so an edited template is never invalidated for us,
          # and the resolver caches process-wide — but discarding the view class
          # on a first resolve would strand the partials already compiled into
          # it, so this must not fire on the way in.
          invalidate_templates! if cached

          template = lookup_for(prefix).find_template(action, [prefix], false, [])
          @templates[key] = [template, template_mtime(template)]
          template
        end

        def invalidate_templates!
          ActionView::LookupContext::DetailsKey.clear
          @templates = {}
          @lookups = {}
          @template_actions = {}
          self.class.reset_view_class!
        end

        def template_mtime(template)
          return nil unless template

          File.mtime(template.identifier)
        rescue SystemCallError
          nil
        end

        # Partials in a screen ("render \"nav\"") resolve relative to the
        # controller's own view folder, so each prefix gets its own context.
        # Never mutated after creation.
        def lookup_for(prefix)
          @lookups[prefix] ||= build_lookup_context([prefix])
        end

        def template_action(screen)
          prefix = controller_path(screen[:controller])
          @template_actions ||= {}
          @template_actions[[prefix, screen[:action]]] ||=
            candidates_for(screen[:action]).find { |action| lookup_for(prefix).exists?(action, [prefix]) }
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

        # One view class for the whole process, not per session. ActionView
        # caches compiled templates process-wide, and a template compiles its
        # render method into the class that first rendered it — so a class per
        # session hands the second connection a template that believes it is
        # already compiled, and every screen it shares raises NoMethodError.
        class << self
          def view_class
            @view_class ||= ActionView::Base.with_empty_template_cache
          end

          def reset_view_class!
            @view_class = nil
          end
        end

        def view_class = self.class.view_class

        def build_lookup_context(prefixes = [])
          ActionView::LookupContext.new(@view_paths || ::ActionController::Base.view_paths, {}, prefixes)
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
          attr_writer :ruflet_screen_params, :ruflet_screen_session

          # Outlives the tap, like a Rails session, but held by the connection
          # rather than a cookie.
          def session
            @ruflet_screen_session ||= {}
          end

          def params
            @ruflet_screen_params ||= {}
          end

        end
      end
    end
  end
end

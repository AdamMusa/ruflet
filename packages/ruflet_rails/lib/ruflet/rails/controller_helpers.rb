# frozen_string_literal: true

module Ruflet
  module Rails
    # Available in every controller (see Railtie).
    #
    # A native screen is fetched by the session's RackFetcher, which tags its
    # requests. Knowing that lets an action answer the native client in one
    # cycle instead of the browser's two.
    #
    # Post/Redirect/Get exists so a browser's reload button doesn't re-submit.
    # The native client has no reload button and no address bar: the redirect
    # buys nothing there and doubles the work, because the fetcher has to
    # follow the 302 with a second request through routing, the controller and
    # the view. `render_native` renders the screen straight from the POST.
    #
    #   def counter_increment
    #     session[:count] = session[:count].to_i + 1
    #     render_native :counter, else: -> { redirect_to counter_path }
    #   end
    # A plain module on purpose: ruflet_rails loads without Rails (the gem's
    # own tests do exactly that), so this must not reach for
    # ActiveSupport::Concern at load time.
    module ControllerHelpers
      def self.included(base)
        return unless base.respond_to?(:helper_method)

        base.helper_method :ruflet_native_request?
      rescue StandardError
        nil
      end

      # True when this request came from a Ruflet native session rather than a
      # browser.
      def ruflet_native_request?
        request.headers["X-Ruflet-Native"].to_s == "1"
      end

      # Render `template` for a native client; otherwise run `else` (usually the
      # redirect a browser still wants).
      def render_native(template, **options, &fallback)
        fallback ||= options.delete(:else)

        unless ruflet_native_request?
          return fallback.call if fallback.respond_to?(:call)

          raise ArgumentError, "render_native needs an `else:` for browser requests"
        end

        options.delete(:else)
        render(template, **options)
      end
    end
  end
end

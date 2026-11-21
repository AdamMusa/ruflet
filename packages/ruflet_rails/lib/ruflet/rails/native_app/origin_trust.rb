# frozen_string_literal: true

require "securerandom"

module Ruflet
  module Rails
    class NativeApp
      # Which pages may drive the native shell.
      #
      # The HTML adapter reports `ruflet:*` lines through console.log, and the
      # WebView forwards the console lines of whatever page it shows: the app's
      # own pages, but also an external site the user followed a link to, or
      # an OAuth provider. Only pages on a trusted origin may drive the shell.
      # The trusted origins are start_url's origin, its https form when
      # start_url is http, its www/apex twin, and every origin the app lists in
      # `native_shell(trusted_origins: [...])`.
      #
      # Each WebView slot (the shell body, and each sheet) keeps a BridgeFrame:
      #
      # - It starts trusted when its first URL is on a trusted origin.
      # - A page_started / url_change / page_ended URL on any other origin
      #   makes it untrusted.
      # - Only a probe makes it trusted again. The probe is a short script that
      #   logs a one-time random token only when window.location.origin, which
      #   page script cannot change, is a trusted origin. A reported URL is not
      #   enough: on iOS page_ended carries the WebView's current URL, which can
      #   already be the next page while the previous one still runs.
      #
      # While a frame is untrusted, its ruflet:* lines are dropped and logged.
      # The adapter is not injected into a page that is not on a trusted
      # origin; the shell clears the page chrome itself, as the adapter's
      # "absent" reports did.
      #
      # An app whose pages all come from start_url's origin never leaves the
      # trusted state, so the shell sends it what it sent before (the sheet
      # WebView now also subscribes to url_change, to see redirects).
      BridgeFrame = Struct.new(:trusted, :nonce, :url, keyword_init: true)

      TRUST_PREFIX = "ruflet:trust:"
      BRIDGE_PREFIXES = [ACTION_PREFIX, APPBAR_PREFIX, BOTTOMNAV_PREFIX, DRAWER_PREFIX, RAIL_PREFIX].freeze

      private

      # --- Trusted origins ---------------------------------------------------

      def configure_trusted_origins(start_url, extra)
        origins = []
        start = origin_of(start_url)
        origins.concat(start_origin_variants(start)) if start
        Array(extra).each do |entry|
          origin = origin_of(entry)
          unless origin
            raise ArgumentError,
                  "trusted_origins: #{entry.inspect} is not an http(s) origin such as \"https://auth.example.com\""
          end

          origins << origin
        end
        @trusted_origins = origins.uniq.freeze
      end

      # Origin checks need an http(s) origin to trust. A start_url without one
      # (and no trusted_origins) keeps the shell's previous behavior.
      def origin_checks?
        !@trusted_origins.empty?
      end

      def trusted_origin?(url)
        return true unless origin_checks?

        origin = origin_of(url)
        !origin.nil? && @trusted_origins.include?(origin)
      end

      # [scheme, host, port] of an http(s) URL, or nil.
      def origin_of(url)
        uri = URI.parse(url.to_s.strip)
        scheme = uri.scheme.to_s.downcase
        return nil unless %w[http https].include?(scheme)

        host = uri.host.to_s.downcase
        return nil if host.empty?

        [scheme, host, uri.port || default_port(scheme)]
      rescue URI::Error
        nil
      end

      # start_url's origin, its https form when start_url is http (a force_ssl
      # redirect), and its www/apex twin (a bare domain that redirects to www).
      def start_origin_variants(origin)
        scheme, host, port = origin
        schemes = [[scheme, port]]
        schemes << ["https", port == 80 ? 443 : port] if scheme == "http"
        hosts = [host, www_twin(host)].compact
        hosts.product(schemes).map { |name, (proto, number)| [proto, name, number] }
      end

      def www_twin(host)
        return nil if host.start_with?("[") || host.match?(/\A[\d.]+\z/) || !host.include?(".")
        return "www.#{host}" unless host.start_with?("www.")

        bare = host.delete_prefix("www.")
        bare.include?(".") ? bare : nil
      end

      def default_port(scheme)
        scheme == "https" ? 443 : 80
      end

      # The origin as window.location.origin spells it.
      def origin_string(origin)
        scheme, host, port = origin
        port == default_port(scheme) ? "#{scheme}://#{host}" : "#{scheme}://#{host}:#{port}"
      end

      def trusted_origins_text
        @trusted_origins.map { |origin| origin_string(origin) }.join(", ")
      end

      # --- Bridge frames -----------------------------------------------------

      def new_bridge_frame(url)
        BridgeFrame.new(trusted: trusted_origin?(url), nonce: nil, url: url.to_s)
      end

      # A URL the frame's WebView reported (page_started, url_change,
      # page_ended). Another origin makes the frame untrusted. With +probe+ (a
      # webview), a trusted-origin URL on an untrusted frame sends a probe:
      # the page may be a trusted one again without a page_ended (a cancelled
      # navigation or a download leaves the previous page in place).
      def note_frame_url(frame, url, probe: nil)
        return unless origin_checks?

        url = url.to_s
        return if url.empty? || url == "about:blank"

        frame.url = url
        if trusted_origin?(url)
          verify_frame(frame, probe) if probe && !frame.trusted && !frame.nonce
        else
          frame.trusted = false
          frame.nonce = nil
        end
      end

      # Run the trust probe (and +adapter+, only once the probe passes) in
      # +webview+. Its reply, TRUST_PREFIX + token, makes the frame trusted.
      def verify_frame(frame, webview, adapter: nil)
        return unless origin_checks? && webview.respond_to?(:run_javascript)

        frame.nonce = SecureRandom.hex(16)
        webview.run_javascript(trust_probe_js(frame.nonce, adapter))
      rescue StandardError
        nil
      end

      def trust_probe_js(nonce, adapter = nil)
        checks = @trusted_origins.map { |origin| "o === #{origin_string(origin).to_json}" }.join(" || ")
        <<~JS
          (function () {
            var o = window.location.origin;
            if (!(#{checks})) return;
            console.log(#{"#{TRUST_PREFIX}#{nonce}".to_json});
          #{adapter}})();
        JS
      end

      # Whether +message+ from +frame+'s WebView may drive the shell. A probe
      # reply is consumed here; a ruflet:* line from an untrusted frame is
      # dropped, logged, and (when no probe is pending) answered with a probe.
      def bridge_message_allowed?(frame, message, webview)
        if message.start_with?(TRUST_PREFIX)
          confirm_frame(frame, message[TRUST_PREFIX.length..])
          return false
        end
        return true if frame.trusted
        return false unless BRIDGE_PREFIXES.any? { |prefix| message.start_with?(prefix) }

        report_untrusted_message(frame, message)
        verify_frame(frame, webview) unless frame.nonce
        false
      end

      def confirm_frame(frame, token)
        nonce = frame.nonce
        return unless nonce && same_token?(token.to_s, nonce)

        frame.trusted = true
        frame.nonce = nil
      end

      def same_token?(left, right)
        return false unless left.bytesize == right.bytesize

        left.bytes.zip(right.bytes).reduce(0) { |diff, (a, b)| diff | (a ^ b) }.zero?
      end

      # page_ended on the shell body: inject the adapter into a trusted page,
      # verify a trusted-origin page that follows an untrusted one, and clear
      # the chrome over any other page.
      def sync_page_chrome(screen, url)
        if @main_frame.trusted
          inject_html_adapter(screen)
        elsif trusted_origin?(url)
          verify_frame(@main_frame, screen.webview, adapter: self.class.html_adapter_js)
        else
          clear_untrusted_chrome(screen)
        end
      end

      # page_ended on a sheet: the same, minus the chrome (a sheet's chrome
      # declarations are ignored anyway).
      def sync_sheet_page(frame, sheet_webview, url)
        if frame.trusted
          inject_html_adapter_for(sheet_webview, sheet: true)
        elsif trusted_origin?(url)
          verify_frame(frame, sheet_webview, adapter: self.class.html_adapter_js(sheet: true))
        end
      end

      # What the adapter's "absent" reports did on a page without ruflet
      # markup: clear the AppBar, drawer and rail the previous page declared
      # (the bottom bar persists).
      def clear_untrusted_chrome(screen)
        apply_appbar(screen, { "absent" => true })
        apply_bottomnav({ "absent" => true })
        apply_drawer(screen, { "absent" => true })
        apply_rail(screen, { "absent" => true })
      end

      # A request action runs a form in the shell body's page, with that page's
      # CSRF token. Send it only to a trusted origin, and only from a page that
      # is verified to be on one.
      def webview_request_allowed?(target)
        return true unless origin_checks?

        unless trusted_origin?(target)
          native_shell_warn("ignored a request to #{describe_url_origin(target)}: requests may only go to " \
                            "#{trusted_origins_text} (add your own origins to native_shell(trusted_origins: [...]))")
          return false
        end
        return true if @main_frame.trusted

        native_shell_warn("ignored a request to #{describe_url_origin(target)}: the page that would send it " \
                          "is not verified to be on #{trusted_origins_text}")
        false
      end

      def report_untrusted_message(frame, message)
        kind = message[/\Aruflet:[a-z]+/]
        origin = origin_of(frame.url)
        source =
          if origin.nil?
            "a page whose origin is unknown"
          elsif @trusted_origins.include?(origin)
            "a page on #{origin_string(origin)} that is not verified yet"
          else
            origin_string(origin)
          end
        native_shell_warn("ignored #{kind} from #{source}: only pages on #{trusted_origins_text} may drive the " \
                          "native shell (add your own origins to native_shell(trusted_origins: [...]))")
      end

      def describe_url_origin(url)
        origin = origin_of(url)
        return origin_string(origin) if origin

        scheme = url.to_s[/\A[a-zA-Z][a-zA-Z0-9+.-]*(?=:)/]
        scheme ? "a #{scheme.downcase}: URL" : "an invalid URL"
      end

      def native_shell_warn(text)
        line = "[ruflet_rails] native_shell #{text}"
        logger = ::Rails.logger if defined?(::Rails) && ::Rails.respond_to?(:logger)
        logger ? logger.warn(line) : warn(line)
      rescue StandardError
        nil
      end
    end
  end
end

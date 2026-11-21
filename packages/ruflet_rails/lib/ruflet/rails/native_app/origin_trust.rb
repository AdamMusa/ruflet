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
      # - It starts trusted when its first URL is on a trusted origin (or is a
      #   relative URL URI could not resolve: the opener's origin).
      # - A page_started / url_change / page_ended URL on any other origin
      #   makes it untrusted.
      # - Only a probe makes it trusted again. The probe is a short script that
      #   logs a one-time random token only when window.location.origin, which
      #   page script cannot change, is a trusted origin. A reported URL is not
      #   enough: on iOS page_ended carries the WebView's current URL, which can
      #   already be the next page while the previous one still runs.
      # - A probe is sent, and its answer counts, only while the last URL the
      #   WebView reported is on a trusted origin. On iOS page_started and
      #   url_change report the next page's URL as its navigation starts, while
      #   the previous document still runs and could answer a probe; when that
      #   navigation commits, no event says so. After a foreign URL, trust
      #   therefore waits for a trusted URL to be reported again: that page's
      #   page_ended, or a url_change back (the navigation was abandoned).
      #
      # While a frame is untrusted, its ruflet:* lines are dropped and logged.
      # The adapter is not injected into a page that is not on a trusted
      # origin; the shell clears the page chrome itself, as the adapter's
      # "absent" reports did.
      #
      # An app whose pages all come from start_url's origin never leaves the
      # trusted state, so the shell sends it what it sent before (the sheet
      # WebView now also subscribes to url_change, to see redirects).
      BridgeFrame = Struct.new(:trusted, :nonces, :url, keyword_init: true)

      TRUST_PREFIX = "ruflet:trust:"
      # Probes that may be in flight at once: the page_ended probe (with the
      # adapter) and url_change probes sent after it all still count.
      MAX_PENDING_PROBES = 8
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

      URL_SCHEME = /\A[a-zA-Z][a-zA-Z0-9+.-]*:/
      URL_AUTHORITY = %r{\A([a-zA-Z][a-zA-Z0-9+.-]*)://([^/\\?#]*)}
      URL_HOST_PORT = /\A(\[[0-9a-fA-F:.]+\]|[a-zA-Z0-9\-._~!$&'()*+,;=]+)(?::(\d*))?\z/
      # //host, or /\host: a WebView reads \ as / in http(s) URLs.
      URL_OTHER_HOST = %r{\A[/\\]{2}}

      # [scheme, host, port] of an absolute http(s) URL, or nil.
      #
      # Only the scheme://authority prefix is read, the way the WebView reads
      # it: the authority ends at the first /, \, ? or #, and the host is what
      # follows its last @. So the app's own pages keep their origin when the
      # path, query or fragment holds something URI.parse rejects but a WebView
      # reports as is (a second #, [ ], |, a lone %). A host that is not plain
      # ASCII (percent-encoded, Unicode) has no origin here; WebViews report
      # the hosts they load in ASCII.
      def origin_of(url)
        match = URL_AUTHORITY.match(url_text(url))
        return nil unless match

        scheme = match[1].downcase
        return nil unless %w[http https].include?(scheme)

        host_port = URL_HOST_PORT.match(match[2].rpartition("@").last)
        return nil unless host_port

        port = host_port[2].to_s.empty? ? default_port(scheme) : host_port[2].to_i
        return nil if port > 65_535

        [scheme, host_port[1].downcase, port]
      end

      # The URL as a WebView parses it: ASCII tabs and newlines are dropped
      # wherever they are, control characters and spaces at either end.
      def url_text(url)
        url.to_s.delete("\t\n\r").gsub(/\A[\x00-\x20]+|[\x00-\x20]+\z/, "")
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

      # A sheet URL that stays relative (URI could not resolve it) is on the
      # origin of the page or code that opened the sheet.
      def new_bridge_frame(url)
        BridgeFrame.new(trusted: trusted_origin?(url) || same_origin_reference?(url), nonces: [], url: url.to_s)
      end

      # A URL the frame's WebView reported (page_started, url_change,
      # page_ended). Another origin makes the frame untrusted and voids its
      # probes. With +probe+ (a webview), a trusted-origin URL on an untrusted
      # frame sends a fresh probe: the page may be a trusted one again without
      # a page_ended (a cancelled navigation or a download leaves the previous
      # page in place, and a back-forward cache restore reports only the URL).
      def note_frame_url(frame, url, probe: nil)
        return unless origin_checks?

        url = url.to_s
        return if url.empty? || url == "about:blank"

        frame.url = url
        if trusted_origin?(url)
          verify_frame(frame, probe) if probe && !frame.trusted
        else
          frame.trusted = false
          frame.nonces.clear
        end
      end

      # Run the trust probe (and +adapter+, only once the probe passes) in
      # +webview+. Its reply, TRUST_PREFIX + token, makes the frame trusted.
      # Nothing is sent while the frame's last reported URL is foreign: a
      # trusted page that answers then may be one a foreign navigation is
      # about to replace.
      def verify_frame(frame, webview, adapter: nil)
        return unless origin_checks? && webview.respond_to?(:run_javascript)
        return unless trusted_origin?(frame.url)

        nonce = SecureRandom.hex(16)
        frame.nonces << nonce
        frame.nonces.shift while frame.nonces.length > MAX_PENDING_PROBES
        webview.run_javascript(trust_probe_js(nonce, adapter))
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
      # dropped, logged, and answered with a probe when none is pending and the
      # frame's last reported URL is on a trusted origin.
      def bridge_message_allowed?(frame, message, webview)
        if message.start_with?(TRUST_PREFIX)
          confirm_frame(frame, message[TRUST_PREFIX.length..])
          return false
        end
        return true if frame.trusted
        return false unless BRIDGE_PREFIXES.any? { |prefix| message.start_with?(prefix) }

        report_untrusted_message(frame, message)
        verify_frame(frame, webview) if frame.nonces.empty?
        false
      end

      def confirm_frame(frame, token)
        return unless frame.nonces.any? { |nonce| same_token?(token.to_s, nonce) }

        frame.trusted = true
        frame.nonces.clear
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

        unless request_target_trusted?(target)
          native_shell_warn("ignored a request to #{describe_url_origin(target)}: requests may only go to " \
                            "#{trusted_origins_text} (add your own origins to native_shell(trusted_origins: [...]))")
          return false
        end
        return true if @main_frame.trusted

        native_shell_warn("ignored a request to #{describe_url_origin(target)}: the page that would send it " \
                          "is not verified to be on #{trusted_origins_text}")
        false
      end

      # The form resolves a target that is still relative (URI could not
      # resolve it) against the page it runs in. A path, query or fragment
      # stays on that page's origin, which the request needs verified anyway;
      # //host or /\host names another host, read with the page's scheme.
      def request_target_trusted?(target)
        return true if same_origin_reference?(target)

        text = url_text(target)
        return trusted_origin?(text) if text.match?(URL_SCHEME)

        page = origin_of(@main_frame.url) || origin_of(current_url)
        !page.nil? && trusted_origin?("#{page.first}://#{text.sub(%r{\A[/\\]+}, "")}")
      end

      # A relative URL that stays on the origin of the page it came from: no
      # scheme, and no //host.
      def same_origin_reference?(url)
        text = url_text(url)
        !text.match?(URL_SCHEME) && !text.match?(URL_OTHER_HOST)
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

        text = url_text(url)
        return "a #{text[URL_SCHEME].downcase} URL" if text.match?(URL_SCHEME)

        text.match?(URL_OTHER_HOST) ? "another host (#{text.inspect})" : "an invalid URL"
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

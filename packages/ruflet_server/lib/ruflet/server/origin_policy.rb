# frozen_string_literal: true

module Ruflet
  # Decides whether a WebSocket upgrade may go ahead, judged by its Origin
  # header.
  #
  # A browser adds Origin to every WebSocket handshake, and a page's script
  # cannot change it. Native Flutter clients (dart:io) send none. Checking it
  # stops another web page the developer has open from opening a socket to a
  # Ruflet server, reading the UI and firing its handlers (cross-site
  # WebSocket hijacking). Native clients are not affected.
  #
  # An upgrade is allowed when any of these holds:
  # - it carries no Origin (native clients and tools);
  # - its Origin is served from this machine (localhost, *.localhost,
  #   127.x.x.x, ::1, 0.0.0.0);
  # - its Origin's host is the host the request was sent to (the Host or
  #   X-Forwarded-Host header), on any port. That covers the web client
  #   `ruflet run --web` serves from its own port and a web build served from
  #   another port of the same machine, opened on localhost or on a LAN
  #   address. A page that could rebind that name could already use the
  #   server's own port, so allowing the other ports adds no exposure;
  # - its Origin is in allowed_origins. "*" allows every Origin.
  #
  # Any other Origin is foreign. An enforcing policy refuses it. A
  # non-enforcing policy accepts it as before and warns once per Origin.
  # Configuring allowed_origins makes a policy enforcing.
  #
  # Kept to what the embedded mruby VM supports: no Regexp, no defined?,
  # no URI, no Set.
  class OriginPolicy
    DEFAULT_PORTS = { "http" => 80, "ws" => 80, "https" => 443, "wss" => 443 }.freeze
    LOCAL_HOSTS = ["localhost", "0.0.0.0", "[::1]", "[::]"].freeze
    # Each distinct foreign Origin is logged once. A page can reconnect with
    # many Origins, so stop recording them past this many.
    LOGGED_ORIGINS_LIMIT = 64
    DEFAULT_SETTING_HINT = "RUFLET_ALLOWED_ORIGINS"

    # Splits allowed-origin settings (Arrays, or Strings separated by commas
    # or whitespace) into one list of entries. nil and blank entries drop out.
    def self.entries(*values)
      result = []
      values.each do |value|
        next if value.nil?

        items = value.is_a?(Array) ? value : [value]
        items.each do |item|
          item.to_s.split(",").each do |part|
            part.split(" ").each do |entry|
              stripped = entry.strip
              result << stripped unless stripped.empty?
            end
          end
        end
      end
      result.uniq
    end

    def initialize(allowed_origins: nil, enforce: false, setting_hint: DEFAULT_SETTING_HINT, log: nil)
      @setting_hint = setting_hint
      @log = log
      @logged = {}
      @logged_mutex = Mutex.new
      entries = self.class.entries(allowed_origins)
      @allow_all = entries.include?("*")
      @allowed = []
      entries.each do |entry|
        next if entry == "*"

        parsed = parse_origin(entry)
        if parsed
          @allowed << parsed
        else
          emit("Ruflet: ignoring allowed origin #{describe(entry)} from #{@setting_hint}: " \
               "expected scheme://host[:port], for example https://app.example.com.")
        end
      end
      @enforce = enforce || !entries.empty?
    end

    def enforce?
      @enforce
    end

    # True when the upgrade may go ahead. hosts are the raw Host and
    # X-Forwarded-Host header values (nil entries are ignored).
    def allow?(origin, hosts = [])
      return true if allowed_without_warning?(origin, hosts)

      report_foreign(origin)
      !@enforce
    end

    # True when the Origin is one that never needs a warning: absent, local,
    # this server's own host, or listed.
    def allowed_without_warning?(origin, hosts = [])
      return true if origin.nil? || origin.to_s.strip.empty?
      return true if @allow_all

      parsed = parse_origin(origin)
      return false unless parsed
      return true if local_host?(parsed[1])
      return true if @allowed.include?(parsed)

      same_host?(parsed, hosts)
    end

    private

    def report_foreign(origin)
      return unless first_report?(origin.to_s)

      emit(@enforce ? refused_message(origin) : accepted_message(origin))
    end

    def first_report?(key)
      @logged_mutex.synchronize do
        next false if @logged.key?(key)
        next false if @logged.size >= LOGGED_ORIGINS_LIMIT

        @logged[key] = true
        true
      end
    end

    def refused_message(origin)
      "Ruflet: refused a WebSocket connection from Origin #{describe(origin)}: " \
        "only pages on this server's own host, localhost and allowed origins may connect. " \
        "#{refused_hint(origin)}"
    end

    # An Origin such as "null" (a file:// page or a sandboxed iframe) cannot
    # be listed, since entries are scheme://host[:port]; only "*" allows it.
    def refused_hint(origin)
      parsed = parse_origin(origin)
      return "To allow it, add #{format_origin(parsed)} to #{@setting_hint}." if parsed

      "That Origin cannot be listed in #{@setting_hint}, which takes scheme://host[:port] entries; " \
        "only \"*\" there allows it, together with every other origin."
    end

    def accepted_message(origin)
      "Ruflet: accepted a WebSocket connection from Origin #{describe(origin)}, which is not this server's host. " \
        "A page on that origin can read and drive this app from a visitor's browser. " \
        "Set #{@setting_hint} to the origins your web clients are served from to refuse the others " \
        "(\"*\" allows every origin and silences this warning)."
    end

    def describe(origin)
      text = origin.to_s
      text = "#{text[0, 200]}..." if text.length > 200
      text.inspect
    end

    def emit(message)
      if @log
        @log.call(message)
      else
        warn message
      end
    rescue StandardError
      nil
    end

    def local_host?(host)
      return true if LOCAL_HOSTS.include?(host)
      return true if host.end_with?(".localhost")

      loopback_ipv4?(host)
    end

    def loopback_ipv4?(host)
      parts = host.split(".")
      return false unless parts.length == 4 && parts[0] == "127"

      parts.all? { |part| digits?(part) && part.to_i <= 255 }
    end

    # The port is not compared: a page on another port of the host the
    # request was sent to is served by the same machine or proxy.
    def same_host?(parsed, hosts)
      host = parsed[1]
      hosts.each do |raw|
        next if raw.nil?

        raw.to_s.split(",").each do |value|
          authority = split_authority(value.strip.downcase)
          return true if authority && authority[0] == host
        end
      end
      false
    end

    # [scheme, host, port] for "scheme://host[:port][/...]", nil otherwise.
    # The port defaults by scheme; it is nil for a scheme without a default.
    def parse_origin(value)
      text = value.to_s.strip.downcase
      separator = text.index("://")
      return nil unless separator && separator > 0

      scheme = text[0, separator]
      return nil unless scheme_chars?(scheme)

      rest = text[(separator + 3)..-1].to_s
      slash = rest.index("/")
      rest = rest[0, slash] if slash
      authority = split_authority(rest)
      return nil unless authority

      host, port = authority
      [scheme, host, port || DEFAULT_PORTS[scheme]]
    end

    # [host, port] for "host", "host:port", "[v6]" or "[v6]:port"; port is
    # nil when absent. nil when the value is not a plain host.
    def split_authority(value)
      return nil if value.nil? || value.empty?

      if value.start_with?("[")
        close = value.index("]")
        return nil unless close

        host = value[0, close + 1]
        return nil unless ipv6_chars?(host[1..-2].to_s)

        rest = value[(close + 1)..-1].to_s
        return [host, nil] if rest.empty?
        return nil unless rest.start_with?(":")

        port = parse_port(rest[1..-1].to_s)
        return port == false ? nil : [host, port]
      end

      colon = value.index(":")
      host = colon ? value[0, colon] : value
      return nil unless host_chars?(host)
      return [host, nil] unless colon

      port = parse_port(value[(colon + 1)..-1].to_s)
      port == false ? nil : [host, port]
    end

    # Integer port, nil for an empty port, false when it is not a number.
    def parse_port(text)
      return nil if text.empty?
      return false unless digits?(text) && text.length <= 5 && text.to_i <= 65_535

      text.to_i
    end

    def format_origin(parsed)
      scheme, host, port = parsed
      return "#{scheme}://#{host}" if port.nil? || port == DEFAULT_PORTS[scheme]

      "#{scheme}://#{host}:#{port}"
    end

    def digits?(text)
      return false if text.empty?

      text.bytes.all? { |byte| byte >= 48 && byte <= 57 }
    end

    # Letters, digits, "-", "." and "_" (lower case: callers downcase first).
    def host_chars?(text)
      return false if text.empty?

      text.bytes.all? do |byte|
        (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57) || byte == 45 || byte == 46 || byte == 95
      end
    end

    def ipv6_chars?(text)
      return false if text.empty?

      text.bytes.all? do |byte|
        (byte >= 97 && byte <= 102) || (byte >= 48 && byte <= 57) || byte == 58 || byte == 46
      end
    end

    def scheme_chars?(text)
      text.bytes.all? do |byte|
        (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57) || byte == 43 || byte == 45 || byte == 46
      end
    end
  end
end

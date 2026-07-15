# frozen_string_literal: true

module Ruflet
  module Rails
    # Resolve Rails assets to absolute URLs the Flutter client can load over
    # HTTP, so server-driven UI can show app images:
    #
    #   image(src: Ruflet::Rails.asset_url("logo.png"))
    #   image(src: Ruflet::Rails.image_url("brand/header.png"), fit: "cover")
    #
    # The *path* comes from the Rails asset pipeline — digested in production
    # (/assets/logo-<digest>.png), plain otherwise — so it survives
    # fingerprinting and CDNs. The *host* is resolved, in order, from:
    #
    #   1. an explicit `host:` argument
    #   2. Ruflet::Rails.config.backend_url
    #   3. the host the client connected on (the live WebSocket request)
    #
    # The client is a separate device (simulator, phone, browser), so a bare
    # "/assets/..." path would not resolve — the URL must be absolute. If Rails
    # already has an asset_host/CDN configured, the pipeline returns an absolute
    # URL and it is used unchanged. A value that is already a full URL passes
    # through untouched.
    module_function

    # The base URL the Flutter client uses to reach this Rails app — the single
    # source of truth for asset URLs, the build-time RUFLET_URL define and the
    # desktop launcher. A Rails Ruflet app always needs one, so this always
    # resolves to a usable value:
    #
    #   1. an explicit host: argument
    #   2. Ruflet::Rails.config.backend_url (set it in config/initializers/ruflet.rb)
    #   3. the host the client connected on (the live WebSocket request)
    #
    # Returns "" only when none of those are available (e.g. a build with no
    # configured backend_url) — set config.backend_url to cover that case.
    def backend_url(host: nil)
      candidate = host || config.backend_url
      candidate = request_base_url if candidate.to_s.strip.empty?
      candidate.to_s.strip.sub(%r{/+\z}, "")
    end

    def asset_url(source, host: nil)
      raw = source.to_s
      return raw if absolute_url?(raw)

      path = asset_pipeline_path(raw)
      return path if absolute_url?(path)

      base = backend_url(host: host)
      base.empty? ? path : "#{base}#{path}"
    end

    # Readability alias for image sources — identical resolution.
    def image_url(source, host: nil)
      asset_url(source, host: host)
    end

    def asset_pipeline_path(source)
      ::ActionController::Base.helpers.asset_path(source)
    rescue StandardError
      source.start_with?("/") ? source : "/#{source}"
    end
    private_class_method :asset_pipeline_path

    # Derive scheme://host from the live WebSocket request env so the URL points
    # back at the exact host the client reached — the one address guaranteed to
    # be reachable from that device.
    def request_base_url
      env = Protocol::Context.current_env
      return nil unless env

      host = env["HTTP_X_FORWARDED_HOST"] || env["HTTP_HOST"]
      return nil if host.to_s.strip.empty?

      scheme = (env["HTTP_X_FORWARDED_PROTO"] || env["rack.url_scheme"] || "http").to_s.split(",").first.to_s.strip
      scheme = "http" if scheme.empty?
      "#{scheme}://#{host}"
    end
    private_class_method :request_base_url

    def absolute_url?(value)
      !(value.to_s =~ %r{\A[a-z][a-z0-9+.-]*://}i).nil?
    end
    private_class_method :absolute_url?
  end
end

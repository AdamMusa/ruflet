# frozen_string_literal: true

module Ruflet
  module Rails
    # Central configuration for ruflet_rails.
    #
    # Rails apps keep Ruflet build metadata in config/initializers/ruflet.rb.
    # The build task serializes this object to the ruflet.yaml structure the
    # Ruflet CLI consumes, so Rails remains the source of truth:
    #
    #   Ruflet::Rails.configure do |config|
    #     # Runtime / server
    #     config.backend_url = Rails.env.production? ? "https://example.com" : "http://localhost:3000"
    #
    #     # App metadata (ruflet.yaml → app:)
    #     config.app_name = "My App"
    #
    #     # Services / extensions (ruflet.yaml → services: / extensions:)
    #     config.services = []
    #     config.extensions = %w[webview]
    #
    #     # Assets (ruflet.yaml → assets:)
    #     config.splash_screen = Rails.root.join("app/assets/images/splash.png")
    #     config.splash_dark   = Rails.root.join("app/assets/images/splash_dark.png")
    #     config.icon_launcher = Rails.root.join("app/assets/images/icon.png")
    #     config.icon_android  = Rails.root.join("app/assets/images/icon_android.png")
    #     config.icon_ios      = Rails.root.join("app/assets/images/icon_ios.png")
    #     config.icon_web      = Rails.root.join("app/assets/images/icon_web.png")
    #     config.icon_windows  = Rails.root.join("app/assets/images/icon_windows.png")
    #     config.icon_macos    = Rails.root.join("app/assets/images/icon_macos.png")
    #
    #     # Build options (ruflet.yaml → build:)
    #     config.splash_color      = "#FFFFFF"
    #     config.splash_dark_color = "#000000"
    #     config.icon_background   = "#FFFFFF"
    #     config.theme_color       = "#FFFFFF"
    #   end
    class Configuration
      # --- Runtime / server ---

      # Backend base URL. Used as --dart-define=RUFLET_URL at build time
      # and by the desktop launcher.
      attr_accessor :backend_url

      # --- App metadata (ruflet.yaml → app:) ---

      attr_accessor :app_name

      # --- Services / extensions (ruflet.yaml → services: / extensions:) ---

      attr_accessor :services
      attr_accessor :extensions

      # --- Assets (ruflet.yaml → assets:) ---

      attr_accessor :splash_screen
      attr_accessor :splash_dark
      attr_accessor :icon_launcher
      attr_accessor :icon_android
      attr_accessor :icon_ios
      attr_accessor :icon_web
      attr_accessor :icon_windows
      attr_accessor :icon_macos

      # --- Build options (ruflet.yaml → build:) ---

      attr_accessor :splash_color
      attr_accessor :splash_dark_color
      attr_accessor :icon_background
      attr_accessor :theme_color

      # --- Sessions (runtime only; not written to ruflet.yaml) ---

      # A Flutter web client reconnects with the session id it stored, and
      # the WebSocket endpoint resumes that session's Page. When the socket
      # that owns the session is still open, the endpoint first pings it and
      # waits this many seconds for the reply. A reply means another live
      # client holds the session (a duplicated browser tab copies the id), so
      # the newcomer gets its own session instead. No reply means the old
      # socket is a dead connection the server has not noticed yet, and the
      # reconnecting client resumes as before. nil or 0 skips the check.
      attr_accessor :session_resume_probe_timeout

      # Optional callable, called before a client resumes a session:
      #
      #   config.session_resume_guard = lambda do |original_env, new_env|
      #     user_id = ->(env) { ActionDispatch::Request.new(env).session[:user_id] }
      #     user_id.call(original_env) == user_id.call(new_env)
      #   end
      #
      # original_env is the Rack env of the WebSocket request that owns the
      # session, new_env the env of the request asking to resume it. A falsy
      # result (or an error) gives the new client a fresh session. Unset by
      # default.
      attr_accessor :session_resume_guard

      def initialize
        @backend_url = nil
        @app_name = nil
        @services = []
        @extensions = []
        @session_resume_probe_timeout = 1.0
        @session_resume_guard = nil
      end

      # Serialises config to the ruflet.yaml hash structure so the CLI can
      # consume it without a yaml file on disk (written to a temp file by
      # the Railtie's build task).
      def to_ruflet_yaml_hash
        hash = {}

        app = {}
        app["name"]        = @app_name    if @app_name
        app["backend_url"] = @backend_url if @backend_url
        hash["app"] = app unless app.empty?

        services = Array(@services)
        extensions = Array(@extensions)
        hash["services"] = services unless services.empty?
        hash["extensions"] = extensions unless extensions.empty?

        assets = {}
        assets["splash_screen"] = @splash_screen.to_s if @splash_screen
        assets["splash_dark"]   = @splash_dark.to_s   if @splash_dark
        assets["icon_launcher"] = @icon_launcher.to_s  if @icon_launcher
        assets["icon_android"]  = @icon_android.to_s   if @icon_android
        assets["icon_ios"]      = @icon_ios.to_s        if @icon_ios
        assets["icon_web"]      = @icon_web.to_s        if @icon_web
        assets["icon_windows"]  = @icon_windows.to_s    if @icon_windows
        assets["icon_macos"]    = @icon_macos.to_s      if @icon_macos
        hash["assets"] = assets unless assets.empty?

        build = {}
        build["splash_color"]      = @splash_color      if @splash_color
        build["splash_dark_color"] = @splash_dark_color if @splash_dark_color
        build["icon_background"]   = @icon_background   if @icon_background
        build["theme_color"]       = @theme_color       if @theme_color
        hash["build"] = build unless build.empty?

        hash
      end
    end
  end
end

# frozen_string_literal: true

module Ruflet
  module Rails
    # Central configuration for ruflet_rails.
    #
    # An install needs no config/initializers/ruflet.rb: routes mount
    # app/views/ruflet/main.rb explicitly and build metadata is read from
    # ruflet.yaml. Add an initializer only to override these settings:
    #
    #   Ruflet::Rails.configure do |config|
    #     # Runtime / server
    #     config.backend_url = Rails.env.production? ? "https://example.com" : "http://localhost:3000"
    #
    #     # App metadata (ruflet.yaml → app:)
    #     config.app_name = "My App"
    #
    #     # Services (ruflet.yaml → services:)
    #     config.services = []
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
      # and by the desktop launcher. Replaces ruflet.yaml → app.backend_url.
      attr_accessor :backend_url

      # --- App metadata (ruflet.yaml → app:) ---

      attr_accessor :app_name

      # --- Services (ruflet.yaml → services:) ---

      attr_accessor :services

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

      def initialize
        @backend_url = nil
        @app_name = nil
        @services = []
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

        hash["services"] = Array(@services)

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

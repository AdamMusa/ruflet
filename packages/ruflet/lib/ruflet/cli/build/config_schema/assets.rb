# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module ConfigSchema
        # Read by Contributors::Assets#apply_build_config. Image paths are
        # relative to ruflet.yaml (or app/ for Rails); colors are hex strings.
        # Where several spellings exist, the first one set wins, in the order
        # build, assets, then the document root.
        assets = lambda do |path, type, description = nil|
          register(path, type: type, feature: :assets, description: description)
        end

        assets.call("assets_dir", :path, "Fallback for `assets.dir`.")
        assets.call("splash_screen", :path, "Fallback for `assets.splash_screen`.")
        assets.call("icon_launcher", :path, "Fallback for `assets.icon_launcher`.")

        # Shared keys, under both build: and assets:.
        {
          "splash_screen" => [:path, "Splash image."],
          "splash_dark" => [:path, "Dark-mode splash image."],
          "icon_launcher" => [:path, "Launcher icon image."],
          "splash_color" => [:string, "Splash background color."],
          "splash_dark_color" => [:string, "Dark-mode splash background color."],
          "splash_color_dark" => [:string, "Alias of `splash_dark_color`."],
          "icon_background" => [:string, "Launcher icon background color."],
          "theme_color" => [:string, "Theme color (web manifest, launcher icons)."],
          "splash_background_image" => [:path, "Splash background image."],
          "splash_background_image_dark" => [:path, "Dark-mode splash background image."],
          "splash_branding" => [:path, "Splash branding image."],
          "splash_branding_dark" => [:path, "Dark-mode splash branding image."],
          "splash_branding_mode" => [:string, "Splash branding position (flutter_native_splash branding_mode)."],
          "branding_mode" => [:string, "Alias of `splash_branding_mode`."],
          "splash_branding_bottom_padding" => [:integer, "Splash branding bottom padding."],
          "branding_bottom_padding" => [:integer, "Alias of `splash_branding_bottom_padding`."]
        }.each do |key, (type, description)|
          assets.call("build.#{key}", type, description)
          assets.call("assets.#{key}", type, description)
        end

        assets.call("assets.dir", :path, "Application asset directory.")
        assets.call("build.assets_dir", :path, "Alias of `assets.dir`.")
        assets.call("build.splash_dark_image", :path, "Alias of `splash_dark`.")
        assets.call("build.background_image", :path, "Alias of `splash_background_image`.")
        assets.call("build.min_sdk_android", :integer, "Fallback for `android.min_sdk` (launcher icons).")
        assets.call("assets.splash_android_12", :path, "Fallback for `android.splash_android_12`.")
        assets.call("assets.splash_android_12_dark", :path, "Fallback for `android.splash_android_12_dark`.")
        assets.call("assets.icon_adaptive_foreground", :path, "Fallback for `android.adaptive_icon_foreground`.")
        assets.call("assets.icon_foreground", :path, "Alias of `assets.icon_adaptive_foreground`.")
        assets.call("assets.icon_adaptive_background_image", :path,
          "Fallback for `android.adaptive_icon_background_image`.")
        assets.call("assets.icon_adaptive_monochrome", :path, "Fallback for `android.adaptive_icon_monochrome`.")

        # Per-platform shorthands in the shared sections.
        PLATFORMS.each do |platform|
          assets.call("build.splash_#{platform}", :path, "Fallback for `#{platform}.splash_screen`.")
          assets.call("build.icon_#{platform}", :path, "Fallback for `#{platform}.icon_launcher`.")
          assets.call("assets.splash_#{platform}", :path, "Fallback for `#{platform}.splash_screen`.")
          assets.call("assets.splash_#{platform}_dark", :path, "Fallback for `#{platform}.splash_dark`.")
          assets.call("assets.icon_#{platform}", :path, "Fallback for `#{platform}.icon_launcher`.")
          assets.call("assets.splash_background_#{platform}", :path,
            "Fallback for `#{platform}.splash_background_image`.")
        end

        platform = lambda do |key, type, description, platforms = PLATFORMS|
          register_platform(key, type: type, feature: :assets, platforms: platforms, description: description)
        end

        # Every platform section takes the shared keys, overriding them there.
        {
          "splash_screen" => [:path, "Splash image."],
          "splash_image" => [:path, "Alias of `splash_screen`."],
          "splash_dark" => [:path, "Dark-mode splash image."],
          "splash_dark_image" => [:path, "Alias of `splash_dark`."],
          "icon_launcher" => [:path, "Launcher icon image."],
          "icon" => [:path, "Alias of `icon_launcher`."],
          "splash_background_image" => [:path, "Splash background image."],
          "background_image" => [:path, "Alias of `splash_background_image`."],
          "splash_background_image_dark" => [:path, "Dark-mode splash background image."],
          "background_image_dark" => [:path, "Alias of `splash_background_image_dark`."],
          "splash_branding" => [:path, "Splash branding image."],
          "branding" => [:path, "Alias of `splash_branding`."],
          "splash_branding_dark" => [:path, "Dark-mode splash branding image."],
          "branding_dark" => [:path, "Alias of `splash_branding_dark`."],
          "splash_color" => [:string, "Splash background color."],
          "splash_dark_color" => [:string, "Dark-mode splash background color."],
          "splash_color_dark" => [:string, "Alias of `splash_dark_color`."],
          "icon_background" => [:string, "Launcher icon background color."],
          "theme_color" => [:string, "Theme color."]
        }.each { |key, (type, description)| platform.call(key, type, description) }

        # Android: adaptive icons, the Android 12+ splash and generator options.
        {
          "splash_android_12" => [:path, "Android 12+ splash image."],
          "android_12_image" => [:path, "Alias of `splash_android_12`."],
          "splash_android_12_dark" => [:path, "Dark-mode Android 12+ splash image."],
          "android_12_image_dark" => [:path, "Alias of `splash_android_12_dark`."],
          "splash_android_12_icon_background_color" => [:string, "Android 12+ splash icon background color."],
          "icon_background_color" => [:string, "Alias of `splash_android_12_icon_background_color`."],
          "splash_android_12_icon_background_color_dark" => [:string,
            "Dark-mode Android 12+ splash icon background color."],
          "icon_background_color_dark" => [:string, "Alias of `splash_android_12_icon_background_color_dark`."],
          "splash_android_12_color" => [:string, "Android 12+ splash background color."],
          "android_12_color" => [:string, "Alias of `splash_android_12_color`."],
          "splash_android_12_color_dark" => [:string, "Dark-mode Android 12+ splash background color."],
          "android_12_color_dark" => [:string, "Alias of `splash_android_12_color_dark`."],
          "splash_android_12_branding" => [:path, "Android 12+ splash branding image."],
          "android_12_branding" => [:path, "Alias of `splash_android_12_branding`."],
          "adaptive_icon_foreground" => [:path, "Adaptive icon foreground image."],
          "icon_foreground" => [:path, "Alias of `adaptive_icon_foreground`."],
          "adaptive_icon_background" => [:string, "Adaptive icon background color."],
          "adaptive_icon_background_image" => [:path, "Adaptive icon background image."],
          "adaptive_icon_monochrome" => [:path, "Adaptive icon monochrome image."],
          "icon_monochrome" => [:path, "Alias of `adaptive_icon_monochrome`."],
          "min_sdk" => [:integer, "Android minimum SDK passed to flutter_launcher_icons."],
          "min_sdk_android" => [:integer, "Alias of `min_sdk`."],
          "splash_fullscreen" => [:boolean, "Hide the status bar on the splash screen."],
          "fullscreen" => [:boolean, "Alias of `splash_fullscreen`."],
          "splash_gravity" => [:string, "Splash image gravity."],
          "android_gravity" => [:string, "Alias of `splash_gravity`."]
        }.each { |key, (type, description)| platform.call(key, type, description, %w[android]) }

        platform.call("remove_alpha", :boolean, "Strip the alpha channel from the iOS icon.", %w[ios])
        platform.call("remove_alpha_ios", :boolean, "Alias of `remove_alpha`.", %w[ios])
        platform.call("content_mode", :string, "iOS splash content mode.", %w[ios])
        platform.call("ios_content_mode", :string, "Alias of `content_mode`.", %w[ios])
        platform.call("image_mode", :string, "Web splash image mode.", %w[web])
        platform.call("web_image_mode", :string, "Alias of `image_mode`.", %w[web])
        platform.call("icon_size", :integer, "Windows icon size.", %w[windows])
      end
    end
  end
end

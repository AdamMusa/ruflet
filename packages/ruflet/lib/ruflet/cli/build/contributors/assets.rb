# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module Contributors
        # Copies the configured splash and launcher icon images into the client
        # and configures flutter_native_splash and flutter_launcher_icons.
        module Assets
          # What the underlying generators can actually produce per platform:
          # flutter_native_splash covers android/ios/web, flutter_launcher_icons
          # covers android/ios/web/windows/macos. Linux has neither.
          PLATFORM_ASSET_SUPPORT = {
            "android" => { splash: true, icon: true },
            "ios" => { splash: true, icon: true },
            "web" => { splash: true, icon: true },
            "macos" => { splash: false, icon: true },
            "windows" => { splash: false, icon: true },
            "linux" => { splash: false, icon: false }
          }.freeze

          private

          # The generators can succeed while silently skipping Android output, which
          # ships a build with the stock Flutter icon and splash. Confirm the native
          # resources that ruflet.yaml asked for are actually on disk.
          def verify_android_generated_assets(client_dir, asset_flags, platform, verbose: false)
            return true unless %w[apk android aab appbundle].include?(platform.to_s)

            res_dir = File.join(client_dir, "android", "app", "src", "main", "res")
            return true unless File.directory?(res_dir)

            ok = true

            if asset_flags[:has_splash]
              launch_background = File.join(res_dir, "drawable", "launch_background.xml")
              if !File.file?(launch_background) || !read_text_file(launch_background).include?("splash")
                warn "Android splash screen was not generated in res/drawable/launch_background.xml"
                ok = false
              end

              styles_v31 = File.join(res_dir, "values-v31", "styles.xml")
              if !File.file?(styles_v31) || !read_text_file(styles_v31).include?("windowSplashScreenBackground")
                warn "Android 12+ splash screen is missing from res/values-v31/styles.xml; " \
                     "devices on Android 12 and newer will show the system default splash"
                ok = false
              else
                build_log(verbose, "android 12+ splash present in values-v31/styles.xml")
              end
            end

            if asset_flags[:has_icon]
              adaptive_icon = File.join(res_dir, "mipmap-anydpi-v26", "launcher_icon.xml")
              if File.file?(adaptive_icon)
                build_log(verbose, "adaptive launcher icon present in mipmap-anydpi-v26")
              else
                warn "Android adaptive launcher icon was not generated in res/mipmap-anydpi-v26/; " \
                     "set android.adaptive_icon_foreground and android.adaptive_icon_background in ruflet.yaml"
                ok = false
              end

              manifest = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
              if File.file?(manifest) && !read_text_file(manifest).include?("@mipmap/launcher_icon")
                warn "AndroidManifest.xml does not reference @mipmap/launcher_icon; the configured launcher icon is unused"
                ok = false
              end
            end

            build_note("Android launcher icon and splash resources verified") if ok && (asset_flags[:has_icon] || asset_flags[:has_splash])
            ok
          end

          def apply_build_config(client_dir, config = {})
            config_path = ENV["RUFLET_CONFIG"] || (File.file?("ruflet.yaml") ? "ruflet.yaml" : "ruflet.yml")
            config_present = File.file?(config_path)
            build = config["build"] || {}
            assets = config["assets"] || {}
            config_dir = config_present ? File.dirname(File.expand_path(config_path)) : Dir.pwd

            assets_root = build["assets_dir"] || assets["dir"] || config["assets_dir"] || "assets"
            assets_root = File.expand_path(assets_root, config_dir)

            resolve_asset = lambda do |path|
              return nil if path.nil? || path.to_s.strip.empty?
              full = File.expand_path(path.to_s, config_dir)
              return full if File.file?(full)

              rails_full = File.expand_path(File.join("app", path.to_s), config_dir)
              return rails_full if File.file?(rails_full)

              nil
            end

            splash_defined = key_defined?(build, "splash_screen") || key_defined?(assets, "splash_screen") || key_defined?(config, "splash_screen")
            icon_defined = key_defined?(build, "icon_launcher") || key_defined?(assets, "icon_launcher") || key_defined?(config, "icon_launcher")

            splash = resolve_asset.call(build["splash_screen"] || assets["splash_screen"] || config["splash_screen"])
            splash_dark = resolve_asset.call(build["splash_dark"] || build["splash_dark_image"] || assets["splash_dark"])
            icon = resolve_asset.call(build["icon_launcher"] || assets["icon_launcher"] || config["icon_launcher"])

            # Splash and icon appearance belongs with the assets it styles. `build`
            # is still read first so existing projects keep working.
            splash_color = build["splash_color"] || assets["splash_color"]
            splash_dark_color = build["splash_dark_color"] || build["splash_color_dark"] ||
              assets["splash_dark_color"] || assets["splash_color_dark"]
            icon_background = build["icon_background"] || assets["icon_background"]
            theme_color = build["theme_color"] || assets["theme_color"]

            # Every platform gets its own section with the same key names, falling
            # back to the shared assets/build values when a key is not overridden.
            platforms = PLATFORM_ASSET_SUPPORT.keys.each_with_object({}) do |name, resolved|
              section = platform_build_config(config, name)
              resolved[name] = {
                config: section,
                splash: resolve_asset.call(
                  section["splash_screen"] || section["splash_image"] ||
                    build["splash_#{name}"] || assets["splash_#{name}"]
                ),
                splash_dark: resolve_asset.call(
                  section["splash_dark"] || section["splash_dark_image"] || assets["splash_#{name}_dark"]
                ),
                icon: resolve_asset.call(
                  section["icon_launcher"] || section["icon"] ||
                    build["icon_#{name}"] || assets["icon_#{name}"]
                ),
                background_image: resolve_asset.call(
                  section["splash_background_image"] || section["background_image"] || assets["splash_background_#{name}"]
                ),
                background_image_dark: resolve_asset.call(
                  section["splash_background_image_dark"] || section["background_image_dark"]
                ),
                branding: resolve_asset.call(section["splash_branding"] || section["branding"]),
                branding_dark: resolve_asset.call(section["splash_branding_dark"] || section["branding_dark"]),
                splash_color: section["splash_color"] || splash_color,
                splash_dark_color: section["splash_dark_color"] || section["splash_color_dark"] || splash_dark_color,
                icon_background: section["icon_background"] || icon_background,
                theme_color: section["theme_color"] || theme_color
              }
            end

            splash_background_image = resolve_asset.call(
              build["splash_background_image"] || assets["splash_background_image"] || build["background_image"]
            )
            splash_background_image_dark = resolve_asset.call(
              build["splash_background_image_dark"] || assets["splash_background_image_dark"]
            )
            splash_branding = resolve_asset.call(build["splash_branding"] || assets["splash_branding"])
            splash_branding_dark = resolve_asset.call(build["splash_branding_dark"] || assets["splash_branding_dark"])
            splash_branding_mode = build["splash_branding_mode"] || build["branding_mode"] ||
              assets["splash_branding_mode"] || assets["branding_mode"]
            splash_branding_padding = build["splash_branding_bottom_padding"] || build["branding_bottom_padding"] ||
              assets["splash_branding_bottom_padding"] || assets["branding_bottom_padding"]

            android = platforms.dig("android", :config)
            android_splash = platforms.dig("android", :splash)
            android_splash_dark = platforms.dig("android", :splash_dark)
            android_12_splash = resolve_asset.call(
              android["splash_android_12"] || android["android_12_image"] || assets["splash_android_12"]
            )
            android_12_splash_dark = resolve_asset.call(
              android["splash_android_12_dark"] || android["android_12_image_dark"] || assets["splash_android_12_dark"]
            )
            adaptive_foreground = resolve_asset.call(
              android["adaptive_icon_foreground"] || android["icon_foreground"] ||
                assets["icon_adaptive_foreground"] || assets["icon_foreground"]
            )
            adaptive_background_image = resolve_asset.call(
              android["adaptive_icon_background_image"] || assets["icon_adaptive_background_image"]
            )
            adaptive_monochrome = resolve_asset.call(
              android["adaptive_icon_monochrome"] || android["icon_monochrome"] || assets["icon_adaptive_monochrome"]
            )

            android_splash_color = platforms.dig("android", :splash_color)
            android_splash_dark_color = platforms.dig("android", :splash_dark_color)
            android_12_icon_background = android["splash_android_12_icon_background_color"] ||
              android["icon_background_color"] || android_splash_color
            android_12_icon_background_dark = android["splash_android_12_icon_background_color_dark"] ||
              android["icon_background_color_dark"] || android_splash_dark_color
            android_12_color = android["splash_android_12_color"] || android["android_12_color"]
            android_12_color_dark = android["splash_android_12_color_dark"] || android["android_12_color_dark"]
            android_12_branding = resolve_asset.call(android["splash_android_12_branding"] || android["android_12_branding"])
            adaptive_background_color = android["adaptive_icon_background"] || icon_background
            android_min_sdk = android["min_sdk"] || android["min_sdk_android"] || build["min_sdk_android"]
            android_splash_fullscreen = first_defined(android, "splash_fullscreen", "fullscreen")
            android_splash_gravity = android["splash_gravity"] || android["android_gravity"]

            assets_dir = File.join(client_dir, "assets")
            FileUtils.mkdir_p(assets_dir)

            copy_asset = lambda do |src, dest|
              return unless src
              FileUtils.cp(src, File.join(assets_dir, dest))
            end

            copy_asset.call(splash, "splash.png")
            copy_asset.call(splash_dark, "splash_dark.png")
            copy_asset.call(icon, "icon.png")
            copy_asset.call(splash_background_image, "splash_background.png")
            copy_asset.call(splash_background_image_dark, "splash_background_dark.png")
            copy_asset.call(splash_branding, "splash_branding.png")
            copy_asset.call(splash_branding_dark, "splash_branding_dark.png")

            platforms.each do |name, entry|
              support = PLATFORM_ASSET_SUPPORT.fetch(name)
              if support[:splash]
                copy_asset.call(entry[:splash], "splash_#{name}.png")
                copy_asset.call(entry[:splash_dark], "splash_#{name}_dark.png")
                copy_asset.call(entry[:background_image], "splash_background_#{name}.png")
                copy_asset.call(entry[:background_image_dark], "splash_background_#{name}_dark.png")
                copy_asset.call(entry[:branding], "splash_branding_#{name}.png")
                copy_asset.call(entry[:branding_dark], "splash_branding_#{name}_dark.png")
              elsif entry[:splash] || entry[:splash_dark]
                build_note("#{name} has no splash screen generator; ignoring #{name}.splash_screen")
              end

              next unless entry[:icon]

              unless support[:icon]
                build_note("#{name} has no launcher icon generator; ignoring #{name}.icon_launcher")
                next
              end

              if name == "windows" && File.extname(entry[:icon]).downcase == ".ico"
                copy_asset.call(entry[:icon], "icon_windows.ico")
              else
                copy_asset.call(entry[:icon], "icon_#{name}.png")
              end
            end

            copy_asset.call(android_12_splash, "splash_android_12.png")
            copy_asset.call(android_12_splash_dark, "splash_android_12_dark.png")
            copy_asset.call(adaptive_foreground, "icon_foreground.png")
            copy_asset.call(adaptive_background_image, "icon_background.png")
            copy_asset.call(adaptive_monochrome, "icon_monochrome.png")

            default_splash = File.file?(File.join(assets_dir, "splash.png"))
            default_icon = File.file?(File.join(assets_dir, "icon.png"))

            using_default_splash = false
            using_default_icon = false

            if splash_defined && splash.nil?
              if default_splash
                using_default_splash = true
                build_note("Configured splash_screen was not found; using default template asset assets/splash.png")
              else
                return { has_icon: false, has_splash: false, error: "build config error: splash_screen is set but file was not found, and no default splash asset exists" }
              end
            end
            if icon_defined && icon.nil?
              if default_icon
                using_default_icon = true
                build_note("Configured icon_launcher was not found; using default template asset assets/icon.png")
              else
                return { has_icon: false, has_splash: false, error: "build config error: icon_launcher is set but file was not found, and no default icon asset exists" }
              end
            end

            # A project may configure nothing shared and declare everything under the
            # platform sections, so a platform asset alone has to run the generators.
            platform_splash = platforms.any? { |name, entry| PLATFORM_ASSET_SUPPORT.fetch(name)[:splash] && entry[:splash] }
            platform_icon = platforms.any? { |name, entry| PLATFORM_ASSET_SUPPORT.fetch(name)[:icon] && entry[:icon] }

            platforms.each do |name, entry|
              support = PLATFORM_ASSET_SUPPORT.fetch(name)
              if support[:splash] && entry[:splash].nil? && key_defined?(entry[:config], "splash_screen")
                build_note("#{name}.splash_screen was set but the file was not found")
              end
              if support[:icon] && entry[:icon].nil? && key_defined?(entry[:config], "icon_launcher")
                build_note("#{name}.icon_launcher was set but the file was not found")
              end
            end

            shared_splash_asset = !splash.nil? || default_splash
            shared_icon_asset = !icon.nil? || default_icon
            has_splash = shared_splash_asset || platform_splash
            has_icon = shared_icon_asset || platform_icon

            # Fall back to whatever Android configured when nothing is shared.
            effective_icon_background = icon_background || platforms.dig("android", :icon_background)
            effective_theme_color = theme_color || platforms.dig("android", :theme_color)

            pubspec_path = File.join(client_dir, "pubspec.yaml")
            unless File.file?(pubspec_path)
              return { has_icon: has_icon, has_splash: has_splash, error: nil }
            end

            ensure_pubspec_block(pubspec_path, "flutter_launcher_icons") if has_icon
            ensure_pubspec_block(pubspec_path, "flutter_native_splash") if has_splash

            if has_icon
              if shared_icon_asset
                update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path", "\"assets/icon.png\"", multiple: true)
              end
              # Android 8+ renders adaptive icons. Without these keys flutter_launcher_icons
              # never writes mipmap-anydpi-v26/, and the launcher falls back to the legacy
              # bitmap, ignoring icon_background entirely.
              update_pubspec_value(pubspec_path, "flutter_launcher_icons", "android", "launcher_icon", multiple: true)
              adaptive_foreground_path =
                if adaptive_foreground then "assets/icon_foreground.png"
                elsif platforms.dig("android", :icon) then "assets/icon_android.png"
                else "assets/icon.png"
                end
              update_pubspec_value(
                pubspec_path, "flutter_launcher_icons", "adaptive_icon_foreground",
                "\"#{adaptive_foreground_path}\"", multiple: true
              )
              adaptive_background_value =
                if adaptive_background_image
                  "\"assets/icon_background.png\""
                elsif adaptive_background_color
                  "\"#{adaptive_background_color}\""
                end
              if adaptive_background_value
                update_pubspec_value(
                  pubspec_path, "flutter_launcher_icons", "adaptive_icon_background",
                  adaptive_background_value, multiple: true
                )
              end
              if adaptive_monochrome
                update_pubspec_value(
                  pubspec_path, "flutter_launcher_icons", "adaptive_icon_monochrome",
                  "\"assets/icon_monochrome.png\"", multiple: true
                )
              end
              update_pubspec_value(pubspec_path, "flutter_launcher_icons", "min_sdk_android", android_min_sdk.to_s) if android_min_sdk
            end
            if has_icon
              # flutter_launcher_icons takes android/ios as flat image_path_* keys but
              # web/windows/macos as nested platform blocks.
              if platforms.dig("android", :icon)
                update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_android", "\"assets/icon_android.png\"", multiple: true)
              end
              if platforms.dig("ios", :icon)
                update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_ios", "\"assets/icon_ios.png\"", multiple: true)
              end
              if (remove_alpha = first_defined(platforms.dig("ios", :config), "remove_alpha", "remove_alpha_ios"))
                update_pubspec_value(pubspec_path, "flutter_launcher_icons", "remove_alpha_ios", remove_alpha ? "true" : "false")
              end

              %w[web windows macos].each do |name|
                entry = platforms.fetch(name)
                section = entry[:config]
                next if entry[:icon].nil? && section.empty?

                update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", name, "generate", "true")
                if entry[:icon]
                  image = if name == "windows" && File.extname(entry[:icon]).downcase == ".ico"
                    "assets/icon_windows.ico"
                  else
                    "assets/icon_#{name}.png"
                  end
                  update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", name, "image_path", "\"#{image}\"")
                end
                if name == "web"
                  update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", "web", "background_color", "\"#{entry[:icon_background]}\"") if entry[:icon_background]
                  update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", "web", "theme_color", "\"#{entry[:theme_color]}\"") if entry[:theme_color]
                end
                if name == "windows" && (icon_size = section["icon_size"])
                  update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", "windows", "icon_size", icon_size.to_s)
                end
              end
            end
            update_pubspec_value(pubspec_path, "flutter_launcher_icons", "background_color", "\"#{effective_icon_background}\"") if effective_icon_background
            update_pubspec_value(pubspec_path, "flutter_launcher_icons", "theme_color", "\"#{effective_theme_color}\"") if effective_theme_color

            update_pubspec_value(pubspec_path, "flutter_native_splash", "image", "\"assets/splash.png\"") if shared_splash_asset
            update_pubspec_value(pubspec_path, "flutter_native_splash", "image_dark", "\"assets/splash_dark.png\"") if splash_dark
            update_pubspec_value(pubspec_path, "flutter_native_splash", "color", "\"#{splash_color}\"") if splash_color
            update_pubspec_value(pubspec_path, "flutter_native_splash", "color_dark", "\"#{splash_dark_color}\"") if splash_dark_color

            if has_splash
              update_pubspec_value(pubspec_path, "flutter_native_splash", "background_image", "\"assets/splash_background.png\"") if splash_background_image
              update_pubspec_value(pubspec_path, "flutter_native_splash", "background_image_dark", "\"assets/splash_background_dark.png\"") if splash_background_image_dark
              update_pubspec_value(pubspec_path, "flutter_native_splash", "branding", "\"assets/splash_branding.png\"") if splash_branding
              update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_dark", "\"assets/splash_branding_dark.png\"") if splash_branding_dark
              update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_mode", splash_branding_mode.to_s) if splash_branding_mode
              update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_bottom_padding", splash_branding_padding.to_s) if splash_branding_padding
            end

            if has_splash
              # flutter_native_splash only generates for android, ios, and web; each
              # takes the shared keys suffixed with the platform name.
              %w[android ios web].each do |name|
                entry = platforms.fetch(name)
                update_pubspec_value(pubspec_path, "flutter_native_splash", name, "true")
                update_pubspec_value(pubspec_path, "flutter_native_splash", "image_#{name}", "\"assets/splash_#{name}.png\"") if entry[:splash]
                update_pubspec_value(pubspec_path, "flutter_native_splash", "image_dark_#{name}", "\"assets/splash_#{name}_dark.png\"") if entry[:splash_dark]
                if entry[:splash_color] && entry[:splash_color] != splash_color
                  update_pubspec_value(pubspec_path, "flutter_native_splash", "color_#{name}", "\"#{entry[:splash_color]}\"")
                end
                if entry[:splash_dark_color] && entry[:splash_dark_color] != splash_dark_color
                  update_pubspec_value(pubspec_path, "flutter_native_splash", "color_dark_#{name}", "\"#{entry[:splash_dark_color]}\"")
                end
                update_pubspec_value(pubspec_path, "flutter_native_splash", "background_image_#{name}", "\"assets/splash_background_#{name}.png\"") if entry[:background_image]
                update_pubspec_value(pubspec_path, "flutter_native_splash", "background_image_dark_#{name}", "\"assets/splash_background_#{name}_dark.png\"") if entry[:background_image_dark]
                update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_#{name}", "\"assets/splash_branding_#{name}.png\"") if entry[:branding]
                update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_dark_#{name}", "\"assets/splash_branding_#{name}_dark.png\"") if entry[:branding_dark]
              end

              if (ios_content_mode = platforms.dig("ios", :config)["content_mode"] || platforms.dig("ios", :config)["ios_content_mode"])
                update_pubspec_value(pubspec_path, "flutter_native_splash", "ios_content_mode", ios_content_mode.to_s)
              end
              if (web_image_mode = platforms.dig("web", :config)["image_mode"] || platforms.dig("web", :config)["web_image_mode"])
                update_pubspec_value(pubspec_path, "flutter_native_splash", "web_image_mode", web_image_mode.to_s)
              end
              update_pubspec_value(pubspec_path, "flutter_native_splash", "fullscreen", android_splash_fullscreen ? "true" : "false") unless android_splash_fullscreen.nil?
              update_pubspec_value(pubspec_path, "flutter_native_splash", "android_gravity", android_splash_gravity.to_s) if android_splash_gravity

              # Android 12+ draws the splash itself and ignores the legacy `image`/`color`
              # keys. Without an android_12 section the OS shows the launcher icon on a
              # system background, so mirror the configured splash into it.
              android_12_image =
                if android_12_splash then "assets/splash_android_12.png"
                elsif android_splash then "assets/splash_android.png"
                else "assets/splash.png"
                end
              update_pubspec_nested_value(pubspec_path, "flutter_native_splash", "android_12", "image", "\"#{android_12_image}\"")
              if android_12_icon_background
                update_pubspec_nested_value(
                  pubspec_path, "flutter_native_splash", "android_12",
                  "icon_background_color", "\"#{android_12_icon_background}\""
                )
              end
              android_12_image_dark =
                if android_12_splash_dark then "assets/splash_android_12_dark.png"
                elsif android_splash_dark then "assets/splash_android_dark.png"
                elsif splash_dark then "assets/splash_dark.png"
                end
              if android_12_image_dark
                update_pubspec_nested_value(
                  pubspec_path, "flutter_native_splash", "android_12",
                  "image_dark", "\"#{android_12_image_dark}\""
                )
              end
              if android_12_icon_background_dark
                update_pubspec_nested_value(
                  pubspec_path, "flutter_native_splash", "android_12",
                  "icon_background_color_dark", "\"#{android_12_icon_background_dark}\""
                )
              end
              update_pubspec_nested_value(pubspec_path, "flutter_native_splash", "android_12", "color", "\"#{android_12_color}\"") if android_12_color
              update_pubspec_nested_value(pubspec_path, "flutter_native_splash", "android_12", "color_dark", "\"#{android_12_color_dark}\"") if android_12_color_dark
              if android_12_branding
                copy_asset.call(android_12_branding, "splash_android_12_branding.png")
                update_pubspec_nested_value(
                  pubspec_path, "flutter_native_splash", "android_12",
                  "branding", "\"assets/splash_android_12_branding.png\""
                )
              end
            end

            {
              has_icon: has_icon,
              has_splash: has_splash,
              using_default_icon: using_default_icon,
              using_default_splash: using_default_splash,
              android_adaptive_icon: has_icon,
              android_12_splash: has_splash,
              error: nil
            }
          end

          def announce_asset_configuration(asset_flags)
            if asset_flags[:has_splash]
              if asset_flags[:using_default_splash]
                build_note("Splash screen will use the default template asset")
              else
                build_note("Splash screen is configured")
              end
            else
              build_note("No splash screen configured")
            end

            if asset_flags[:has_icon]
              if asset_flags[:using_default_icon]
                build_note("Launcher icons will use the default template asset")
              else
                build_note("Launcher icons are configured")
              end
            else
              build_note("No launcher icons configured")
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "fileutils"
require "yaml"

module Ruflet
  module CLI
    module BuildCommand
      def command_build(args)
        platform = (args.shift || "").downcase
        if platform.empty?
          warn "Usage: ruflet build <apk|ios|aab|web|macos|windows|linux>"
          return 1
        end

        flutter_cmd = flutter_build_command(platform)
        unless flutter_cmd
          warn "Unsupported build target: #{platform}"
          return 1
        end

        client_dir = detect_flutter_client_dir
        unless client_dir
          warn "Could not find Flutter client directory."
          warn "Set RUFLET_CLIENT_DIR or place client at ./ruflet_client"
          return 1
        end

        ok = prepare_flutter_client(client_dir)
        return 1 unless ok

        ok = system(*flutter_cmd, *args, chdir: client_dir)
        ok ? 0 : 1
      end

      private

      def detect_flutter_client_dir
        env_dir = ENV["RUFLET_CLIENT_DIR"]
        return env_dir if env_dir && Dir.exist?(env_dir)

        local = File.expand_path("ruflet_client", Dir.pwd)
        return local if Dir.exist?(local)

        template = File.expand_path("templates/ruflet_flutter_template", Dir.pwd)
        return template if Dir.exist?(template)

        nil
      end

      def prepare_flutter_client(client_dir)
        apply_build_config(client_dir)
        unless system("flutter", "pub", "get", chdir: client_dir)
          warn "flutter pub get failed"
          return false
        end

        unless system("dart", "run", "flutter_native_splash:create", chdir: client_dir)
          warn "flutter_native_splash failed"
          return false
        end

        unless system("dart", "run", "flutter_launcher_icons", chdir: client_dir)
          warn "flutter_launcher_icons failed"
          return false
        end

        true
      end

      def apply_build_config(client_dir)
        config_path = ENV["RUFLET_CONFIG"] || "ruflet.yaml"
        unless File.file?(config_path)
          alt = "ruflet.yml"
          config_path = alt if File.file?(alt)
        end

        config_present = File.file?(config_path)
        config = config_present ? (YAML.load_file(config_path) || {}) : {}
        build = config["build"] || {}
        assets = config["assets"] || {}
        config_dir = config_present ? File.dirname(File.expand_path(config_path)) : Dir.pwd

        assets_root = build["assets_dir"] || assets["dir"] || config["assets_dir"] || "assets"
        assets_root = File.expand_path(assets_root, config_dir)

        unless config_present || Dir.exist?(assets_root) || ENV["RUFLET_SPLASH"] || ENV["RUFLET_ICON"]
          return
        end

        resolve_asset = lambda do |path|
          return nil if path.nil? || path.to_s.strip.empty?
          full = File.expand_path(path.to_s, config_dir)
          File.file?(full) ? full : nil
        end

        find_first = lambda do |dir, names|
          names.each do |name|
            candidate = File.join(dir, name)
            return candidate if File.file?(candidate)
          end
          nil
        end

        splash = resolve_asset.call(build["splash"] || assets["splash"] || ENV["RUFLET_SPLASH"])
        splash_dark = resolve_asset.call(build["splash_dark"] || build["splash_dark_image"] || assets["splash_dark"])
        icon = resolve_asset.call(build["icon"] || assets["icon"] || ENV["RUFLET_ICON"])
        icon_android = resolve_asset.call(build["icon_android"] || assets["icon_android"])
        icon_ios = resolve_asset.call(build["icon_ios"] || assets["icon_ios"])
        icon_web = resolve_asset.call(build["icon_web"] || assets["icon_web"])
        icon_windows = resolve_asset.call(build["icon_windows"] || assets["icon_windows"])
        icon_macos = resolve_asset.call(build["icon_macos"] || assets["icon_macos"])

        if Dir.exist?(assets_root)
          splash ||= find_first.call(assets_root, ["splash.png", "splash.jpg", "splash.webp", "splash.bmp"])
          splash_dark ||= find_first.call(assets_root, ["splash_dark.png", "splash_dark.jpg", "splash_dark.webp", "splash_dark.bmp"])
          icon ||= find_first.call(assets_root, ["icon.png", "icon.jpg", "icon.webp", "icon.bmp"])
          icon_android ||= find_first.call(assets_root, ["icon_android.png", "icon_android.jpg", "icon_android.webp"])
          icon_ios ||= find_first.call(assets_root, ["icon_ios.png", "icon_ios.jpg", "icon_ios.webp"])
          icon_web ||= find_first.call(assets_root, ["icon_web.png", "icon_web.jpg", "icon_web.webp"])
          icon_windows ||= find_first.call(assets_root, ["icon_windows.ico", "icon_windows.png"])
          icon_macos ||= find_first.call(assets_root, ["icon_macos.png", "icon_macos.jpg", "icon_macos.webp"])
        end

        splash_color = build["splash_color"]
        splash_dark_color = build["splash_dark_color"] || build["splash_color_dark"]
        icon_background = build["icon_background"]
        theme_color = build["theme_color"]

        assets_dir = File.join(client_dir, "assets")
        FileUtils.mkdir_p(assets_dir)

        copy_asset = lambda do |src, dest|
          return unless src
          FileUtils.cp(src, File.join(assets_dir, dest))
        end

        copy_asset.call(splash, "splash.png")
        copy_asset.call(splash_dark, "splash_dark.png")
        copy_asset.call(icon, "icon.png")
        copy_asset.call(icon_android, "icon_android.png")
        copy_asset.call(icon_ios, "icon_ios.png")
        copy_asset.call(icon_web, "icon_web.png")
        if icon_windows
          ext = File.extname(icon_windows).downcase
          copy_asset.call(icon_windows, ext == ".ico" ? "icon_windows.ico" : "icon_windows.png")
        end
        copy_asset.call(icon_macos, "icon_macos.png")

        pubspec_path = File.join(client_dir, "pubspec.yaml")
        return unless File.file?(pubspec_path)

        if icon
          update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path", "\"assets/icon.png\"", multiple: true)
        end
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_android", "\"assets/icon_android.png\"", multiple: true) if icon_android
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_ios", "\"assets/icon_ios.png\"", multiple: true) if icon_ios
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_web", "\"assets/icon_web.png\"", multiple: true) if icon_web
        if icon_windows
          ext = File.extname(icon_windows).downcase
          value = ext == ".ico" ? "\"assets/icon_windows.ico\"" : "\"assets/icon_windows.png\""
          update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_windows", value, multiple: true)
        end
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_macos", "\"assets/icon_macos.png\"", multiple: true) if icon_macos
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "background_color", "\"#{icon_background}\"") if icon_background
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "theme_color", "\"#{theme_color}\"") if theme_color

        update_pubspec_value(pubspec_path, "flutter_native_splash", "image", "\"assets/splash.png\"") if splash
        update_pubspec_value(pubspec_path, "flutter_native_splash", "image_dark", "\"assets/splash_dark.png\"") if splash_dark
        update_pubspec_value(pubspec_path, "flutter_native_splash", "color", "\"#{splash_color}\"") if splash_color
        update_pubspec_value(pubspec_path, "flutter_native_splash", "color_dark", "\"#{splash_dark_color}\"") if splash_dark_color
      end

      def update_pubspec_value(path, block, key, value, multiple: false)
        lines = File.read(path).split("\n", -1)
        out = []
        in_block = false
        replaced = false
        block_indent = nil
        lines.each do |line|
          if line.start_with?("#{block}:")
            in_block = true
            block_indent = line[/^\s*/] + "  "
            out << line
            next
          end

          if in_block
            if line =~ /^\S/ && !line.start_with?("#{block}:")
              unless replaced
                out << "#{block_indent}#{key}: #{value}"
                replaced = true
              end
              in_block = false
            else
              if line.strip.start_with?("#{key}:")
                indent = line[/^\s*/]
                out << "#{indent}#{key}: #{value}"
                replaced = true
                next
              end
            end
          end

          out << line
        end
        if in_block && !replaced
          out << "#{block_indent}#{key}: #{value}"
        end
        File.write(path, out.join("\n"))
      end

      def flutter_build_command(platform)
        case platform
        when "apk", "android"
          ["flutter", "build", "apk"]
        when "aab", "appbundle"
          ["flutter", "build", "appbundle"]
        when "ios"
          ["flutter", "build", "ios", "--no-codesign"]
        when "web"
          ["flutter", "build", "web"]
        when "macos"
          ["flutter", "build", "macos"]
        when "windows"
          ["flutter", "build", "windows"]
        when "linux"
          ["flutter", "build", "linux"]
        else
          nil
        end
      end
    end
  end
end

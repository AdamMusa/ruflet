# frozen_string_literal: true

require "fileutils"
require "uri"
require "yaml"

module Ruflet
  module CLI
    module BuildCommand
      include FlutterSdk
      CLIENT_EXTENSION_MAP = {
        "ads" => { package: "flet_ads", alias: "ruflet_ads" },
        "audio" => { package: "flet_audio", alias: "ruflet_audio" },
        "audio_recorder" => { package: "flet_audio_recorder", alias: "ruflet_audio_recorder" },
        "camera" => { package: "flet_camera", alias: "ruflet_camera" },
        "charts" => { package: "flet_charts", alias: "ruflet_charts" },
        "code_editor" => { package: "flet_code_editor", alias: "ruflet_code_editor" },
        "color_pickers" => { package: "flet_color_pickers", alias: "ruflet_color_picker" },
        "datatable2" => { package: "flet_datatable2", alias: "ruflet_datatable2" },
        "flashlight" => { package: "flet_flashlight", alias: "ruflet_flashlight" },
        "geolocator" => { package: "flet_geolocator", alias: "ruflet_geolocator" },
        "lottie" => { package: "flet_lottie", alias: "ruflet_lottie" },
        "map" => { package: "flet_map", alias: "ruflet_map" },
        "permission_handler" => { package: "flet_permission_handler", alias: "ruflet_permission_handler" },
        "secure_storage" => { package: "flet_secure_storage", alias: "ruflet_secure_storage" },
        "video" => { package: "flet_video", alias: "ruflet_video" },
        "webview" => { package: "flet_webview", alias: "ruflet_webview" }
      }.freeze

      def command_build(args)
        platform = (args.shift || "").downcase
        if platform.empty?
          warn "Usage: ruflet build <apk|android|ios|aab|web|macos|windows|linux>"
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

        config = load_ruflet_config
        tools = ensure_flutter!("build", client_dir: client_dir)
        ok = prepare_flutter_client(client_dir, tools: tools, config: config)
        return 1 unless ok

        build_args = [*flutter_cmd, *args]
        client_url = configured_client_url(config)
        if client_url
          build_args += ["--dart-define", "RUFLET_CLIENT_URL=#{client_url}"]
        end

        ok = system(tools[:env], tools[:flutter], *build_args, chdir: client_dir)
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

      def prepare_flutter_client(client_dir, tools:, config:)
        ensure_local_ruby_runtime_override(client_dir)
        apply_service_extension_config(client_dir, config)
        asset_flags = apply_build_config(client_dir, config)
        if asset_flags[:error]
          warn asset_flags[:error]
          return false
        end
        unless system(tools[:env], tools[:flutter], "pub", "get", chdir: client_dir)
          warn "flutter pub get failed"
          return false
        end

        if asset_flags[:has_splash]
          unless system(tools[:env], tools[:dart], "run", "flutter_native_splash:create", chdir: client_dir)
            warn "flutter_native_splash failed"
            return false
          end
        end

        if asset_flags[:has_icon]
          unless system(tools[:env], tools[:dart], "run", "flutter_launcher_icons", chdir: client_dir)
            warn "flutter_launcher_icons failed"
            return false
          end
        end

        true
      end

      def configured_client_url(config)
        candidates = [
          config["ruflet_client_url"],
          (config["app"].is_a?(Hash) ? config["app"]["ruflet_client_url"] : nil)
        ]
        raw = candidates.find { |v| !v.to_s.strip.empty? }
        return nil if raw.nil?

        value = raw.to_s.strip
        uri = URI.parse(value)
        return nil unless %w[http https ws wss].include?(uri.scheme)
        return nil if uri.host.to_s.strip.empty?

        value
      rescue URI::InvalidURIError
        nil
      end

      def load_ruflet_config
        config_path = ENV["RUFLET_CONFIG"] || "ruflet.yaml"
        unless File.file?(config_path)
          alt = "ruflet.yml"
          config_path = alt if File.file?(alt)
        end
        return {} unless File.file?(config_path)

        YAML.safe_load(File.read(config_path), aliases: true) || {}
      rescue StandardError => e
        warn "Failed to load ruflet config: #{e.class}: #{e.message}"
        {}
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
        icon_android = resolve_asset.call(build["icon_android"] || assets["icon_android"])
        icon_ios = resolve_asset.call(build["icon_ios"] || assets["icon_ios"])
        icon_web = resolve_asset.call(build["icon_web"] || assets["icon_web"])
        icon_windows = resolve_asset.call(build["icon_windows"] || assets["icon_windows"])
        icon_macos = resolve_asset.call(build["icon_macos"] || assets["icon_macos"])

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

        if splash_defined && splash.nil?
          return { has_icon: false, has_splash: false, error: "build config error: splash_screen is set but file was not found" }
        end
        if icon_defined && icon.nil?
          return { has_icon: false, has_splash: false, error: "build config error: icon_launcher is set but file was not found" }
        end

        pubspec_path = File.join(client_dir, "pubspec.yaml")
        unless File.file?(pubspec_path)
          return { has_icon: icon_defined && !icon.nil?, has_splash: splash_defined && !splash.nil?, error: nil }
        end

        if icon_defined && icon
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

        update_pubspec_value(pubspec_path, "flutter_native_splash", "image", "\"assets/splash.png\"") if splash_defined && splash
        update_pubspec_value(pubspec_path, "flutter_native_splash", "image_dark", "\"assets/splash_dark.png\"") if splash_dark
        update_pubspec_value(pubspec_path, "flutter_native_splash", "color", "\"#{splash_color}\"") if splash_color
        update_pubspec_value(pubspec_path, "flutter_native_splash", "color_dark", "\"#{splash_dark_color}\"") if splash_dark_color

        { has_icon: icon_defined && !icon.nil?, has_splash: splash_defined && !splash.nil?, error: nil }
      end

      def key_defined?(hash, key)
        hash.is_a?(Hash) && (hash.key?(key) || hash.key?(key.to_sym))
      end

      def apply_service_extension_config(client_dir, config = {})
        services = Array(config["services"])
        extension_keys = services.map { |v| normalize_extension_key(v) }.compact.uniq
        extension_packages = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:package) }.uniq
        extension_aliases = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:alias) }.uniq

        pubspec_path = File.join(client_dir, "pubspec.yaml")
        main_path = File.join(client_dir, "lib", "main.dart")
        prune_client_pubspec(pubspec_path, extension_packages) if File.file?(pubspec_path)
        prune_client_main(main_path, extension_aliases) if File.file?(main_path)
      end

      def ensure_local_ruby_runtime_override(client_dir)
        pubspec_path = File.join(client_dir, "pubspec.yaml")
        return unless File.file?(pubspec_path)

        pubspec = YAML.safe_load(File.read(pubspec_path), aliases: true) || {}
        dependencies = pubspec["dependencies"] || {}
        return unless dependencies.is_a?(Hash) && dependencies.key?("ruby_runtime")

        override_path = discover_local_ruby_runtime_path(client_dir)
        return unless override_path

        overrides_path = File.join(client_dir, "pubspec_overrides.yaml")
        content = <<~YAML
          dependency_overrides:
            ruby_runtime:
              path: #{override_path}
        YAML
        File.write(overrides_path, content)
      rescue StandardError => e
        warn "Failed to prepare ruby_runtime override: #{e.class}: #{e.message}"
      end

      def discover_local_ruby_runtime_path(client_dir)
        candidates = []

        env_path = ENV["RUFLET_RUBY_RUNTIME_PATH"].to_s.strip
        candidates << env_path unless env_path.empty?
        candidates << File.expand_path("../ruby_runtime", client_dir)
        candidates << File.expand_path("../../../../../ruby_runtime", __dir__)

        candidates.find do |path|
          next false if path.to_s.empty?

          File.file?(File.join(path, "pubspec.yaml"))
        end
      end

      def normalize_extension_key(value)
        key = value.to_s.strip.downcase
        return nil if key.empty?

        key.tr!("-", "_")
        key.gsub!(/\A(flet_)+/, "")
        key.gsub!(/\Aservice_/, "")
        key
      end

      def prune_client_pubspec(path, selected_packages)
        data = YAML.safe_load(File.read(path), aliases: true) || {}
        deps = (data["dependencies"] || {}).dup

        deps.keys.each do |name|
          next unless name.start_with?("flet_")
          next if name == "flet"
          next if selected_packages.include?(name)

          deps.delete(name)
        end

        data["dependencies"] = deps
        File.write(path, YAML.dump(data))
      end

      def prune_client_main(path, selected_aliases)
        lines = File.readlines(path)
        alias_to_package = {}

        lines.each do |line|
          match = line.match(%r{\Aimport 'package:(flet_[^/]+)/\1\.dart' as ([a-zA-Z0-9_]+);})
          next unless match

          alias_to_package[match[2]] = match[1]
        end

        kept = lines.select do |line|
          import_match = line.match(%r{\Aimport 'package:(flet_[^/]+)/\1\.dart' as ([a-zA-Z0-9_]+);})
          if import_match
            package_name = import_match[1]
            next true if package_name == "flet"
            next true if selected_aliases.include?(import_match[2])
            next false
          end

          extension_match = line.match(/\A\s*([a-zA-Z0-9_]+)\.Extension\(\),\s*\z/)
          if extension_match
            extension_alias = extension_match[1]
            package_name = alias_to_package[extension_alias]
            next true if package_name.nil?
            next true if selected_aliases.include?(extension_alias)
            next false
          end

          true
        end

        File.write(path, kept.join)
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
          ["build", "apk"]
        when "aab", "appbundle"
          ["build", "appbundle"]
        when "ios"
          ["build", "ios", "--no-codesign"]
        when "web"
          ["build", "web"]
        when "macos"
          ["build", "macos"]
        when "windows"
          ["build", "windows"]
        when "linux"
          ["build", "linux"]
        else
          nil
        end
      end
    end
  end
end

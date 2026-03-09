# frozen_string_literal: true

require "fileutils"
require "yaml"

module Ruflet
  module CLI
    module NewCommand
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

      def command_new(args)
        app_name = args.shift
        if app_name.nil? || app_name.strip.empty?
          warn "Usage: ruflet new <appname>"
          return 1
        end

        root = File.expand_path(app_name, Dir.pwd)
        if Dir.exist?(root)
          warn "Directory already exists: #{root}"
          return 1
        end

        FileUtils.mkdir_p(root)
        File.write(File.join(root, "main.rb"), format(Ruflet::CLI::MAIN_TEMPLATE, app_title: humanize_name(File.basename(root))))
        File.write(File.join(root, "Gemfile"), Ruflet::CLI::GEMFILE_TEMPLATE)
        File.write(File.join(root, "README.md"), format(Ruflet::CLI::README_TEMPLATE, app_name: File.basename(root)))
        write_default_ruflet_config(root, File.basename(root))
        copy_ruflet_client_template(root)
        configure_ruflet_client(root)

        project_name = File.basename(root)
        puts "Ruflet app created: #{project_name}"
        puts "Run:"
        puts "  cd #{project_name}"
        puts "  bundle install"
        puts "  bundle exec ruflet run main.rb"
        puts
        puts "Client template:"
        puts "  cd ruflet_client"
        puts "  flutter pub get"
        puts "  flutter run"
        0
      end

      private

      def copy_ruflet_client_template(root)
        template_root = File.expand_path("../../../../../ruflet_client", __dir__)
        return unless Dir.exist?(template_root)

        target = File.join(root, "ruflet_client")
        FileUtils.cp_r(template_root, target)
        prune_client_template(target)
      end

      def prune_client_template(target)
        paths = %w[
          .dart_tool
          .idea
          build
          ios/Pods
          ios/.symlinks
          ios/Podfile.lock
          macos/Pods
          macos/Podfile.lock
          android/.gradle
          android/.kotlin
          android/local.properties
        ]
        paths.each do |path|
          full = File.join(target, path)
          FileUtils.rm_rf(full) if File.exist?(full)
        end
      end

      def write_default_ruflet_config(root, app_name)
        File.write(File.join(root, "ruflet.yaml"), <<~YAML)
          app:
            name: #{app_name}
            # Optional production client endpoint used by `ruflet build`.
            # Example: https://api.example.com
            ruflet_client_url: ""

          # Source of truth for Flutter client extensions/plugins.
          # Examples: camera, video, audio, flashlight, webview, map
          services: []

          # Build assets configuration consumed by `ruflet build`.
          # Paths are relative to this file unless absolute.
          assets:
            dir: assets
            splash_screen: assets/splash.png
            icon_launcher: assets/icon.png

          build:
            splash_color: "#FFFFFF"
            splash_dark_color: "#0B0B0B"
            icon_background: "#FFFFFF"
            theme_color: "#FFFFFF"
        YAML
      end

      def configure_ruflet_client(root)
        config_path = File.join(root, "ruflet.yaml")
        return unless File.file?(config_path)

        config = YAML.safe_load(File.read(config_path), aliases: true) || {}
        extension_keys = extract_extension_keys(config)
        extension_packages = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:package) }.uniq
        extension_aliases = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:alias) }.uniq

        client_dir = File.join(root, "ruflet_client")
        apply_client_manifest!(client_dir, extension_packages, extension_aliases)
      rescue StandardError => e
        warn "Failed to configure ruflet_client from ruflet.yaml: #{e.class}: #{e.message}"
      end

      def extract_extension_keys(config)
        from_services = Array(config["services"])

        from_services
          .map { |v| normalize_extension_key(v) }
          .compact
          .uniq
      end

      def normalize_extension_key(value)
        key = value.to_s.strip.downcase
        return nil if key.empty?

        key.tr!("-", "_")
        key.gsub!(/\A(flet_)+/, "")
        key.gsub!(/\Aservice_/, "")
        key.gsub!(/\Acontrol_/, "")
        key = "file_picker" if key == "filepicker"
        key
      end

      def apply_client_manifest!(client_dir, extension_packages, extension_aliases)
        return unless Dir.exist?(client_dir)

        pubspec_path = File.join(client_dir, "pubspec.yaml")
        main_path = File.join(client_dir, "lib", "main.dart")
        prune_client_pubspec(pubspec_path, extension_packages) if File.file?(pubspec_path)
        prune_client_main(main_path, extension_aliases) if File.file?(main_path)
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
            next true if package_name.nil? # non-Flet extension lines
            next true if selected_aliases.include?(extension_alias)
            next false
          end

          true
        end

        File.write(path, kept.join)
      end

      def humanize_name(name)
        name.to_s.gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end

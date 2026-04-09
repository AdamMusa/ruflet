# frozen_string_literal: true

require "fileutils"
require "tmpdir"
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
        project_name = File.basename(root)
        puts "Run:"
        puts "  cd #{project_name}"
        puts "  bundle install"
        puts "  bundle exec ruflet run main.rb"
        puts
        puts "Build:"
        puts "  bundle exec ruflet build android --self"
        puts "  bundle exec ruflet build ios --self"
        0
      end

      private

      def copy_ruflet_client_template(root)
        template_root = resolve_ruflet_client_template_root
        return unless Dir.exist?(template_root)

        target = hidden_flutter_client_dir(root)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp_r(template_root, target)
        prune_client_template(target)
      end

      def hidden_flutter_client_dir(root = Dir.pwd)
        File.join(root, "build", ".ruflet", "client")
      end

      def resolve_ruflet_client_template_root
        repo_template = File.expand_path("../../../../../templates/ruflet_flutter_template", __dir__)
        return repo_template if Dir.exist?(repo_template)

        cached_template = cached_ruflet_client_template_root
        return cached_template if Dir.exist?(cached_template)

        fallback = File.expand_path("../../../../../ruflet_client", __dir__)
        return fallback if Dir.exist?(fallback)

        nil
      end

      def ensure_cached_ruflet_client_template!(verbose: false)
        cached_template = cached_ruflet_client_template_root
        return cached_template if Dir.exist?(cached_template)

        download_ruflet_client_template(verbose: verbose)
      end

      def cached_ruflet_client_template_root
        File.join(template_cache_root, "ruflet_flutter_template")
      end

      def template_cache_root
        File.join(Dir.home, ".ruflet", "templates")
      end

      def download_ruflet_client_template(verbose: false)
        target = cached_ruflet_client_template_root
        FileUtils.mkdir_p(template_cache_root)

        Dir.mktmpdir("ruflet-template") do |tmp|
          repo_dir = File.join(tmp, "Ruflet")
          clone_cmd = ["git", "clone", "--depth", "1", "--filter=blob:none", "--sparse", "https://github.com/AdamMusa/Ruflet.git", repo_dir]
          return nil unless run_template_command(clone_cmd, verbose: verbose)
          return nil unless run_template_command(["git", "-C", repo_dir, "sparse-checkout", "set", "templates/ruflet_flutter_template"], verbose: verbose)

          source = File.join(repo_dir, "templates", "ruflet_flutter_template")
          return nil unless Dir.exist?(source)

          FileUtils.rm_rf(target)
          FileUtils.cp_r(source, target)
        end

        target
      rescue StandardError => e
        warn "Failed to fetch Ruflet template: #{e.class}: #{e.message}"
        nil
      end

      def run_template_command(cmd, verbose: false)
        output = verbose ? $stdout : File::NULL
        system(*cmd, out: output, err: verbose ? $stderr : File::NULL)
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
          pubspec_overrides.yaml
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
            display_name: #{humanize_name(app_name)}
            package_name: #{app_name.gsub(/[^a-zA-Z0-9_]+/, "_").downcase}
            organization: com.example
            version: 1.0.0+1
            description: A new Ruflet app.
            # Required for server-driven builds: `ruflet build ios`, `apk`, `web`, etc. without `--self`.
            # Example: https://api.example.com
            backend_url: ""

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

      def humanize_name(name)
        name.to_s.gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end

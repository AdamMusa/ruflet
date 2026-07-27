# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

module Ruflet
  module CLI
    module NewCommand
      TEMPLATE_REPO_URL = ENV.fetch("RUFLET_TEMPLATE_REPO_URL", "https://github.com/AdamMusa/ruflet-template.git")
      TEMPLATE_REPO_REF = ENV.fetch("RUFLET_TEMPLATE_REPO_REF", "main")
      RUNTIME_REPO_URL = ENV.fetch("RUFLET_RUNTIME_REPO_URL", "https://github.com/AdamMusa/ruflet.git")

      CLIENT_EXTENSION_MAP = {
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
        "qrcode_scanner" => { package: "ruflet_qrcode_scanner", alias: "ruflet_qrcode_scanner" },
        "rive" => { package: "flet_rive", alias: "ruflet_rive" },
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
        copy_default_project_assets(root)
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
        template_root = resolve_ruflet_client_template_root || ensure_cached_ruflet_client_template!
        return unless template_root && Dir.exist?(template_root)

        target = hidden_flutter_client_dir(root)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.rm_rf(target)
        FileUtils.cp_r(template_root, target)
        prune_client_template(target)
        write_client_template_revision(target, installed_template_revision(template_root))
      end

      def hidden_flutter_client_dir(root = Dir.pwd)
        File.join(root, "build", "client")
      end

      def resolve_ruflet_client_template_root
        explicit = ENV["RUFLET_TEMPLATE_ROOT"].to_s.strip
        unless explicit.empty?
          explicit_template = [
            explicit,
            File.join(explicit, "templates", "ruflet_flutter_template")
          ].find { |path| valid_ruflet_template?(path) }
          return explicit_template if explicit_template
        end

        sibling_template = File.expand_path(
          "../../../../../../ruflet-template/templates/ruflet_flutter_template",
          __dir__
        )
        return sibling_template if valid_ruflet_template?(sibling_template)

        cached_template = cached_ruflet_client_template_root
        return cached_template if valid_ruflet_template?(cached_template)

        nil
      end

      def ensure_cached_ruflet_client_template!(force: false, verbose: false)
        cached_template = cached_ruflet_client_template_root
        download_ruflet_template(force: force, verbose: verbose)
        Dir.exist?(cached_template) ? cached_template : nil
      end

      def ensure_cached_ruby_runtime!(force: false, verbose: false)
        nil
      end

      def cached_ruflet_client_template_root
        File.join(template_cache_root, "ruflet_flutter_template")
      end

      def cached_ruflet_client_template_revision_path
        File.join(template_cache_root, "ruflet_flutter_template.revision")
      end

      def cached_ruby_runtime_root
        File.join(cache_root, "ruby_runtime")
      end

      def template_cache_root
        File.join(cache_root, "templates")
      end

      def cache_root
        ENV.fetch("RUFLET_CACHE_DIR", File.join(Dir.home, ".ruflet"))
      end

      def download_ruflet_assets(force: false, verbose: false)
        !ensure_cached_ruflet_client_template!(force: force, verbose: verbose).nil?
      end

      def download_ruflet_template(force: false, verbose: false)
        target = cached_ruflet_client_template_root
        remote_revision = remote_template_revision(verbose: verbose)
        current_revision = cached_template_revision
        cache_available = valid_ruflet_template?(target)
        if !force && cache_available && remote_revision && current_revision == remote_revision
          return target
        end
        if !force && cache_available && remote_revision.nil?
          build_log(verbose, "Unable to check the Ruflet template revision; using cached #{current_revision || 'template'}") if respond_to?(:build_log, true)
          return target
        end

        FileUtils.mkdir_p(template_cache_root)

        Dir.mktmpdir("ruflet-assets") do |tmp|
          repo_dir = File.join(tmp, "Ruflet")
          clone_cmd = ["git", "clone", "--depth", "1", "--branch", TEMPLATE_REPO_REF, "--filter=blob:none", "--sparse", TEMPLATE_REPO_URL, repo_dir]
          return target_if_present(target) unless run_template_command(clone_cmd, verbose: verbose)
          return target_if_present(target) unless run_template_command(["git", "-C", repo_dir, "sparse-checkout", "set", "templates/ruflet_flutter_template"], verbose: verbose)

          source = File.join(repo_dir, "templates", "ruflet_flutter_template")
          return target_if_present(target) unless valid_ruflet_template?(source)

          fetched_revision = git_revision(repo_dir) || remote_revision
          staged_target = File.join(tmp, "ruflet_flutter_template")
          FileUtils.cp_r(source, staged_target)
          FileUtils.rm_rf(target)
          FileUtils.mv(staged_target, target)
          File.write(cached_ruflet_client_template_revision_path, "#{fetched_revision}\n") if fetched_revision
        end

        target
      rescue StandardError => e
        warn "Failed to fetch Ruflet template: #{e.class}: #{e.message}"
        target_if_present(target)
      end

      def run_template_command(cmd, verbose: false)
        output = verbose ? $stdout : File::NULL
        env = { "GIT_TERMINAL_PROMPT" => "0" }
        system(env, *cmd, out: output, err: verbose ? $stderr : File::NULL)
      end

      def remote_template_revision(verbose: false)
        return @ruflet_template_remote_revision if defined?(@ruflet_template_remote_revision)

        env = { "GIT_TERMINAL_PROMPT" => "0" }
        stdout, stderr, status = Open3.capture3(env, "git", "ls-remote", TEMPLATE_REPO_URL, "refs/heads/#{TEMPLATE_REPO_REF}")
        warn stderr unless status.success? || !verbose || stderr.empty?
        @ruflet_template_remote_revision = status.success? ? stdout.split.first : nil
      rescue StandardError => e
        warn "Failed to check Ruflet template revision: #{e.message}" if verbose
        @ruflet_template_remote_revision = nil
      end

      def cached_template_revision
        return nil unless File.file?(cached_ruflet_client_template_revision_path)

        File.read(cached_ruflet_client_template_revision_path).strip.then { |value| value.empty? ? nil : value }
      end

      def installed_template_revision(template_root)
        return cached_template_revision if File.expand_path(template_root) == File.expand_path(cached_ruflet_client_template_root)

        git_revision(File.expand_path("../..", template_root))
      end

      def write_client_template_revision(target, revision)
        return unless revision

        File.write(File.join(target, ".ruflet-template-revision"), "#{revision}\n")
      end

      def client_template_current?(target, template_root)
        expected = installed_template_revision(template_root)
        return false unless expected

        marker = File.join(target, ".ruflet-template-revision")
        File.file?(marker) && File.read(marker).strip == expected
      end

      def git_revision(repo_dir)
        stdout, _stderr, status = Open3.capture3("git", "-C", repo_dir, "rev-parse", "HEAD")
        status.success? ? stdout.strip : nil
      rescue StandardError
        nil
      end

      def valid_ruflet_template?(path)
        Dir.exist?(path) && File.file?(File.join(path, "pubspec.yaml")) && File.file?(File.join(path, "lib", "main.dart"))
      end

      def target_if_present(target)
        valid_ruflet_template?(target) ? target : nil
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
            # Required for server-driven builds: `ruflet build ios`, `apk`, `web`, etc. without `--self`.
            # Example: https://api.example.com
            backend_url: ""

          # Optional Flutter client extensions. Only listed extensions are bundled.
          # Examples: audio, charts, code_editor, map, rive, video, webview
          extensions: []

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

        File.write(File.join(root, "services.yaml"), <<~YAML)
          # Application identity used by the Flutter build pipeline. Ruflet derives
          # the mobile identifier as organization.package_name and passes it to
          # change_app_package_name for Android and iOS builds.
          app:
            app_name: #{humanize_name(app_name)}
            package_name: #{app_name.gsub(/[^a-zA-Z0-9_]+/, "_").downcase}
            organization: com.example
            version: 1.0.0+1
            description: A new Ruflet app.

          # Native capabilities that require platform permissions. Ruflet activates
          # the matching client extensions and writes Android/iOS permissions.
          # Supported services: camera, microphone, location, motion
          services: []
        YAML
      end

      def copy_default_project_assets(root)
        assets_dir = File.join(root, "assets")
        FileUtils.mkdir_p(assets_dir)

        default_project_assets_root.each do |source_root|
          next unless Dir.exist?(source_root)

          %w[icon.png splash.png].each do |filename|
            source = File.join(source_root, filename)
            FileUtils.cp(source, File.join(assets_dir, filename)) if File.file?(source)
          end
          return if File.file?(File.join(assets_dir, "icon.png")) && File.file?(File.join(assets_dir, "splash.png"))
        end
      end

      def default_project_assets_root
        [
          File.expand_path("../../../assets", __dir__),
          File.expand_path("../../../../../templates/ruflet_flutter_template/assets", __dir__),
          File.expand_path("../../../../../ruflet_client/assets", __dir__)
        ]
      end

      def humanize_name(name)
        name.to_s.gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end

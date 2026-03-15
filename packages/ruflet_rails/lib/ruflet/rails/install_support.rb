# frozen_string_literal: true

require "fileutils"
require "yaml"

module Ruflet
  module Rails
    module InstallSupport
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

      module_function

      def default_mobile_app_template(app_title:)
        <<~RUBY
          require "ruflet"

          Ruflet.run do |page|
            page.title = #{app_title.inspect}
            count = 0
            count_text = text(count.to_s, size: 40)

            page.add(
              container(
                expand: true,
                alignment: Ruflet::MainAxisAlignment::CENTER,
                content: column(
                  alignment: Ruflet::MainAxisAlignment::CENTER,
                  horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
                  children: [
                    text("You have pushed the button this many times:"),
                    count_text
                  ]
                )
              ),
              floating_action_button: fab(
                icon: Ruflet::MaterialIcons::ADD,
                on_click: ->(_e) do
                  count += 1
                  page.update(count_text, value: count.to_s)
                end
              )
            )
          end
        RUBY
      end

      def default_ruflet_yaml(app_name:)
        <<~YAML
          app:
            name: #{app_name}
            ruflet_client_url: ""

          services: []

          assets:
            splash_screen: assets/splash.png
            icon_launcher: assets/icon.png
        YAML
      end

      def route_snippet(entrypoint: "app/mobile/main.rb", mount_path: "/ws")
        %(mount Ruflet::Rails.mobile(Rails.root.join("#{entrypoint}")), at: "#{mount_path}")
      end

      def client_template_root
        env = ENV["RUFLET_CLIENT_TEMPLATE_DIR"].to_s.strip
        return env if !env.empty? && Dir.exist?(env)

        candidates = [
          File.expand_path("../../../../../ruflet_client", __dir__),
          File.expand_path("../../../../../templates/ruflet_flutter_template", __dir__)
        ]
        candidates.find { |path| Dir.exist?(path) }
      end

      def copy_ruflet_client_template(root)
        template_root = client_template_root
        return false unless template_root

        target = File.join(root, "ruflet_client")
        return true if Dir.exist?(target)

        FileUtils.cp_r(template_root, target)
        prune_client_template(target)
        true
      end

      def prune_client_template(target)
        %w[
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
        ].each do |path|
          full = File.join(target, path)
          FileUtils.rm_rf(full) if File.exist?(full)
        end
      end

      def configure_ruflet_client(root)
        config_path = File.join(root, "ruflet.yaml")
        return unless File.file?(config_path)

        config = YAML.safe_load(File.read(config_path), aliases: true) || {}
        extension_keys = Array(config["services"]).map { |v| normalize_extension_key(v) }.compact.uniq
        extension_packages = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:package) }.uniq
        extension_aliases = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:alias) }.uniq

        client_dir = File.join(root, "ruflet_client")
        return unless Dir.exist?(client_dir)

        prune_client_pubspec(File.join(client_dir, "pubspec.yaml"), extension_packages)
        prune_client_main(File.join(client_dir, "lib", "main.dart"), extension_aliases)
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

      def prune_client_pubspec(path, selected_packages)
        return unless File.file?(path)

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
        return unless File.file?(path)

        lines = File.readlines(path)
        alias_to_package = {}

        lines.each do |line|
          match = line.match(%r{\Aimport 'package:(flet_[^/]+)/\1\.dart' as ([a-zA-Z0-9_]+);})
          alias_to_package[match[2]] = match[1] if match
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
    end
  end
end

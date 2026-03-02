# frozen_string_literal: true

require "fileutils"

module Ruflet
  module CLI
    module NewCommand
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
        FileUtils.mkdir_p(File.join(root, ".bundle"))
        File.write(File.join(root, "main.rb"), format(Ruflet::CLI::MAIN_TEMPLATE, app_title: humanize_name(File.basename(root))))
        File.write(File.join(root, "Gemfile"), Ruflet::CLI::GEMFILE_TEMPLATE)
        File.write(File.join(root, ".bundle", "config"), Ruflet::CLI::BUNDLE_CONFIG_TEMPLATE)
        File.write(File.join(root, "README.md"), format(Ruflet::CLI::README_TEMPLATE, app_name: File.basename(root)))
        copy_ruflet_client_template(root)

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

      def humanize_name(name)
        name.to_s.gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end

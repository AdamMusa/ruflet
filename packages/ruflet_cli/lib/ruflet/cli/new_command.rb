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

        project_name = File.basename(root)
        puts "Ruflet app created: #{project_name}"
        puts "Run:"
        puts "  cd #{project_name}"
        puts "  bundle install"
        puts "  bundle exec ruflet run main"
        0
      end

      private

      def humanize_name(name)
        name.to_s.gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end

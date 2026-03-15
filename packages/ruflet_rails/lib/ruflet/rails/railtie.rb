# frozen_string_literal: true

module Ruflet
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "ruflet_rails.middleware" do |app|
        app.middleware.use Ruflet::Rails::Protocol::Middleware
      end

      rake_tasks do
        namespace :ruflet do
          desc "Build Ruflet client for this Rails app. Usage: rake ruflet:build[web]"
          task :build, [:platform] do |_task, args|
            platform = args[:platform].to_s.strip
            if platform.empty?
              warn "Usage: rake ruflet:build[apk|android|ios|aab|web|macos|windows|linux]"
              next
            end

            require "ruflet/cli"
            exit_code = Dir.chdir(::Rails.root) do
              Ruflet::CLI.command_build([platform])
            end
            raise SystemExit, exit_code unless exit_code.to_i.zero?
          end
        end
      end
    end
  end
end

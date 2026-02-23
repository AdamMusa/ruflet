# frozen_string_literal: true

require "fileutils"
require "optparse"
require "rbconfig"

module RubyNative
  module CLI
    module_function

    MAIN_TEMPLATE = <<~RUBY
      require "ruby_native"

      class CounterApp < RubyNative::App
        def initialize
          super
          @count = 0
        end

        def view(page)
          app_name = "%<app_title>s"
          page.title = app_name
          page.vertical_alignment = "center"
          page.horizontal_alignment = "center"

          counter = page.text(value: @count.to_s, size: 48)

          page.add(
            page.column(horizontal_alignment: "center", spacing: 8) do
              text "You have pushed the button this many times"
              counter
            end,
            appbar: page.app_bar(
              bgcolor: "#2196F3",
              color: "#FFFFFF",
              title: page.text(value: app_name)
            ),
            floating_action_button: page.fab("+", bgcolor: "#2196F3",
              color: "#FFFFFF", on_click: ->(e) {
              @count += 1
              e.page.update(counter, value: @count.to_s)
            })
          )
        end
      end

      CounterApp.new.run
    RUBY

    GEMFILE_TEMPLATE = <<~GEMFILE
      source "https://rubygems.org"

      gem "ruby_native", path: "%<gem_path>s"
    GEMFILE

    BUNDLE_CONFIG_TEMPLATE = <<~YAML
      ---
      BUNDLE_PATH: "vendor/bundle"
      BUNDLE_DISABLE_SHARED_GEMS: "true"
    YAML

    README_TEMPLATE = <<~MD
      # %<app_name>s

      RubyNative app.

      ## Setup

      ```bash
      bundle install
      ```

      ## Run

      ```bash
      bundle exec ruby_native run main
      ```

      ## Build

      ```bash
      bundle exec ruby_native build apk
      bundle exec ruby_native build ios
      ```
    MD

    def run(argv = ARGV)
      command = (argv.shift || "help").downcase

      case command
      when "new"
        command_new(argv)
      when "run"
        command_run(argv)
      when "build"
        command_build(argv)
      when "bootstrap", "init"
        command_new(argv)
      when "help", "-h", "--help"
        print_help
        0
      else
        warn "Unknown command: #{command}"
        print_help
        1
      end
    end

    def command_new(args)
      app_name = args.shift
      if app_name.nil? || app_name.strip.empty?
        warn "Usage: ruby_native new <appname>"
        return 1
      end

      root = File.expand_path(app_name, Dir.pwd)
      if Dir.exist?(root)
        warn "Directory already exists: #{root}"
        return 1
      end

      FileUtils.mkdir_p(root)
      FileUtils.mkdir_p(File.join(root, ".bundle"))
      File.write(File.join(root, "main.rb"), format(MAIN_TEMPLATE, app_title: humanize_name(File.basename(root))))
      File.write(File.join(root, "Gemfile"), format(GEMFILE_TEMPLATE, gem_path: gem_path_from(root)))
      File.write(File.join(root, ".bundle", "config"), BUNDLE_CONFIG_TEMPLATE)
      File.write(File.join(root, "README.md"), format(README_TEMPLATE, app_name: File.basename(root)))

      puts "RubyNative app created at #{root}"
      puts "Run:"
      puts "  cd #{root}"
      puts "  bundle install"
      puts "  bundle exec ruby_native run main"
      0
    end

    def command_run(args)
      options = { target: "mobile" }
      parser = OptionParser.new do |o|
        o.on("--web") { options[:target] = "web" }
        o.on("--mobile") { options[:target] = "mobile" }
        o.on("--desktop") { options[:target] = "desktop" }
      end
      parser.parse!(args)

      script_token = args.shift || "main"

      script_path = resolve_script(script_token)
      unless script_path
        warn "Script not found: #{script_token}"
        warn "Expected: ./#{script_token}.rb, ./#{script_token}, or explicit file path."
        return 1
      end

      env = { "RUBY_NATIVE_TARGET" => options[:target] }
      cmd =
        if File.file?(File.expand_path("Gemfile", Dir.pwd))
          env["BUNDLE_PATH"] = "vendor/bundle"
          env["BUNDLE_DISABLE_SHARED_GEMS"] = "true"
          bundle_ready = system(env, "bundle", "check", out: File::NULL, err: File::NULL)
          return 1 unless bundle_ready || system(env, "bundle", "install")

          ["bundle", "exec", RbConfig.ruby, script_path]
        else
          [RbConfig.ruby, script_path]
        end

      ok = system(env, *cmd)
      ok ? 0 : 1
    end

    def command_build(args)
      platform = (args.shift || "").downcase
      if platform.empty?
        warn "Usage: ruby_native build <apk|ios|aab|web|macos|windows|linux>"
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
        warn "Set RUBY_NATIVE_CLIENT_DIR or place client at ./ruby_native_client"
        return 1
      end

      ok = system(*flutter_cmd, chdir: client_dir)
      ok ? 0 : 1
    end

    def print_help
      puts <<~HELP
        RubyNative CLI

        Commands:
          ruby_native new <appname>
          ruby_native run [scriptname|path] [--web|--mobile|--desktop]
          ruby_native build <apk|ios|aab|web|macos|windows|linux>
      HELP
    end

    def resolve_script(token)
      path = File.expand_path(token, Dir.pwd)
      return path if File.file?(path)

      candidate = File.expand_path("#{token}.rb", Dir.pwd)
      return candidate if File.file?(candidate)

      nil
    end

    def detect_flutter_client_dir
      env_dir = ENV["RUBY_NATIVE_CLIENT_DIR"]
      return env_dir if env_dir && Dir.exist?(env_dir)

      local = File.expand_path("ruby_native_client", Dir.pwd)
      return local if Dir.exist?(local)

      nil
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

    def gem_path_from(app_root)
      cli_root = File.expand_path("../..", __dir__)
      monorepo_umbrella = File.expand_path("../ruby_native", cli_root)
      ruby_native_root = Dir.exist?(monorepo_umbrella) ? monorepo_umbrella : cli_root
      app_root = File.expand_path(app_root)

      begin
        require "pathname"
        Pathname.new(ruby_native_root).relative_path_from(Pathname.new(app_root)).to_s
      rescue StandardError
        ruby_native_root
      end
    end

    def humanize_name(name)
      name.to_s.gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
    end

    def bootstrap(path)
      command_new([path || Dir.pwd])
      0
    end
  end
end

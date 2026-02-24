# frozen_string_literal: true

require "fileutils"
require "optparse"
require "rbconfig"
require "socket"

module RubyNative
  module CLI
    module_function

    MAIN_TEMPLATE = <<~RUBY
      require "ruby_native"

      class MainApp < RubyNative::App
        def view(page)
          app_name = "%<app_title>s"
          page.title = app_name

          body = page.column(
            expand: true,
            alignment: RubyNative::MainAxisAlignment::CENTER,
            horizontal_alignment: RubyNative::CrossAxisAlignment::CENTER,
            spacing: 8
          ) do
            text value: "Hello RubyNative", size: 28
            text value: "Edit main.rb and run again", size: 12
          end

          page.add(
            body,
            appbar: page.app_bar(
              bgcolor: "#2196F3",
              color: "#FFFFFF",
              title: page.text(value: app_name)
            ),
            floating_action_button: page.fab("+", bgcolor: "#2196F3", color: "#FFFFFF", on_click: ->(_e) {})
          )
        end
      end

      MainApp.new.run
    RUBY

    GEMFILE_TEMPLATE = <<~GEMFILE
      source "https://rubygems.org"

      RUBY_NATIVE_GIT = "https://github.com/AdamMusa/RubyNative.git"
      RUBY_NATIVE_BRANCH = "main"

      gem "ruby_native_protocol", git: RUBY_NATIVE_GIT, branch: RUBY_NATIVE_BRANCH, glob: "packages/ruby_native_protocol/*.gemspec"
      gem "ruby_native_ui", git: RUBY_NATIVE_GIT, branch: RUBY_NATIVE_BRANCH, glob: "packages/ruby_native_ui/*.gemspec"
      gem "ruby_native_server", git: RUBY_NATIVE_GIT, branch: RUBY_NATIVE_BRANCH, glob: "packages/ruby_native_server/*.gemspec"
      gem "ruby_native", git: RUBY_NATIVE_GIT, branch: RUBY_NATIVE_BRANCH, glob: "packages/ruby_native/*.gemspec"
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
      File.write(File.join(root, "Gemfile"), GEMFILE_TEMPLATE)
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

      env = {
        "RUBY_NATIVE_TARGET" => options[:target],
        "RUBY_NATIVE_SUPPRESS_SERVER_BANNER" => "1"
      }
      print_mobile_qr_hint if options[:target] == "mobile"
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

    def print_mobile_qr_hint(port: 8550)
      host = best_lan_host
      payload = "http://#{host}:#{port}"

      puts
      puts "RubyNative mobile connect URL:"
      puts "  #{payload}"
      puts "RubyNative server ws URL:"
      puts "  ws://0.0.0.0:#{port}/ws"
      puts "Scan this QR from ruby_native_client (Connect -> Scan QR):"
      print_ascii_qr(payload)
      puts
    rescue StandardError => e
      warn "QR setup failed: #{e.class}: #{e.message}"
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

    def best_lan_host
      ips = Socket.ip_address_list
      addr = ips.find { |ip| ip.ipv4_private? && !ip.ipv4_loopback? }
      return addr.ip_address if addr

      "127.0.0.1"
    end

    def print_ascii_qr(payload)
      begin
        require "rqrcode"
      rescue LoadError
        puts "(Install 'rqrcode' gem in CLI package for terminal QR rendering.)"
        return
      end

      q = RQRCode::QRCode.new(payload)
      border = 1
      core = q.modules
      size = core.length + (2 * border)

      matrix = Array.new(size) do |y|
        Array.new(size) do |x|
          cy = y - border
          cx = x - border
          cy >= 0 && cx >= 0 && cy < core.length && cx < core.length && core[cy][cx]
        end
      end

      # Compact square-ish terminal rendering: combine two QR rows into one character row.
      # This stays small and scans better than freeform resizing.
      y = 0
      while y < size
        line = +""
        (0...size).each do |x|
          top = matrix[y][x]
          bottom = (y + 1 < size) ? matrix[y + 1][x] : false
          line << if top && bottom
            "\u2588" # full block
          elsif top
            "\u2580" # upper half block
          elsif bottom
            "\u2584" # lower half block
          else
            " "
          end
        end
        puts line
        y += 2
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

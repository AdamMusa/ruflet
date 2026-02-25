# frozen_string_literal: true

require "fileutils"
require "optparse"
require "rbconfig"
require "socket"

module Ruflet
  module CLI
    module_function

    MAIN_TEMPLATE = <<~RUBY
      require "ruflet"

      class MainApp < Ruflet::App
        def initialize
          super
          @count = 0
        end

        def view(page)
          page.title = "Counter Demo"
          page.vertical_alignment = Ruflet::MainAxisAlignment::CENTER
          page.horizontal_alignment = Ruflet::CrossAxisAlignment::CENTER
          count_text = page.text(value: @count.to_s, size: 40)

          page.add(
            page.container(
              expand: true,
              padding: 24,
              content: page.column(
                expand: true,
                alignment: Ruflet::MainAxisAlignment::CENTER,
                horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
                spacing: 12,
                controls: [
                  page.text(value: "You have pushed the button this many times:"),
                  count_text
                ]
              )
            ),
            appbar: page.app_bar(
              title: page.text(value: "Counter Demo")
            ),
            floating_action_button: page.fab(
              page.icon(icon: Ruflet::MaterialIcons::ADD),
              on_click: ->(_e) {
                @count += 1
                page.update(count_text, value: @count.to_s)
              }
            )
          )
        end
      end

      MainApp.new.run

    RUBY

    GEMFILE_TEMPLATE = <<~GEMFILE
      source "https://rubygems.org"

      RUFLET_GIT = "https://github.com/AdamMusa/Ruflet.git"
      RUFLET_BRANCH = "main"

      gem "ruflet_protocol", git: RUFLET_GIT, branch: RUFLET_BRANCH, glob: "packages/ruflet_protocol/*.gemspec"
      gem "ruflet_ui", git: RUFLET_GIT, branch: RUFLET_BRANCH, glob: "packages/ruflet_ui/*.gemspec"
      gem "ruflet_server", git: RUFLET_GIT, branch: RUFLET_BRANCH, glob: "packages/ruflet_server/*.gemspec"
      gem "ruflet", git: RUFLET_GIT, branch: RUFLET_BRANCH, glob: "packages/ruflet/*.gemspec"
    GEMFILE

    BUNDLE_CONFIG_TEMPLATE = <<~YAML
      ---
      BUNDLE_PATH: "vendor/bundle"
      BUNDLE_DISABLE_SHARED_GEMS: "true"
    YAML

    README_TEMPLATE = <<~MD
      # %<app_name>s

      Ruflet app.

      ## Setup

      ```bash
      bundle install
      ```

      ## Run

      ```bash
      bundle exec ruflet run main
      ```

      ## Build

      ```bash
      bundle exec ruflet build apk
      bundle exec ruflet build ios
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
      File.write(File.join(root, "main.rb"), format(MAIN_TEMPLATE, app_title: humanize_name(File.basename(root))))
      File.write(File.join(root, "Gemfile"), GEMFILE_TEMPLATE)
      File.write(File.join(root, ".bundle", "config"), BUNDLE_CONFIG_TEMPLATE)
      File.write(File.join(root, "README.md"), format(README_TEMPLATE, app_name: File.basename(root)))
      project_name = File.basename(root)
      puts "Ruflet app created: #{project_name}"
      puts "Run:"
      puts "  cd #{project_name}"
      puts "  bundle install"
      puts "  bundle exec ruflet run main"
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
        "RUFLET_TARGET" => options[:target],
        "RUFLET_SUPPRESS_SERVER_BANNER" => "1"
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
      puts "Ruflet mobile connect URL:"
      puts "  #{payload}"
      puts "Ruflet server ws URL:"
      puts "  ws://0.0.0.0:#{port}/ws"
      puts "Scan this QR from ruflet_client (Connect -> Scan QR):"
      print_ascii_qr(payload)
      puts
    rescue StandardError => e
      warn "QR setup failed: #{e.class}: #{e.message}"
    end

    def command_build(args)
      platform = (args.shift || "").downcase
      if platform.empty?
        warn "Usage: ruflet build <apk|ios|aab|web|macos|windows|linux>"
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

      ok = system(*flutter_cmd, chdir: client_dir)
      ok ? 0 : 1
    end

    def print_help
      puts <<~HELP
        Ruflet CLI

        Commands:
          ruflet new <appname>
          ruflet run [scriptname|path] [--web|--mobile|--desktop]
          ruflet build <apk|ios|aab|web|macos|windows|linux>
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
      env_dir = ENV["RUFLET_CLIENT_DIR"]
      return env_dir if env_dir && Dir.exist?(env_dir)

      local = File.expand_path("ruflet_client", Dir.pwd)
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

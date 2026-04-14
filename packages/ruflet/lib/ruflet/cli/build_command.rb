# frozen_string_literal: true

require "fileutils"
require "find"
require "json"
require "pathname"
require "rbconfig"
require "uri"
require "yaml"

module Ruflet
  module CLI
    module BuildCommand
      include FlutterSdk
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

      def command_build(args)
        self_contained = args.delete("--self")
        verbose = args.delete("--verbose") || args.delete("-v")
        platform = (args.shift || "").downcase
        if platform.empty?
          warn "Usage: ruflet build <apk|android|ios|aab|web|macos|windows|linux> [--self] [--verbose]"
          return 1
        end

        flutter_cmd = flutter_build_command(platform)
        unless flutter_cmd
          warn "Unsupported build target: #{platform}"
          return 1
        end

        client_dir = ensure_flutter_client_dir(verbose: !!verbose)
        unless client_dir
          warn "Could not find Flutter client directory."
          warn "Set RUFLET_CLIENT_DIR or let Ruflet manage the hidden client under ./build/.ruflet/client"
          return 1
        end

        config = load_ruflet_config
        tools = ensure_flutter!("build", client_dir: client_dir)
        command_env = build_tool_env(tools[:env], platform, client_dir)
        ok = prepare_flutter_client(
          client_dir,
          platform: platform,
          tools: tools.merge(env: command_env),
          config: config,
          self_contained: !!self_contained,
          verbose: !!verbose
        )
        return 1 unless ok

        build_args = [*flutter_cmd, *args]
        target_entrypoint = flutter_target_entrypoint(client_dir, self_contained: !!self_contained)
        build_args += ["--target", target_entrypoint] if target_entrypoint
        backend_url = configured_backend_url(config)
        if self_contained
          build_args += ["--dart-define", "RUFLET_BACKEND_URL=#{backend_url}"] if backend_url
        else
          unless backend_url
            warn "build config error: backend_url is required for server-driven builds"
            warn "Set app.backend_url or backend_url in ruflet.yaml"
            return 1
          end
          build_args += ["--dart-define", "RUFLET_BACKEND_URL=#{backend_url}"]
        end
        build_args << "-v" if verbose

        build_log(verbose, "mode=#{self_contained ? 'self' : 'server'}")
        build_log(verbose, "client_dir=#{client_dir}")
        build_log(verbose, "flutter=#{tools[:flutter]}")
        build_log(verbose, "dart=#{tools[:dart]}")
        build_log(verbose, "target=#{target_entrypoint}") if target_entrypoint
        build_log(verbose, "command=#{([tools[:flutter]] + build_args).join(' ')}")

        ok = run_external_command(command_env, tools[:flutter], *build_args, chdir: client_dir, unbundled: true)
        export_platform_build_outputs(client_dir, platform, verbose: !!verbose) if ok
        ok ? 0 : 1
      end

      def command_install(args)
        verbose = args.delete("--verbose") || args.delete("-v")
        device_id = extract_option_value!(args, "--device", "-d")

        client_dir = ensure_flutter_client_dir(verbose: !!verbose)
        unless client_dir
          warn "Could not find Flutter client directory."
          warn "Set RUFLET_CLIENT_DIR or let Ruflet manage the hidden client under ./build/.ruflet/client"
          return 1
        end

        tools = ensure_flutter!("install", client_dir: client_dir)
        command_env = install_tool_env(tools[:env], client_dir)
        unless sync_built_outputs_for_install(client_dir, verbose: !!verbose)
          warn "Could not find built app outputs under ./build"
          warn "Run `ruflet build ...` first, then `ruflet install`."
          return 1
        end

        install_args = ["install"]
        install_args += ["-d", device_id] if device_id
        install_args << "-v" if verbose

        build_log(verbose, "client_dir=#{client_dir}")
        build_log(verbose, "flutter=#{tools[:flutter]}")
        build_log(verbose, "dart=#{tools[:dart]}")
        build_log(verbose, "install_command=#{([tools[:flutter]] + install_args).join(' ')}")
        build_note("Installing app#{device_id ? " to device #{device_id}" : ""}")

        ok = run_external_command(command_env, tools[:flutter], *install_args, chdir: client_dir, unbundled: true)
        ok ? 0 : 1
      end

      private

      def extract_option_value!(args, *flags)
        flags.each do |flag|
          index = args.index(flag)
          next unless index

          value = args[index + 1]
          args.slice!(index, 2)
          return value
        end
        nil
      end

      def ensure_flutter_client_dir(verbose: false)
        client_dir = detect_flutter_client_dir
        return client_dir if client_dir

        bootstrapped = bootstrap_flutter_client_template
        build_log(verbose, "bootstrapped client template at #{bootstrapped}") if bootstrapped
        bootstrapped
      end

      def build_tool_env(env, platform, client_dir = nil)
        return env unless %w[ios macos].include?(platform)

        apple_env = unbundled_command_env(env)
        apple_env["PATH"] = apple_build_path(apple_env["PATH"])
        install_apple_pod_shim(client_dir, apple_env) if client_dir
        apple_env
      end

      def install_tool_env(env, client_dir)
        return build_tool_env(env, inferred_install_platform, client_dir) if inferred_install_platform

        command_env = unbundled_command_env(env)
        command_env["PATH"] = apple_build_path(command_env["PATH"])
        install_apple_pod_shim(client_dir, command_env)
        command_env
      end

      def inferred_install_platform
        host_os = RbConfig::CONFIG["host_os"]
        return "ios" if host_os.match?(/darwin/i)

        nil
      end

      def export_platform_build_outputs(client_dir, platform, verbose: false)
        exports_for(platform).each do |relative_source, relative_target|
          source = File.join(client_dir, "build", relative_source)
          next unless File.exist?(source)

          target = File.join(user_build_root, relative_target)
          FileUtils.rm_rf(target)
          FileUtils.mkdir_p(File.dirname(target))
          FileUtils.cp_r(source, target)
          build_log(verbose, "exported #{source} -> #{target}")
        end
      end

      def sync_built_outputs_for_install(client_dir, verbose: false)
        synced = false

        %w[android ios macos windows linux web apk aab appbundle].each do |platform|
          exports_for(platform).each do |relative_source, relative_target|
            source = File.join(user_build_root, relative_target)
            next unless File.exist?(source)

            target = File.join(client_dir, "build", relative_source)
            FileUtils.rm_rf(target)
            FileUtils.mkdir_p(File.dirname(target))
            FileUtils.cp_r(source, target)
            build_log(verbose, "synced #{source} -> #{target}")
            synced = true
          end
        end

        synced
      end

      def exports_for(platform)
        case platform
        when "apk", "android", "aab", "appbundle"
          { File.join("app", "outputs") => "android" }
        when "ios"
          { "ios" => "ios" }
        when "macos"
          { "macos" => "macos" }
        when "windows"
          { "windows" => "windows" }
        when "linux"
          { "linux" => "linux" }
        when "web"
          { "web" => "web" }
        else
          {}
        end
      end

      def detect_flutter_client_dir
        env_dir = ENV["RUFLET_CLIENT_DIR"]
        return env_dir if env_dir && Dir.exist?(env_dir)

        hidden = hidden_flutter_client_dir
        return hidden if Dir.exist?(hidden)

        local = File.expand_path("ruflet_client", Dir.pwd)
        return local if Dir.exist?(local)

        template = File.expand_path("templates/ruflet_flutter_template", Dir.pwd)
        return template if Dir.exist?(template)

        nil
      end

      def bootstrap_flutter_client_template
        return nil if ENV["RUFLET_CLIENT_DIR"]

        target = hidden_flutter_client_dir
        return target if Dir.exist?(target)

        if Ruflet::CLI.respond_to?(:copy_ruflet_client_template, true)
          Ruflet::CLI.send(:copy_ruflet_client_template, Dir.pwd)
        end

        Dir.exist?(target) ? target : nil
      end

      def hidden_flutter_client_dir(root = Dir.pwd)
        File.join(root, "build", ".ruflet", "client")
      end

      def user_build_root(root = Dir.pwd)
        File.join(root, "build")
      end

      def prepare_flutter_client(client_dir, platform:, tools:, config:, self_contained: false, verbose: false)
        sync_client_metadata(client_dir, config, verbose: verbose)
        configure_client_runtime_mode(client_dir, self_contained: self_contained, verbose: verbose)
        apply_service_extension_config(client_dir, config)
        asset_flags = apply_build_config(client_dir, config)
        if asset_flags[:error]
          warn asset_flags[:error]
          return false
        end
        announce_asset_configuration(asset_flags)
        clear_flutter_build_state(client_dir, verbose: verbose)
        build_log(verbose, "running flutter pub get")
        unless run_external_command(tools[:env], tools[:flutter], "pub", "get", chdir: client_dir, unbundled: true)
          warn "flutter pub get failed"
          return false
        end

        unless ensure_native_build_dependencies(client_dir, platform, tools[:env], verbose: verbose)
          return false
        end

        if asset_flags[:has_splash]
          build_note("Generating splash screen with flutter_native_splash")
          build_log(verbose, "running flutter_native_splash:create")
          unless run_external_command(tools[:env], tools[:dart], "run", "flutter_native_splash:create", chdir: client_dir, unbundled: true)
            warn "flutter_native_splash failed"
            return false
          end
        end

        if asset_flags[:has_icon]
          build_note("Generating launcher icons with flutter_launcher_icons")
          build_log(verbose, "running flutter_launcher_icons")
          unless run_external_command(tools[:env], tools[:dart], "run", "flutter_launcher_icons", chdir: client_dir, unbundled: true)
            warn "flutter_launcher_icons failed"
            return false
          end
        end

        true
      end

      def ensure_native_build_dependencies(client_dir, platform, env, verbose: false)
        case platform
        when "ios"
          ensure_cocoapods_install(client_dir, "ios", env, verbose: verbose)
        when "macos"
          ok = true
          ok &&= ensure_cocoapods_install(client_dir, "ios", env, verbose: verbose)
          ok &&= ensure_cocoapods_install(client_dir, "macos", env, verbose: verbose)
          ok
        else
          true
        end
      end

      def ensure_cocoapods_install(client_dir, platform_dir, env, verbose: false)
        pod_dir = File.join(client_dir, platform_dir)
        return true unless Dir.exist?(pod_dir)
        return true unless File.file?(File.join(pod_dir, "Podfile"))

        build_note("Running CocoaPods install for #{platform_dir}")
        build_log(verbose, "pod install in #{pod_dir}")
        ok =
          if defined?(Bundler) && Bundler.respond_to?(:with_unbundled_env)
            Bundler.with_unbundled_env do
              run_external_command(unbundled_command_env(env), "pod", "install", chdir: pod_dir, unbundled: false)
            end
          else
            run_external_command(unbundled_command_env(env), "pod", "install", chdir: pod_dir, unbundled: false)
          end
        return true if ok

        warn "CocoaPods install failed for #{platform_dir}"
        warn "Make sure `pod` is installed and working for the Ruby used by Flutter."
        false
      end

      def unbundled_command_env(env)
        sanitized_env = env.reject { |key, _value| key.start_with?("BUNDLE_") || key == "RUBYOPT" || key == "RUBYLIB" }
        cleared_env = {}
        ENV.each_key do |key|
          next unless key.start_with?("BUNDLE_") || key == "RUBYOPT" || key == "RUBYLIB" || key.start_with?("GEM_")

          cleared_env[key] = nil
        end

        cleared_env.merge(sanitized_env)
      end

      def run_external_command(env, *cmd, chdir:, unbundled: false)
        if unbundled && defined?(Bundler) && Bundler.respond_to?(:with_unbundled_env)
          Bundler.with_unbundled_env do
            system(env, *cmd, chdir: chdir)
          end
        else
          system(env, *cmd, chdir: chdir)
        end
      end

      def apple_build_path(existing_path)
        segments = existing_path.to_s.split(File::PATH_SEPARATOR)
        segments.reject! { |segment| segment.include?("/.gem/ruby/") && segment.end_with?("/bin") }

        preferred = []
        preferred << "/opt/homebrew/bin" if File.executable?("/opt/homebrew/bin/pod")
        preferred << "/usr/local/bin" if File.executable?("/usr/local/bin/pod")

        (preferred + segments).uniq.join(File::PATH_SEPARATOR)
      end

      def install_apple_pod_shim(client_dir, env)
        pod_executable = resolve_working_pod_executable
        return unless pod_executable

        shim_dir = File.join(client_dir, ".ruflet", "bin")
        FileUtils.mkdir_p(shim_dir)
        shim_path = File.join(shim_dir, "pod")
        File.write(
          shim_path,
          <<~SH
            #!/bin/sh
            exec "#{pod_executable}" "$@"
          SH
        )
        FileUtils.chmod("+x", shim_path)
        env["PATH"] = ([shim_dir] + env["PATH"].to_s.split(File::PATH_SEPARATOR)).uniq.join(File::PATH_SEPARATOR)
        env["COCOAPODS_DISABLE_STATS"] = "true"
        env["GEM_HOME"] = nil
        env["GEM_PATH"] = nil
        env["GEM_ROOT"] = nil
      end

      def resolve_working_pod_executable
        return "/opt/homebrew/bin/pod" if File.executable?("/opt/homebrew/bin/pod")
        return "/usr/local/bin/pod" if File.executable?("/usr/local/bin/pod")

        nil
      end

      def configured_backend_url(config)
        candidates = [
          config["backend_url"],
          config["server_url"],
          config["ruflet_client_url"],
          (config["app"].is_a?(Hash) ? config["app"]["backend_url"] : nil),
          (config["app"].is_a?(Hash) ? config["app"]["server_url"] : nil),
          (config["app"].is_a?(Hash) ? config["app"]["ruflet_client_url"] : nil)
        ]
        raw = candidates.find { |v| !v.to_s.strip.empty? }
        return nil if raw.nil?

        value = raw.to_s.strip
        uri = URI.parse(value)
        return nil unless %w[http https ws wss].include?(uri.scheme)
        return nil if uri.host.to_s.strip.empty?

        value
      rescue URI::InvalidURIError
        nil
      end

      def load_ruflet_config
        config_path = ENV["RUFLET_CONFIG"] || "ruflet.yaml"
        unless File.file?(config_path)
          alt = "ruflet.yml"
          config_path = alt if File.file?(alt)
        end
        return {} unless File.file?(config_path)

        YAML.safe_load(File.read(config_path), aliases: true) || {}
      rescue StandardError => e
        warn "Failed to load ruflet config: #{e.class}: #{e.message}"
        {}
      end

      def apply_build_config(client_dir, config = {})
        config_path = ENV["RUFLET_CONFIG"] || (File.file?("ruflet.yaml") ? "ruflet.yaml" : "ruflet.yml")
        config_present = File.file?(config_path)
        build = config["build"] || {}
        assets = config["assets"] || {}
        config_dir = config_present ? File.dirname(File.expand_path(config_path)) : Dir.pwd

        assets_root = build["assets_dir"] || assets["dir"] || config["assets_dir"] || "assets"
        assets_root = File.expand_path(assets_root, config_dir)

        resolve_asset = lambda do |path|
          return nil if path.nil? || path.to_s.strip.empty?
          full = File.expand_path(path.to_s, config_dir)
          return full if File.file?(full)

          rails_full = File.expand_path(File.join("app", path.to_s), config_dir)
          return rails_full if File.file?(rails_full)

          nil
        end

        splash_defined = key_defined?(build, "splash_screen") || key_defined?(assets, "splash_screen") || key_defined?(config, "splash_screen")
        icon_defined = key_defined?(build, "icon_launcher") || key_defined?(assets, "icon_launcher") || key_defined?(config, "icon_launcher")

        splash = resolve_asset.call(build["splash_screen"] || assets["splash_screen"] || config["splash_screen"])
        splash_dark = resolve_asset.call(build["splash_dark"] || build["splash_dark_image"] || assets["splash_dark"])
        icon = resolve_asset.call(build["icon_launcher"] || assets["icon_launcher"] || config["icon_launcher"])
        icon_android = resolve_asset.call(build["icon_android"] || assets["icon_android"])
        icon_ios = resolve_asset.call(build["icon_ios"] || assets["icon_ios"])
        icon_web = resolve_asset.call(build["icon_web"] || assets["icon_web"])
        icon_windows = resolve_asset.call(build["icon_windows"] || assets["icon_windows"])
        icon_macos = resolve_asset.call(build["icon_macos"] || assets["icon_macos"])

        splash_color = build["splash_color"]
        splash_dark_color = build["splash_dark_color"] || build["splash_color_dark"]
        icon_background = build["icon_background"]
        theme_color = build["theme_color"]

        assets_dir = File.join(client_dir, "assets")
        FileUtils.mkdir_p(assets_dir)

        copy_asset = lambda do |src, dest|
          return unless src
          FileUtils.cp(src, File.join(assets_dir, dest))
        end

        copy_asset.call(splash, "splash.png")
        copy_asset.call(splash_dark, "splash_dark.png")
        copy_asset.call(icon, "icon.png")
        copy_asset.call(icon_android, "icon_android.png")
        copy_asset.call(icon_ios, "icon_ios.png")
        copy_asset.call(icon_web, "icon_web.png")
        if icon_windows
          ext = File.extname(icon_windows).downcase
          copy_asset.call(icon_windows, ext == ".ico" ? "icon_windows.ico" : "icon_windows.png")
        end
        copy_asset.call(icon_macos, "icon_macos.png")

        default_splash = File.file?(File.join(assets_dir, "splash.png"))
        default_icon = File.file?(File.join(assets_dir, "icon.png"))

        using_default_splash = false
        using_default_icon = false

        if splash_defined && splash.nil?
          if default_splash
            using_default_splash = true
            build_note("Configured splash_screen was not found; using default template asset assets/splash.png")
          else
            return { has_icon: false, has_splash: false, error: "build config error: splash_screen is set but file was not found, and no default splash asset exists" }
          end
        end
        if icon_defined && icon.nil?
          if default_icon
            using_default_icon = true
            build_note("Configured icon_launcher was not found; using default template asset assets/icon.png")
          else
            return { has_icon: false, has_splash: false, error: "build config error: icon_launcher is set but file was not found, and no default icon asset exists" }
          end
        end

        has_splash = !splash.nil? || default_splash
        has_icon = !icon.nil? || default_icon

        pubspec_path = File.join(client_dir, "pubspec.yaml")
        unless File.file?(pubspec_path)
          return { has_icon: has_icon, has_splash: has_splash, error: nil }
        end

        if has_icon
          update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path", "\"assets/icon.png\"", multiple: true)
        end
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_android", "\"assets/icon_android.png\"", multiple: true) if icon_android
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_ios", "\"assets/icon_ios.png\"", multiple: true) if icon_ios
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_web", "\"assets/icon_web.png\"", multiple: true) if icon_web
        if icon_windows
          ext = File.extname(icon_windows).downcase
          value = ext == ".ico" ? "\"assets/icon_windows.ico\"" : "\"assets/icon_windows.png\""
          update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_windows", value, multiple: true)
        end
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_macos", "\"assets/icon_macos.png\"", multiple: true) if icon_macos
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "background_color", "\"#{icon_background}\"") if icon_background
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "theme_color", "\"#{theme_color}\"") if theme_color

        update_pubspec_value(pubspec_path, "flutter_native_splash", "image", "\"assets/splash.png\"") if has_splash
        update_pubspec_value(pubspec_path, "flutter_native_splash", "image_dark", "\"assets/splash_dark.png\"") if splash_dark
        update_pubspec_value(pubspec_path, "flutter_native_splash", "color", "\"#{splash_color}\"") if splash_color
        update_pubspec_value(pubspec_path, "flutter_native_splash", "color_dark", "\"#{splash_dark_color}\"") if splash_dark_color

        {
          has_icon: has_icon,
          has_splash: has_splash,
          using_default_icon: using_default_icon,
          using_default_splash: using_default_splash,
          error: nil
        }
      end

      def sync_client_metadata(client_dir, config = {}, verbose: false)
        metadata = build_client_metadata(config, client_dir)
        apply_pubspec_metadata(client_dir, metadata)
        apply_android_metadata(client_dir, metadata)
        apply_ios_metadata(client_dir, metadata)
        apply_macos_metadata(client_dir, metadata)
        apply_web_metadata(client_dir, metadata)
        apply_windows_metadata(client_dir, metadata)
        apply_linux_metadata(client_dir, metadata)
        build_log(
          verbose,
          "app=#{metadata[:display_name]} package=#{metadata[:package_name]} org=#{metadata[:organization]} bundle=#{metadata[:bundle_identifier]}"
        )
      end

      def build_client_metadata(config, client_dir)
        app = config["app"].is_a?(Hash) ? config["app"] : {}
        current_pubspec = load_client_pubspec(client_dir)
        current_name = current_pubspec["name"].to_s
        inferred_display_name = app["name"] || config["name"] || humanize_name(File.basename(Dir.pwd))
        package_name = normalize_package_name(app["package_name"] || config["package_name"] || current_name || inferred_display_name)
        display_name = first_present(app["display_name"], app["name"], config["display_name"], config["name"], humanize_name(package_name))
        organization = normalize_bundle_prefix(
          first_present(app["org"], app["organization"], config["org"], config["organization"], "com.example")
        )
        bundle_identifier = normalize_bundle_identifier(
          first_present(app["bundle_identifier"], config["bundle_identifier"], "#{organization}.#{package_name}")
        )

        {
          package_name: package_name,
          display_name: display_name,
          description: first_present(app["description"], config["description"], current_pubspec["description"], "A new Flutter project."),
          version: first_present(app["version"], config["version"], current_pubspec["version"], "1.0.0+1"),
          organization: organization,
          company_name: first_present(app["company_name"], config["company_name"], organization),
          bundle_identifier: bundle_identifier,
          android_application_id: normalize_bundle_identifier(
            first_present(app["android_application_id"], config["android_application_id"], bundle_identifier)
          ),
          ios_bundle_identifier: normalize_bundle_identifier(
            first_present(app["ios_bundle_identifier"], config["ios_bundle_identifier"], bundle_identifier)
          ),
          macos_bundle_identifier: normalize_bundle_identifier(
            first_present(app["macos_bundle_identifier"], config["macos_bundle_identifier"], bundle_identifier)
          ),
          linux_application_id: normalize_bundle_identifier(
            first_present(app["linux_application_id"], config["linux_application_id"], bundle_identifier)
          ),
          short_name: first_present(app["short_name"], config["short_name"], display_name)
        }
      end

      def load_client_pubspec(client_dir)
        pubspec_path = File.join(client_dir, "pubspec.yaml")
        return {} unless File.file?(pubspec_path)

        YAML.safe_load(File.read(pubspec_path), aliases: true) || {}
      rescue StandardError
        {}
      end

      def apply_pubspec_metadata(client_dir, metadata)
        pubspec_path = File.join(client_dir, "pubspec.yaml")
        return unless File.file?(pubspec_path)

        data = YAML.safe_load(File.read(pubspec_path), aliases: true) || {}
        data["name"] = metadata[:package_name]
        data["description"] = metadata[:description]
        data["version"] = metadata[:version]
        File.write(pubspec_path, YAML.dump(data))
      end

      def apply_android_metadata(client_dir, metadata)
        gradle_path = File.join(client_dir, "android", "app", "build.gradle.kts")
        replace_in_file(
          gradle_path,
          /^\s*namespace = ".*"$/,
          %(    namespace = "#{metadata[:android_application_id]}")
        )
        replace_in_file(
          gradle_path,
          /^\s*applicationId = ".*"$/,
          %(        applicationId = "#{metadata[:android_application_id]}")
        )

        manifest_path = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
        replace_in_file(
          manifest_path,
          /android:label="[^"]*"/,
          %(android:label="#{xml_escape(metadata[:display_name])}")
        )
      end

      def apply_ios_metadata(client_dir, metadata)
        info_plist_path = File.join(client_dir, "ios", "Runner", "Info.plist")
        replace_plist_value(info_plist_path, "CFBundleDisplayName", metadata[:display_name])
        replace_plist_value(info_plist_path, "CFBundleName", metadata[:display_name])

        pbxproj_path = File.join(client_dir, "ios", "Runner.xcodeproj", "project.pbxproj")
        return unless File.file?(pbxproj_path)

        content = File.read(pbxproj_path)
        content.gsub!(/INFOPLIST_KEY_CFBundleDisplayName = "[^"]*";/, %(INFOPLIST_KEY_CFBundleDisplayName = "#{xcode_escape(metadata[:display_name])}";))
        content.gsub!(/PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/) do |match|
          identifier = Regexp.last_match(1).to_s.strip
          if identifier.include?("RunnerTests")
            match
          else
            "PRODUCT_BUNDLE_IDENTIFIER = #{metadata[:ios_bundle_identifier]};"
          end
        end
        File.write(pbxproj_path, content)
      end

      def apply_macos_metadata(client_dir, metadata)
        app_info_path = File.join(client_dir, "macos", "Runner", "Configs", "AppInfo.xcconfig")
        replace_in_file(
          app_info_path,
          /^PRODUCT_NAME = .*$/,
          "PRODUCT_NAME = #{metadata[:display_name]}"
        )
        replace_in_file(
          app_info_path,
          /^PRODUCT_BUNDLE_IDENTIFIER = .*$/,
          "PRODUCT_BUNDLE_IDENTIFIER = #{metadata[:macos_bundle_identifier]}"
        )
        replace_in_file(
          app_info_path,
          /^PRODUCT_COPYRIGHT = .*$/,
          "PRODUCT_COPYRIGHT = Copyright © #{Time.now.year} #{metadata[:company_name]}. All rights reserved."
        )
      end

      def apply_web_metadata(client_dir, metadata)
        manifest_path = File.join(client_dir, "web", "manifest.json")
        if File.file?(manifest_path)
          data = JSON.parse(File.read(manifest_path))
          data["name"] = metadata[:display_name]
          data["short_name"] = metadata[:short_name]
          data["description"] = metadata[:description]
          File.write(manifest_path, JSON.pretty_generate(data) + "\n")
        end

        index_path = File.join(client_dir, "web", "index.html")
        replace_in_file(
          index_path,
          /<meta name="description" content="[^"]*">/,
          %(<meta name="description" content="#{html_escape(metadata[:description])}">)
        )
        replace_in_file(
          index_path,
          /<meta name="apple-mobile-web-app-title" content="[^"]*">/,
          %(<meta name="apple-mobile-web-app-title" content="#{html_escape(metadata[:short_name])}">)
        )
        replace_in_file(
          index_path,
          /<title>.*<\/title>/,
          "<title>#{html_escape(metadata[:display_name])}</title>"
        )
      end

      def apply_windows_metadata(client_dir, metadata)
        cmake_path = File.join(client_dir, "windows", "CMakeLists.txt")
        replace_in_file(cmake_path, /^project\(.*\)$/, "project(#{metadata[:package_name]} LANGUAGES CXX)")
        replace_in_file(cmake_path, /^set\(BINARY_NAME ".*"\)$/, %(set(BINARY_NAME "#{metadata[:package_name]}")))

        runner_rc_path = File.join(client_dir, "windows", "runner", "Runner.rc")
        replace_in_file(
          runner_rc_path,
          /VALUE "CompanyName", ".*" "\\0"/,
          %(VALUE "CompanyName", "#{windows_string_escape(metadata[:company_name])}" "\\0")
        )
        replace_in_file(
          runner_rc_path,
          /VALUE "FileDescription", ".*" "\\0"/,
          %(VALUE "FileDescription", "#{windows_string_escape(metadata[:display_name])}" "\\0")
        )
        replace_in_file(
          runner_rc_path,
          /VALUE "InternalName", ".*" "\\0"/,
          %(VALUE "InternalName", "#{windows_string_escape(metadata[:package_name])}" "\\0")
        )
        replace_in_file(
          runner_rc_path,
          /VALUE "LegalCopyright", ".*" "\\0"/,
          %(VALUE "LegalCopyright", "Copyright (C) #{Time.now.year} #{windows_string_escape(metadata[:company_name])}. All rights reserved." "\\0")
        )
        replace_in_file(
          runner_rc_path,
          /VALUE "OriginalFilename", ".*" "\\0"/,
          %(VALUE "OriginalFilename", "#{windows_string_escape(metadata[:package_name])}.exe" "\\0")
        )
        replace_in_file(
          runner_rc_path,
          /VALUE "ProductName", ".*" "\\0"/,
          %(VALUE "ProductName", "#{windows_string_escape(metadata[:display_name])}" "\\0")
        )
      end

      def apply_linux_metadata(client_dir, metadata)
        cmake_path = File.join(client_dir, "linux", "CMakeLists.txt")
        replace_in_file(cmake_path, /^set\(BINARY_NAME ".*"\)$/, %(set(BINARY_NAME "#{metadata[:package_name]}")))
        replace_in_file(cmake_path, /^set\(APPLICATION_ID ".*"\)$/, %(set(APPLICATION_ID "#{metadata[:linux_application_id]}")))
      end

      def replace_plist_value(path, key, value)
        return unless File.file?(path)

        content = File.read(path)
        pattern = %r{(<key>#{Regexp.escape(key)}</key>\s*<string>)(.*?)(</string>)}m
        updated = content.gsub(pattern) do
          "#{Regexp.last_match(1)}#{xml_escape(value)}#{Regexp.last_match(3)}"
        end
        File.write(path, updated) unless updated == content
      end

      def replace_in_file(path, pattern, replacement)
        return unless File.file?(path)

        content = File.read(path)
        updated = content.gsub(pattern, replacement)
        File.write(path, updated) unless updated == content
      end

      def first_present(*values)
        values.find { |value| !value.to_s.strip.empty? }
      end

      def normalize_package_name(value)
        normalized = value.to_s.strip.downcase.gsub(/[^a-z0-9_]+/, "_")
        normalized.gsub!(/\A_+|_+\z/, "")
        normalized.gsub!(/_+/, "_")
        normalized = "ruflet_client" if normalized.empty?
        normalized = "app_#{normalized}" if normalized.match?(/\A\d/)
        normalized
      end

      def normalize_bundle_prefix(value)
        segments = value.to_s.strip.downcase.split(".").map do |segment|
          normalized = segment.gsub(/[^a-z0-9_]+/, "")
          normalized = "app" if normalized.empty?
          normalized = "app#{normalized}" if normalized.match?(/\A\d/)
          normalized
        end
        segments.reject!(&:empty?)
        segments = %w[com example] if segments.empty?
        segments.join(".")
      end

      def normalize_bundle_identifier(value)
        segments = value.to_s.strip.downcase.split(".").map do |segment|
          normalized = segment.gsub(/[^a-z0-9_]+/, "_")
          normalized.gsub!(/\A_+|_+\z/, "")
          normalized = "app" if normalized.empty?
          normalized = "app#{normalized}" if normalized.match?(/\A\d/)
          normalized
        end
        segments.reject!(&:empty?)
        segments = %w[com example ruflet_client] if segments.empty?
        segments.join(".")
      end

      def humanize_name(name)
        name.to_s.gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
      end

      def xml_escape(value)
        value.to_s
             .gsub("&", "&amp;")
             .gsub("<", "&lt;")
             .gsub(">", "&gt;")
             .gsub('"', "&quot;")
             .gsub("'", "&apos;")
      end

      def html_escape(value)
        xml_escape(value)
      end

      def xcode_escape(value)
        value.to_s.gsub("\\", "\\\\\\").gsub('"', '\"')
      end

      def windows_string_escape(value)
        value.to_s.gsub('"', '""')
      end

      def key_defined?(hash, key)
        hash.is_a?(Hash) && (hash.key?(key) || hash.key?(key.to_sym))
      end

      def apply_service_extension_config(client_dir, config = {})
        services = Array(config["services"])
        extension_keys = services.map { |v| normalize_extension_key(v) }.compact.uniq
        extension_packages = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:package) }.uniq
        extension_aliases = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:alias) }.uniq

        pubspec_path = File.join(client_dir, "pubspec.yaml")
        prune_client_pubspec(pubspec_path, extension_packages) if File.file?(pubspec_path)
        client_entrypoint_paths(client_dir).each do |entrypoint|
          prune_client_main(entrypoint, extension_aliases) if File.file?(entrypoint)
        end
      end

      def clear_flutter_build_state(client_dir, verbose: false)
        flutter_build_dir = File.join(client_dir, ".dart_tool", "flutter_build")
        return unless Dir.exist?(flutter_build_dir)

        FileUtils.rm_rf(flutter_build_dir)
        build_log(verbose, "cleared .dart_tool/flutter_build")
      end

      def client_entrypoint_paths(client_dir)
        %w[main.dart main.self.dart main.server.dart].map do |name|
          File.join(client_dir, "lib", name)
        end
      end

      def configure_client_runtime_mode(client_dir, self_contained:, verbose: false)
        build_log(verbose, "configuring #{self_contained ? 'self-contained' : 'server-driven'} runtime")
        sync_client_pubspec_for_runtime_mode(client_dir, self_contained: self_contained)
        if self_contained
          sync_self_contained_project_assets(client_dir, verbose: verbose)
          ensure_local_ruby_runtime_override(client_dir, verbose: verbose)
        else
          remove_self_contained_project_assets(client_dir, verbose: verbose)
          remove_local_ruby_runtime_override(client_dir, verbose: verbose)
        end
      end

      def sync_client_pubspec_for_runtime_mode(client_dir, self_contained:)
        pubspec_path = File.join(client_dir, "pubspec.yaml")
        return unless File.file?(pubspec_path)

        data = YAML.safe_load(File.read(pubspec_path), aliases: true) || {}
        dependencies = data["dependencies"]
        dependencies = data["dependencies"] = {} unless dependencies.is_a?(Hash)
        flutter = data["flutter"]
        flutter = data["flutter"] = {} unless flutter.is_a?(Hash)
        assets = Array(flutter["assets"]).map(&:to_s)

        if self_contained
          dependencies["ruby_runtime"] ||= "^0.0.1"
          assets << "assets/main.rb" unless assets.include?("assets/main.rb")
          assets << "assets/ruby_project/" unless assets.include?("assets/ruby_project/")
        else
          dependencies.delete("ruby_runtime")
          assets.delete("assets/main.rb")
          assets.delete("assets/ruby_project/")
        end

        flutter["assets"] = assets unless assets.empty?
        flutter.delete("assets") if assets.empty?
        File.write(pubspec_path, YAML.dump(data))
      end

      def sync_self_contained_project_assets(client_dir, verbose: false)
        project_root = Pathname.new(Dir.pwd)
        destination_root = File.join(client_dir, "assets", "ruby_project")
        FileUtils.rm_rf(destination_root)
        FileUtils.mkdir_p(destination_root)

        copied = 0
        project_asset_relative_paths.each do |relative_path|
          source = project_root.join(relative_path)
          next unless source.exist? && source.file?

          destination = File.join(destination_root, relative_path)
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(source.to_s, destination)
          copied += 1
        end

        build_log(verbose, "copied #{copied} project file#{copied == 1 ? '' : 's'} to assets/ruby_project")
      end

      def remove_self_contained_project_assets(client_dir, verbose: false)
        destination_root = File.join(client_dir, "assets", "ruby_project")
        return unless Dir.exist?(destination_root)

        FileUtils.rm_rf(destination_root)
        build_log(verbose, "removed assets/ruby_project")
      end

      def project_asset_relative_paths
        root = Pathname.new(Dir.pwd)
        included = []

        Find.find(root.to_s) do |path|
          pathname = Pathname.new(path)
          relative = pathname.relative_path_from(root).to_s
          next if relative.empty?

          if pathname.directory?
            if skip_project_asset_directory?(relative)
              Find.prune
            else
              next
            end
          end

          next unless include_project_asset_file?(relative)

          included << relative
        end

        included.sort
      end

      def skip_project_asset_directory?(relative)
        first = relative.split(File::SEPARATOR).first
        %w[
          .git
          .bundle
          .dart_tool
          .idea
          .vscode
          build
          coverage
          log
          node_modules
          pkg
          ruflet_client
          tmp
          vendor
        ].include?(first)
      end

      def include_project_asset_file?(relative)
        basename = File.basename(relative)
        return false if %w[Gemfile.lock pubspec.lock Podfile.lock package-lock.json yarn.lock pnpm-lock.yaml].include?(basename)
        return true if %w[main.rb Gemfile ruflet.yaml ruflet.yml manifest.json].include?(basename)

        ext = File.extname(relative).downcase
        return true if %w[.rb .json .yml .yaml].include?(ext)

        first = relative.split(File::SEPARATOR).first
        return true if first == "assets"

        false
      end

      def flutter_target_entrypoint(client_dir, self_contained:)
        candidate = File.join(
          client_dir,
          "lib",
          self_contained ? "main.self.dart" : "main.server.dart"
        )
        return nil unless File.file?(candidate)

        File.join("lib", File.basename(candidate))
      end

      def ensure_local_ruby_runtime_override(client_dir, verbose: false)
        pubspec_path = File.join(client_dir, "pubspec.yaml")
        return unless File.file?(pubspec_path)

        pubspec = YAML.safe_load(File.read(pubspec_path), aliases: true) || {}
        dependencies = pubspec["dependencies"] || {}
        return unless dependencies.is_a?(Hash) && dependencies.key?("ruby_runtime")

        override_path = discover_local_ruby_runtime_path(client_dir)
        return unless override_path

        overrides_path = File.join(client_dir, "pubspec_overrides.yaml")
        content = <<~YAML
          dependency_overrides:
            ruby_runtime:
              path: #{override_path}
        YAML
        File.write(overrides_path, content)
        build_log(verbose, "ruby_runtime override=#{override_path}")
      rescue StandardError => e
        warn "Failed to prepare ruby_runtime override: #{e.class}: #{e.message}"
      end

      def remove_local_ruby_runtime_override(client_dir, verbose: false)
        overrides_path = File.join(client_dir, "pubspec_overrides.yaml")
        return unless File.file?(overrides_path)

        File.delete(overrides_path)
        build_log(verbose, "removed ruby_runtime override")
      rescue StandardError => e
        warn "Failed to remove ruby_runtime override: #{e.class}: #{e.message}"
      end

      def discover_local_ruby_runtime_path(client_dir)
        candidates = []

        env_path = ENV["RUFLET_RUBY_RUNTIME_PATH"].to_s.strip
        candidates << env_path unless env_path.empty?
        candidates << File.expand_path("../ruby_runtime", client_dir)
        candidates << File.expand_path("../../../../../ruby_runtime", __dir__)

        candidates.find do |path|
          next false if path.to_s.empty?

          File.file?(File.join(path, "pubspec.yaml"))
        end
      end

      def normalize_extension_key(value)
        key = value.to_s.strip.downcase
        return nil if key.empty?

        key.tr!("-", "_")
        key.gsub!(/\A(flet_)+/, "")
        key.gsub!(/\Aservice_/, "")
        key
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
        content = File.read(path)
        alias_to_package = {}

        content.scan(%r{^import 'package:(flet_[^/]+)/\1\.dart'\s+as ([a-zA-Z0-9_]+);$}m) do |package_name, import_alias|
          alias_to_package[import_alias] = package_name
        end

        content = content.gsub(%r{^import 'package:(flet_[^/]+)/\1\.dart'\s+as ([a-zA-Z0-9_]+);\n}m) do |match|
          package_name = Regexp.last_match(1)
          import_alias = Regexp.last_match(2)
          if package_name == "flet" || selected_aliases.include?(import_alias)
            match
          else
            ""
          end
        end

        content = content.gsub(/^(\s*)([a-zA-Z0-9_]+)\.Extension\(\),\s*$/) do |match|
          extension_alias = Regexp.last_match(2)
          package_name = alias_to_package[extension_alias]
          if package_name.nil? || selected_aliases.include?(extension_alias)
            match
          else
            ""
          end
        end

        File.write(path, content)
      end

      def update_pubspec_value(path, block, key, value, multiple: false)
        lines = File.read(path).split("\n", -1)
        out = []
        in_block = false
        replaced = false
        block_indent = nil
        lines.each do |line|
          if line.start_with?("#{block}:")
            in_block = true
            block_indent = line[/^\s*/] + "  "
            out << line
            next
          end

          if in_block
            if line =~ /^\S/ && !line.start_with?("#{block}:")
              unless replaced
                out << "#{block_indent}#{key}: #{value}"
                replaced = true
              end
              in_block = false
            else
              if line.strip.start_with?("#{key}:")
                indent = line[/^\s*/]
                out << "#{indent}#{key}: #{value}"
                replaced = true
                next
              end
            end
          end

          out << line
        end
        if in_block && !replaced
          out << "#{block_indent}#{key}: #{value}"
        end
        File.write(path, out.join("\n"))
      end

      def flutter_build_command(platform)
        case platform
        when "apk", "android"
          ["build", "apk"]
        when "aab", "appbundle"
          ["build", "appbundle"]
        when "ios"
          ["build", "ios", "--no-codesign"]
        when "web"
          ["build", "web"]
        when "macos"
          ["build", "macos"]
        when "windows"
          ["build", "windows"]
        when "linux"
          ["build", "linux"]
        else
          nil
        end
      end

      def build_log(verbose, message)
        return unless verbose

        puts "[ruflet build] #{message}"
      end

      def build_note(message)
        puts "[ruflet build] #{message}"
      end

      def announce_asset_configuration(asset_flags)
        if asset_flags[:has_splash]
          if asset_flags[:using_default_splash]
            build_note("Splash screen will use the default template asset")
          else
            build_note("Splash screen is configured")
          end
        else
          build_note("No splash screen configured")
        end

        if asset_flags[:has_icon]
          if asset_flags[:using_default_icon]
            build_note("Launcher icons will use the default template asset")
          else
            build_note("Launcher icons are configured")
          end
        else
          build_note("No launcher icons configured")
        end
      end
    end
  end
end

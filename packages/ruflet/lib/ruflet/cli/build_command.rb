# frozen_string_literal: true

require "fileutils"
require "find"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "uri"
require "yaml"

module Ruflet
  module CLI
    module BuildCommand
      include FlutterSdk
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
        "spinkit" => { package: "flet_spinkit", alias: "ruflet_spinkit" },
        "video" => { package: "flet_video", alias: "ruflet_video" },
        "webview" => { package: "flet_webview", alias: "ruflet_webview" }
      }.freeze
      PROTECTED_SERVICE_EXTENSIONS = {
        "camera" => %w[camera permission_handler],
        "microphone" => %w[audio_recorder permission_handler],
        "location" => %w[geolocator permission_handler],
        "motion" => %w[permission_handler]
      }.freeze
      EXTENSION_REQUIRED_SERVICES = {
        "qrcode_scanner" => %w[camera]
      }.freeze
      ANDROID_SERVICE_PERMISSIONS = {
        "camera" => %w[android.permission.CAMERA],
        "microphone" => %w[android.permission.RECORD_AUDIO],
        "location" => %w[android.permission.ACCESS_COARSE_LOCATION android.permission.ACCESS_FINE_LOCATION],
        "motion" => %w[android.permission.ACTIVITY_RECOGNITION android.permission.HIGH_SAMPLING_RATE_SENSORS]
      }.freeze
      IOS_SERVICE_USAGE_KEYS = {
        "camera" => "NSCameraUsageDescription",
        "microphone" => "NSMicrophoneUsageDescription",
        "location" => "NSLocationWhenInUseUsageDescription",
        "motion" => "NSMotionUsageDescription"
      }.freeze
      MANAGED_ANDROID_PERMISSIONS = (
        ANDROID_SERVICE_PERMISSIONS.values.flatten +
        %w[android.permission.FLASHLIGHT android.permission.MODIFY_AUDIO_SETTINGS]
      ).uniq.freeze
      MANAGED_IOS_USAGE_KEYS = (
        IOS_SERVICE_USAGE_KEYS.values +
        %w[NSLocationAlwaysAndWhenInUseUsageDescription NSPhotoLibraryUsageDescription]
      ).uniq.freeze
      # Clients that are told which server to use at launch rather than at build
      # time, so they may be built without a configured backend_url.
      RUNTIME_RESOLVED_BACKEND_PLATFORMS = %w[web macos windows linux].freeze
      # What the underlying generators can actually produce per platform:
      # flutter_native_splash covers android/ios/web, flutter_launcher_icons
      # covers android/ios/web/windows/macos. Linux has neither.
      PLATFORM_ASSET_SUPPORT = {
        "android" => { splash: true, icon: true },
        "ios" => { splash: true, icon: true },
        "web" => { splash: true, icon: true },
        "macos" => { splash: false, icon: true },
        "windows" => { splash: false, icon: true },
        "linux" => { splash: false, icon: false }
      }.freeze

      def command_build(args)
        self_contained = args.delete("--self")
        verbose = args.delete("--verbose") || args.delete("-v")
        platform = (args.shift || "").downcase
        if platform.empty?
          warn "Usage: ruflet build <apk|android|aab|ios|ipa|web|macos|windows|linux> [--self] [--verbose]"
          return 1
        end

        flutter_cmd = flutter_build_command(platform)
        unless flutter_cmd
          warn "Unsupported build target: #{platform}"
          return 1
        end

        # `ipa` produces the uploadable archive; every other step — pods,
        # signing, icons, package name — is the same as a plain iOS build.
        requested_platform = platform
        platform = "ios" if platform == "ipa"

        # The embedded Ruby VM is a native plugin with no browser
        # implementation, so a self-contained web build produces an app that
        # cannot start. Say so rather than shipping one that hangs.
        if self_contained && platform == "web"
          warn "build config error: --self is not supported for web"
          warn "A web client runs no embedded Ruby; build it with `ruflet build web`."
          return 1
        end

        ensure_ruflet_build_assets(verbose: !!verbose)
        client_dir = ensure_flutter_client_dir(verbose: !!verbose)
        unless client_dir
          warn "Could not find Flutter client directory."
          warn "Set RUFLET_CLIENT_DIR or let Ruflet manage the client under ./build/client"
          return 1
        end

        build_note("Preparing #{platform} build (#{self_contained ? 'self-contained' : 'server-driven'})")
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
        build_args << "--codesign" if ios_device_build_needs_codesign_flag?(requested_platform, build_args)
        target_entrypoint = flutter_target_entrypoint(client_dir, self_contained: !!self_contained)
        build_args += ["--target", target_entrypoint] if target_entrypoint
        backend_url = configured_backend_url(config)
        if self_contained
          # Pin the embedded project so main.self.dart extracts assets/<name>/
          # deterministically instead of inferring from a single main.rb — the
          # app tree now ships many main.rb files (standalone_apps/*/main.rb).
          build_args += ["--dart-define", "RUFLET_EMBEDDED_PROJECT=#{self_contained_project_name}"]
        elsif backend_url
          build_args += ["--dart-define", "RUFLET_BACKEND_URL=#{backend_url}"]
        elsif RUNTIME_RESOLVED_BACKEND_PLATFORMS.include?(platform)
          # These clients learn their server at launch: a web client from the
          # origin it is served from, a desktop client from the URL the launcher
          # passes. Baking one in would pin them to a single host and port,
          # which a preview client cannot use.
          build_note("No backend_url configured; the #{platform} client will resolve its server at launch")
        else
          warn "build config error: backend_url is required for server-driven builds"
          warn "Set app.backend_url or backend_url in ruflet.yaml"
          return 1
        end
        build_args << "-v" if verbose
        stage_ios_simulator_ruby_runtime(client_dir, build_args, verbose: !!verbose) if self_contained

        build_log(verbose, "mode=#{self_contained ? 'self' : 'server'}")
        build_log(verbose, "client_dir=#{client_dir}")
        build_log(verbose, "flutter=#{tools[:flutter]}")
        build_log(verbose, "dart=#{tools[:dart]}")
        build_log(verbose, "target=#{target_entrypoint}") if target_entrypoint
        build_log(verbose, "command=#{([tools[:flutter]] + build_args).join(' ')}")

        build_note("Running Flutter #{build_args.join(' ')}")
        ok = run_external_command(command_env, tools[:flutter], *build_args, chdir: client_dir, unbundled: true)

        # A physical iPhone app and a simulator app are different Apple
        # products, but Ruflet users should not have to learn that distinction.
        # Keep both outputs behind the ordinary self-contained iOS build so the
        # following `ruflet install` can target whichever mobile device is
        # connected. An explicit --simulator remains a simulator-only build.
        if ok && self_contained && requested_platform == "ios" && !build_args.include?("--simulator")
          simulator_args = build_args.dup
          simulator_args.delete("--codesign")
          simulator_args.insert(simulator_args.index("ios") + 1, "--simulator")
          stage_ios_simulator_ruby_runtime(client_dir, simulator_args, verbose: !!verbose)
          build_log(verbose, "command=#{([tools[:flutter]] + simulator_args).join(' ')}")
          build_note("Running Flutter #{simulator_args.join(' ')}")
          ok = run_external_command(
            command_env, tools[:flutter], *simulator_args,
            chdir: client_dir, unbundled: true
          )
        end

        export_platform_build_outputs(client_dir, platform, verbose: !!verbose) if ok
        ok ? 0 : 1
      end

      def command_install(args)
        verbose = args.delete("--verbose") || args.delete("-v")
        device_id = extract_option_value!(args, "--device", "-d")

        client_dir = ensure_flutter_client_dir(verbose: !!verbose)
        unless client_dir
          warn "Could not find Flutter client directory."
          warn "Set RUFLET_CLIENT_DIR or let Ruflet manage the client under ./build/client"
          return 1
        end

        tools = ensure_flutter!("install", client_dir: client_dir)
        command_env = install_tool_env(tools[:env], client_dir)
        install_platform = install_platform_for_device(device_id)
        unless sync_built_outputs_for_install(client_dir, platform: install_platform, verbose: !!verbose)
          warn "Could not find built app outputs under ./build"
          warn "Run `ruflet build ...` first, then `ruflet install`."
          return 1
        end
        unless validate_install_artifacts(client_dir, platform: install_platform, device_id: device_id)
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
        if client_dir
          if File.expand_path(client_dir) == File.expand_path(hidden_flutter_client_dir) &&
              !valid_flutter_client_root?(client_dir) &&
              !File.file?(File.join(client_dir, ".metadata"))
            if Ruflet::CLI.respond_to?(:copy_ruflet_client_template, true)
              Ruflet::CLI.send(:copy_ruflet_client_template, Dir.pwd)
              client_dir = hidden_flutter_client_dir
              build_log(verbose, "repaired invalid managed Flutter client root")
            end
          end
          refresh_hidden_flutter_client_template(client_dir, verbose: verbose)
          return client_dir
        end

        bootstrapped = bootstrap_flutter_client_template
        build_log(verbose, "bootstrapped client template at #{bootstrapped}") if bootstrapped
        bootstrapped
      end

      def valid_flutter_client_root?(path)
        File.file?(File.join(path, "pubspec.yaml")) &&
          File.file?(File.join(path, "lib", "main.dart"))
      end

      def refresh_hidden_flutter_client_template(client_dir, verbose: false)
        return unless File.expand_path(client_dir) == File.expand_path(hidden_flutter_client_dir)
        return unless File.file?(File.join(client_dir, ".metadata"))
        return unless Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)

        template_root = Ruflet::CLI.send(:resolve_ruflet_client_template_root)
        return unless template_root && Dir.exist?(template_root)
        return if Ruflet::CLI.respond_to?(:client_template_current?, true) &&
          Ruflet::CLI.send(:client_template_current?, client_dir, template_root)

        Ruflet::CLI.send(:copy_ruflet_client_template, Dir.pwd)
        build_log(verbose, "refreshed managed Flutter client from template #{template_root}")
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

      def sync_built_outputs_for_install(client_dir, platform: nil, verbose: false)
        synced = false

        platforms =
          if platform
            install_sync_platforms(platform)
          else
            %w[android ios macos windows linux web apk aab appbundle]
          end

        platforms.each do |target_platform|
          exports_for(target_platform).each do |relative_source, relative_target|
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

      def install_sync_platforms(platform)
        case platform
        when "ios"
          %w[ios]
        when "android"
          %w[android apk aab appbundle]
        when "macos"
          %w[macos]
        when "windows"
          %w[windows]
        when "linux"
          %w[linux]
        when "web"
          %w[web]
        else
          []
        end
      end

      def install_platform_for_device(device_id)
        return inferred_install_platform unless device_id

        return "android" if device_id.include?("emulator-") || device_id.match?(/\A[a-z0-9._:-]+\z/i) && device_id != "macos" && device_id != "chrome" && !device_id.include?("-")
        return "ios" if device_id.match?(/\A[0-9A-F-]{8,}\z/i)
        return "macos" if device_id == "macos"
        return "web" if device_id == "chrome"

        inferred_install_platform
      end

      def validate_install_artifacts(client_dir, platform:, device_id:)
        return true unless platform == "ios"

        return validate_ios_simulator_install_artifacts(client_dir) if ios_simulator_device_id?(device_id)

        device_app = File.join(client_dir, "build", "ios", "iphoneos", "Runner.app")
        return true unless Dir.exist?(device_app)
        return true if ios_app_signed?(device_app)

        warn "install config error: iOS device app bundle is not code signed"
        warn "Rebuild for a device with: ruflet build ios --self"
        warn "If you intentionally built without signing, install from Xcode or rebuild without --no-codesign."
        false
      end

      def validate_ios_simulator_install_artifacts(client_dir)
        simulator_app = File.join(client_dir, "build", "ios", "iphonesimulator", "Runner.app")
        return true if Dir.exist?(simulator_app)

        device_app = File.join(client_dir, "build", "ios", "iphoneos", "Runner.app")
        if Dir.exist?(device_app)
          warn "install config error: selected device is an iOS simulator, but the latest build is for iphoneos"
          warn "Rebuild for the simulator with: ruflet build ios --self --simulator"
        else
          warn "install config error: no iOS simulator app bundle was found"
          warn "Build the simulator target first with: ruflet build ios --self --simulator"
        end
        false
      end

      def ios_simulator_device_id?(device_id)
        return false if device_id.to_s.strip.empty?

        device_id.match?(/\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\z/i)
      end

      def ios_app_signed?(app_path)
        system("/usr/bin/codesign", "-vv", app_path, out: File::NULL, err: File::NULL)
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

      def ensure_ruflet_build_assets(force: false, verbose: false)
        return true unless respond_to?(:download_ruflet_assets, true)

        !!send(:download_ruflet_assets, force: force, verbose: verbose)
      rescue StandardError => e
        build_log(verbose, "ruflet asset bootstrap skipped: #{e.class}: #{e.message}")
        false
      end

      def hidden_flutter_client_dir(root = Dir.pwd)
        File.join(root, "build", "client")
      end

      def user_build_root(root = Dir.pwd)
        File.join(root, "build")
      end

      def prepare_flutter_client(client_dir, platform:, tools:, config:, self_contained: false, verbose: false)
        refresh_managed_client_template_files(
          client_dir, platform: platform, verbose: verbose)
        metadata = sync_client_metadata(client_dir, config, verbose: verbose)
        return false unless validate_mobile_app_identity(metadata, platform: platform)

        apply_native_service_permissions(client_dir, config)
        apply_android_signing_config(client_dir, platform, verbose: !!verbose)
        apply_ios_signing_team(client_dir, config) if %w[ios ipa macos].include?(platform.to_s)
        configured = configure_client_runtime_mode(client_dir, self_contained: self_contained, verbose: verbose)
        return false if configured == false
        configure_native_apple_runtime(
          client_dir, platform: platform, self_contained: self_contained,
          verbose: verbose)
        @ruflet_self_contained_build = self_contained
        apply_service_extension_config(client_dir, config)
        asset_flags = apply_build_config(client_dir, config)
        if asset_flags[:error]
          warn asset_flags[:error]
          return false
        end
        announce_asset_configuration(asset_flags)
        clear_flutter_build_state(client_dir, verbose: verbose)
        clear_stale_platform_outputs(client_dir, platform, verbose: verbose)
        unless ensure_flutter_platform_artifacts(client_dir, platform, tools[:env], tools[:flutter], verbose: verbose)
          return false
        end
        build_note("Resolving Flutter packages")
        build_log(verbose, "running flutter pub get")
        unless run_external_command(tools[:env], tools[:flutter], "pub", "get", chdir: client_dir, unbundled: true)
          warn "flutter pub get failed"
          return false
        end

        unless apply_mobile_package_name(client_dir, metadata, platform: platform, tools: tools, verbose: verbose)
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

        verify_android_generated_assets(client_dir, asset_flags, platform, verbose: verbose)

        true
      end

      # The generators can succeed while silently skipping Android output, which
      # ships a build with the stock Flutter icon and splash. Confirm the native
      # resources that ruflet.yaml asked for are actually on disk.
      def verify_android_generated_assets(client_dir, asset_flags, platform, verbose: false)
        return true unless %w[apk android aab appbundle].include?(platform.to_s)

        res_dir = File.join(client_dir, "android", "app", "src", "main", "res")
        return true unless File.directory?(res_dir)

        ok = true

        if asset_flags[:has_splash]
          launch_background = File.join(res_dir, "drawable", "launch_background.xml")
          if !File.file?(launch_background) || !read_text_file(launch_background).include?("splash")
            warn "Android splash screen was not generated in res/drawable/launch_background.xml"
            ok = false
          end

          styles_v31 = File.join(res_dir, "values-v31", "styles.xml")
          if !File.file?(styles_v31) || !read_text_file(styles_v31).include?("windowSplashScreenBackground")
            warn "Android 12+ splash screen is missing from res/values-v31/styles.xml; " \
                 "devices on Android 12 and newer will show the system default splash"
            ok = false
          else
            build_log(verbose, "android 12+ splash present in values-v31/styles.xml")
          end
        end

        if asset_flags[:has_icon]
          adaptive_icon = File.join(res_dir, "mipmap-anydpi-v26", "launcher_icon.xml")
          if File.file?(adaptive_icon)
            build_log(verbose, "adaptive launcher icon present in mipmap-anydpi-v26")
          else
            warn "Android adaptive launcher icon was not generated in res/mipmap-anydpi-v26/; " \
                 "set android.adaptive_icon_foreground and android.adaptive_icon_background in ruflet.yaml"
            ok = false
          end

          manifest = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
          if File.file?(manifest) && !read_text_file(manifest).include?("@mipmap/launcher_icon")
            warn "AndroidManifest.xml does not reference @mipmap/launcher_icon; the configured launcher icon is unused"
            ok = false
          end
        end

        build_note("Android launcher icon and splash resources verified") if ok && (asset_flags[:has_icon] || asset_flags[:has_splash])
        ok
      end

      def ensure_flutter_platform_artifacts(client_dir, platform, env, flutter, verbose: false)
        precache_flags = flutter_precache_flags(platform)
        return true if precache_flags.empty?

        build_note("Preparing Flutter #{platform} platform artifacts")
        build_log(verbose, "running flutter precache #{precache_flags.join(' ')}")
        ok = run_external_command(env, flutter, "precache", *precache_flags, chdir: client_dir, unbundled: true)
        return true if ok

        warn "Flutter platform artifact setup failed for #{platform}"
        false
      end

      def flutter_precache_flags(platform)
        case platform
        when "apk", "android", "aab", "appbundle"
          ["--android"]
        when "ios"
          ["--ios"]
        when "macos"
          ["--macos"]
        when "windows"
          ["--windows"]
        when "linux"
          ["--linux"]
        when "web"
          ["--web"]
        else
          []
        end
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

      # CocoaPods can incorrectly treat the static-library XCFramework copy
      # phase as up to date after Ruflet clears Debug-iphonesimulator. The
      # Runner then links with -lruflet_vm while the selected simulator slice
      # is absent. Stage that deterministic slice before Flutter invokes
      # Xcode; CocoaPods may still copy over it normally.
      def stage_ios_simulator_ruby_runtime(client_dir, build_args, verbose: false)
        return true unless build_args.include?("ios")
        return true unless build_args.include?("--simulator")

        runtime_root = explicit_local_ruby_runtime_path || source_checkout_ruby_runtime_path
        return true unless runtime_root

        source = File.join(
          runtime_root,
          "ios",
          "Frameworks",
          "RufletVM.xcframework",
          "ios-arm64_x86_64-simulator"
        )
        library = File.join(source, "libruflet_vm.a")
        return true unless File.file?(library)

        destination = File.join(
          client_dir,
          "build",
          "ios",
          "Debug-iphonesimulator",
          "XCFrameworkIntermediates",
          "ruby_runtime"
        )
        FileUtils.mkdir_p(destination)
        FileUtils.cp(library, File.join(destination, "libruflet_vm.a"))

        headers = File.join(source, "Headers")
        if Dir.exist?(headers)
          destination_headers = File.join(destination, "Headers")
          FileUtils.rm_rf(destination_headers)
          FileUtils.cp_r(headers, destination_headers)
        end

        build_log(verbose, "staged iOS simulator Ruflet VM at #{destination}")
        true
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
        env.reject { |key, _value| key.start_with?("BUNDLE_") || key == "RUBYOPT" || key == "RUBYLIB" || key.start_with?("GEM_") }
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
        write_text_file(
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
        config_exists = File.file?(config_path)
        config = config_exists ? YAML.safe_load(read_text_file(config_path), aliases: true) || {} : {}
        config_dir = File.dirname(File.expand_path(config_path))
        services_path = File.join(config_dir, "services.yaml")
        if File.file?(services_path)
          service_config = YAML.safe_load(read_text_file(services_path), aliases: true) || {}
          if service_config["app"].is_a?(Hash)
            # ruflet.yaml declares the app; services.yaml may still carry an
            # identity from older projects, so it fills gaps rather than
            # overriding what the project states.
            declared = config["app"].is_a?(Hash) ? config["app"] : {}
            config["app"] = service_config["app"].merge(declared)
          end
          config["services"] = service_config["services"] if service_config.key?("services")
        end
        config
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

        # Splash and icon appearance belongs with the assets it styles. `build`
        # is still read first so existing projects keep working.
        splash_color = build["splash_color"] || assets["splash_color"]
        splash_dark_color = build["splash_dark_color"] || build["splash_color_dark"] ||
          assets["splash_dark_color"] || assets["splash_color_dark"]
        icon_background = build["icon_background"] || assets["icon_background"]
        theme_color = build["theme_color"] || assets["theme_color"]

        # Every platform gets its own section with the same key names, falling
        # back to the shared assets/build values when a key is not overridden.
        platforms = PLATFORM_ASSET_SUPPORT.keys.each_with_object({}) do |name, resolved|
          section = platform_build_config(config, name)
          resolved[name] = {
            config: section,
            splash: resolve_asset.call(
              section["splash_screen"] || section["splash_image"] ||
                build["splash_#{name}"] || assets["splash_#{name}"]
            ),
            splash_dark: resolve_asset.call(
              section["splash_dark"] || section["splash_dark_image"] || assets["splash_#{name}_dark"]
            ),
            icon: resolve_asset.call(
              section["icon_launcher"] || section["icon"] ||
                build["icon_#{name}"] || assets["icon_#{name}"]
            ),
            background_image: resolve_asset.call(
              section["splash_background_image"] || section["background_image"] || assets["splash_background_#{name}"]
            ),
            background_image_dark: resolve_asset.call(
              section["splash_background_image_dark"] || section["background_image_dark"]
            ),
            branding: resolve_asset.call(section["splash_branding"] || section["branding"]),
            branding_dark: resolve_asset.call(section["splash_branding_dark"] || section["branding_dark"]),
            splash_color: section["splash_color"] || splash_color,
            splash_dark_color: section["splash_dark_color"] || section["splash_color_dark"] || splash_dark_color,
            icon_background: section["icon_background"] || icon_background,
            theme_color: section["theme_color"] || theme_color
          }
        end

        splash_background_image = resolve_asset.call(
          build["splash_background_image"] || assets["splash_background_image"] || build["background_image"]
        )
        splash_background_image_dark = resolve_asset.call(
          build["splash_background_image_dark"] || assets["splash_background_image_dark"]
        )
        splash_branding = resolve_asset.call(build["splash_branding"] || assets["splash_branding"])
        splash_branding_dark = resolve_asset.call(build["splash_branding_dark"] || assets["splash_branding_dark"])
        splash_branding_mode = build["splash_branding_mode"] || build["branding_mode"] ||
          assets["splash_branding_mode"] || assets["branding_mode"]
        splash_branding_padding = build["splash_branding_bottom_padding"] || build["branding_bottom_padding"] ||
          assets["splash_branding_bottom_padding"] || assets["branding_bottom_padding"]

        android = platforms.dig("android", :config)
        android_splash = platforms.dig("android", :splash)
        android_splash_dark = platforms.dig("android", :splash_dark)
        android_12_splash = resolve_asset.call(
          android["splash_android_12"] || android["android_12_image"] || assets["splash_android_12"]
        )
        android_12_splash_dark = resolve_asset.call(
          android["splash_android_12_dark"] || android["android_12_image_dark"] || assets["splash_android_12_dark"]
        )
        adaptive_foreground = resolve_asset.call(
          android["adaptive_icon_foreground"] || android["icon_foreground"] ||
            assets["icon_adaptive_foreground"] || assets["icon_foreground"]
        )
        adaptive_background_image = resolve_asset.call(
          android["adaptive_icon_background_image"] || assets["icon_adaptive_background_image"]
        )
        adaptive_monochrome = resolve_asset.call(
          android["adaptive_icon_monochrome"] || android["icon_monochrome"] || assets["icon_adaptive_monochrome"]
        )

        android_splash_color = platforms.dig("android", :splash_color)
        android_splash_dark_color = platforms.dig("android", :splash_dark_color)
        android_12_icon_background = android["splash_android_12_icon_background_color"] ||
          android["icon_background_color"] || android_splash_color
        android_12_icon_background_dark = android["splash_android_12_icon_background_color_dark"] ||
          android["icon_background_color_dark"] || android_splash_dark_color
        android_12_color = android["splash_android_12_color"] || android["android_12_color"]
        android_12_color_dark = android["splash_android_12_color_dark"] || android["android_12_color_dark"]
        android_12_branding = resolve_asset.call(android["splash_android_12_branding"] || android["android_12_branding"])
        adaptive_background_color = android["adaptive_icon_background"] || icon_background
        android_min_sdk = android["min_sdk"] || android["min_sdk_android"] || build["min_sdk_android"]
        android_splash_fullscreen = first_defined(android, "splash_fullscreen", "fullscreen")
        android_splash_gravity = android["splash_gravity"] || android["android_gravity"]

        assets_dir = File.join(client_dir, "assets")
        FileUtils.mkdir_p(assets_dir)

        copy_asset = lambda do |src, dest|
          return unless src
          FileUtils.cp(src, File.join(assets_dir, dest))
        end

        copy_asset.call(splash, "splash.png")
        copy_asset.call(splash_dark, "splash_dark.png")
        copy_asset.call(icon, "icon.png")
        copy_asset.call(splash_background_image, "splash_background.png")
        copy_asset.call(splash_background_image_dark, "splash_background_dark.png")
        copy_asset.call(splash_branding, "splash_branding.png")
        copy_asset.call(splash_branding_dark, "splash_branding_dark.png")

        platforms.each do |name, entry|
          support = PLATFORM_ASSET_SUPPORT.fetch(name)
          if support[:splash]
            copy_asset.call(entry[:splash], "splash_#{name}.png")
            copy_asset.call(entry[:splash_dark], "splash_#{name}_dark.png")
            copy_asset.call(entry[:background_image], "splash_background_#{name}.png")
            copy_asset.call(entry[:background_image_dark], "splash_background_#{name}_dark.png")
            copy_asset.call(entry[:branding], "splash_branding_#{name}.png")
            copy_asset.call(entry[:branding_dark], "splash_branding_#{name}_dark.png")
          elsif entry[:splash] || entry[:splash_dark]
            build_note("#{name} has no splash screen generator; ignoring #{name}.splash_screen")
          end

          next unless entry[:icon]

          unless support[:icon]
            build_note("#{name} has no launcher icon generator; ignoring #{name}.icon_launcher")
            next
          end

          if name == "windows" && File.extname(entry[:icon]).downcase == ".ico"
            copy_asset.call(entry[:icon], "icon_windows.ico")
          else
            copy_asset.call(entry[:icon], "icon_#{name}.png")
          end
        end

        copy_asset.call(android_12_splash, "splash_android_12.png")
        copy_asset.call(android_12_splash_dark, "splash_android_12_dark.png")
        copy_asset.call(adaptive_foreground, "icon_foreground.png")
        copy_asset.call(adaptive_background_image, "icon_background.png")
        copy_asset.call(adaptive_monochrome, "icon_monochrome.png")

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

        # A project may configure nothing shared and declare everything under the
        # platform sections, so a platform asset alone has to run the generators.
        platform_splash = platforms.any? { |name, entry| PLATFORM_ASSET_SUPPORT.fetch(name)[:splash] && entry[:splash] }
        platform_icon = platforms.any? { |name, entry| PLATFORM_ASSET_SUPPORT.fetch(name)[:icon] && entry[:icon] }

        platforms.each do |name, entry|
          support = PLATFORM_ASSET_SUPPORT.fetch(name)
          if support[:splash] && entry[:splash].nil? && key_defined?(entry[:config], "splash_screen")
            build_note("#{name}.splash_screen was set but the file was not found")
          end
          if support[:icon] && entry[:icon].nil? && key_defined?(entry[:config], "icon_launcher")
            build_note("#{name}.icon_launcher was set but the file was not found")
          end
        end

        shared_splash_asset = !splash.nil? || default_splash
        shared_icon_asset = !icon.nil? || default_icon
        has_splash = shared_splash_asset || platform_splash
        has_icon = shared_icon_asset || platform_icon

        # Fall back to whatever Android configured when nothing is shared.
        effective_icon_background = icon_background || platforms.dig("android", :icon_background)
        effective_theme_color = theme_color || platforms.dig("android", :theme_color)

        pubspec_path = File.join(client_dir, "pubspec.yaml")
        unless File.file?(pubspec_path)
          return { has_icon: has_icon, has_splash: has_splash, error: nil }
        end

        ensure_pubspec_block(pubspec_path, "flutter_launcher_icons") if has_icon
        ensure_pubspec_block(pubspec_path, "flutter_native_splash") if has_splash

        if has_icon
          if shared_icon_asset
            update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path", "\"assets/icon.png\"", multiple: true)
          end
          # Android 8+ renders adaptive icons. Without these keys flutter_launcher_icons
          # never writes mipmap-anydpi-v26/, and the launcher falls back to the legacy
          # bitmap, ignoring icon_background entirely.
          update_pubspec_value(pubspec_path, "flutter_launcher_icons", "android", "launcher_icon", multiple: true)
          adaptive_foreground_path =
            if adaptive_foreground then "assets/icon_foreground.png"
            elsif platforms.dig("android", :icon) then "assets/icon_android.png"
            else "assets/icon.png"
            end
          update_pubspec_value(
            pubspec_path, "flutter_launcher_icons", "adaptive_icon_foreground",
            "\"#{adaptive_foreground_path}\"", multiple: true
          )
          adaptive_background_value =
            if adaptive_background_image
              "\"assets/icon_background.png\""
            elsif adaptive_background_color
              "\"#{adaptive_background_color}\""
            end
          if adaptive_background_value
            update_pubspec_value(
              pubspec_path, "flutter_launcher_icons", "adaptive_icon_background",
              adaptive_background_value, multiple: true
            )
          end
          if adaptive_monochrome
            update_pubspec_value(
              pubspec_path, "flutter_launcher_icons", "adaptive_icon_monochrome",
              "\"assets/icon_monochrome.png\"", multiple: true
            )
          end
          update_pubspec_value(pubspec_path, "flutter_launcher_icons", "min_sdk_android", android_min_sdk.to_s) if android_min_sdk
        end
        if has_icon
          # flutter_launcher_icons takes android/ios as flat image_path_* keys but
          # web/windows/macos as nested platform blocks.
          if platforms.dig("android", :icon)
            update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_android", "\"assets/icon_android.png\"", multiple: true)
          end
          if platforms.dig("ios", :icon)
            update_pubspec_value(pubspec_path, "flutter_launcher_icons", "image_path_ios", "\"assets/icon_ios.png\"", multiple: true)
          end
          if (remove_alpha = first_defined(platforms.dig("ios", :config), "remove_alpha", "remove_alpha_ios"))
            update_pubspec_value(pubspec_path, "flutter_launcher_icons", "remove_alpha_ios", remove_alpha ? "true" : "false")
          end

          %w[web windows macos].each do |name|
            entry = platforms.fetch(name)
            section = entry[:config]
            next if entry[:icon].nil? && section.empty?

            update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", name, "generate", "true")
            if entry[:icon]
              image = if name == "windows" && File.extname(entry[:icon]).downcase == ".ico"
                "assets/icon_windows.ico"
              else
                "assets/icon_#{name}.png"
              end
              update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", name, "image_path", "\"#{image}\"")
            end
            if name == "web"
              update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", "web", "background_color", "\"#{entry[:icon_background]}\"") if entry[:icon_background]
              update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", "web", "theme_color", "\"#{entry[:theme_color]}\"") if entry[:theme_color]
            end
            if name == "windows" && (icon_size = section["icon_size"])
              update_pubspec_nested_value(pubspec_path, "flutter_launcher_icons", "windows", "icon_size", icon_size.to_s)
            end
          end
        end
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "background_color", "\"#{effective_icon_background}\"") if effective_icon_background
        update_pubspec_value(pubspec_path, "flutter_launcher_icons", "theme_color", "\"#{effective_theme_color}\"") if effective_theme_color

        update_pubspec_value(pubspec_path, "flutter_native_splash", "image", "\"assets/splash.png\"") if shared_splash_asset
        update_pubspec_value(pubspec_path, "flutter_native_splash", "image_dark", "\"assets/splash_dark.png\"") if splash_dark
        update_pubspec_value(pubspec_path, "flutter_native_splash", "color", "\"#{splash_color}\"") if splash_color
        update_pubspec_value(pubspec_path, "flutter_native_splash", "color_dark", "\"#{splash_dark_color}\"") if splash_dark_color

        if has_splash
          update_pubspec_value(pubspec_path, "flutter_native_splash", "background_image", "\"assets/splash_background.png\"") if splash_background_image
          update_pubspec_value(pubspec_path, "flutter_native_splash", "background_image_dark", "\"assets/splash_background_dark.png\"") if splash_background_image_dark
          update_pubspec_value(pubspec_path, "flutter_native_splash", "branding", "\"assets/splash_branding.png\"") if splash_branding
          update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_dark", "\"assets/splash_branding_dark.png\"") if splash_branding_dark
          update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_mode", splash_branding_mode.to_s) if splash_branding_mode
          update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_bottom_padding", splash_branding_padding.to_s) if splash_branding_padding
        end

        if has_splash
          # flutter_native_splash only generates for android, ios, and web; each
          # takes the shared keys suffixed with the platform name.
          %w[android ios web].each do |name|
            entry = platforms.fetch(name)
            update_pubspec_value(pubspec_path, "flutter_native_splash", name, "true")
            update_pubspec_value(pubspec_path, "flutter_native_splash", "image_#{name}", "\"assets/splash_#{name}.png\"") if entry[:splash]
            update_pubspec_value(pubspec_path, "flutter_native_splash", "image_dark_#{name}", "\"assets/splash_#{name}_dark.png\"") if entry[:splash_dark]
            if entry[:splash_color] && entry[:splash_color] != splash_color
              update_pubspec_value(pubspec_path, "flutter_native_splash", "color_#{name}", "\"#{entry[:splash_color]}\"")
            end
            if entry[:splash_dark_color] && entry[:splash_dark_color] != splash_dark_color
              update_pubspec_value(pubspec_path, "flutter_native_splash", "color_dark_#{name}", "\"#{entry[:splash_dark_color]}\"")
            end
            update_pubspec_value(pubspec_path, "flutter_native_splash", "background_image_#{name}", "\"assets/splash_background_#{name}.png\"") if entry[:background_image]
            update_pubspec_value(pubspec_path, "flutter_native_splash", "background_image_dark_#{name}", "\"assets/splash_background_#{name}_dark.png\"") if entry[:background_image_dark]
            update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_#{name}", "\"assets/splash_branding_#{name}.png\"") if entry[:branding]
            update_pubspec_value(pubspec_path, "flutter_native_splash", "branding_dark_#{name}", "\"assets/splash_branding_#{name}_dark.png\"") if entry[:branding_dark]
          end

          if (ios_content_mode = platforms.dig("ios", :config)["content_mode"] || platforms.dig("ios", :config)["ios_content_mode"])
            update_pubspec_value(pubspec_path, "flutter_native_splash", "ios_content_mode", ios_content_mode.to_s)
          end
          if (web_image_mode = platforms.dig("web", :config)["image_mode"] || platforms.dig("web", :config)["web_image_mode"])
            update_pubspec_value(pubspec_path, "flutter_native_splash", "web_image_mode", web_image_mode.to_s)
          end
          update_pubspec_value(pubspec_path, "flutter_native_splash", "fullscreen", android_splash_fullscreen ? "true" : "false") unless android_splash_fullscreen.nil?
          update_pubspec_value(pubspec_path, "flutter_native_splash", "android_gravity", android_splash_gravity.to_s) if android_splash_gravity

          # Android 12+ draws the splash itself and ignores the legacy `image`/`color`
          # keys. Without an android_12 section the OS shows the launcher icon on a
          # system background, so mirror the configured splash into it.
          android_12_image =
            if android_12_splash then "assets/splash_android_12.png"
            elsif android_splash then "assets/splash_android.png"
            else "assets/splash.png"
            end
          update_pubspec_nested_value(pubspec_path, "flutter_native_splash", "android_12", "image", "\"#{android_12_image}\"")
          if android_12_icon_background
            update_pubspec_nested_value(
              pubspec_path, "flutter_native_splash", "android_12",
              "icon_background_color", "\"#{android_12_icon_background}\""
            )
          end
          android_12_image_dark =
            if android_12_splash_dark then "assets/splash_android_12_dark.png"
            elsif android_splash_dark then "assets/splash_android_dark.png"
            elsif splash_dark then "assets/splash_dark.png"
            end
          if android_12_image_dark
            update_pubspec_nested_value(
              pubspec_path, "flutter_native_splash", "android_12",
              "image_dark", "\"#{android_12_image_dark}\""
            )
          end
          if android_12_icon_background_dark
            update_pubspec_nested_value(
              pubspec_path, "flutter_native_splash", "android_12",
              "icon_background_color_dark", "\"#{android_12_icon_background_dark}\""
            )
          end
          update_pubspec_nested_value(pubspec_path, "flutter_native_splash", "android_12", "color", "\"#{android_12_color}\"") if android_12_color
          update_pubspec_nested_value(pubspec_path, "flutter_native_splash", "android_12", "color_dark", "\"#{android_12_color_dark}\"") if android_12_color_dark
          if android_12_branding
            copy_asset.call(android_12_branding, "splash_android_12_branding.png")
            update_pubspec_nested_value(
              pubspec_path, "flutter_native_splash", "android_12",
              "branding", "\"assets/splash_android_12_branding.png\""
            )
          end
        end

        {
          has_icon: has_icon,
          has_splash: has_splash,
          using_default_icon: using_default_icon,
          using_default_splash: using_default_splash,
          android_adaptive_icon: has_icon,
          android_12_splash: has_splash,
          error: nil
        }
      end

      # Platform-specific overrides may live in a top-level `<platform>:` block,
      # under `build.<platform>:`, or under `assets.<platform>:`. Later sources win.
      def platform_build_config(config, platform)
        name = platform.to_s
        build = config["build"].is_a?(Hash) ? config["build"] : {}
        assets = config["assets"].is_a?(Hash) ? config["assets"] : {}
        [config[name], build[name], assets[name]].each_with_object({}) do |source, merged|
          next unless source.is_a?(Hash)

          source.each { |key, value| merged[key.to_s] = value }
        end
      end

      # Like first_present, but keeps `false` — needed for boolean toggles.
      def first_defined(hash, *keys)
        return nil unless hash.is_a?(Hash)

        keys.each do |key|
          return hash[key] if hash.key?(key)
          return hash[key.to_sym] if hash.key?(key.to_sym)
        end
        nil
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
        metadata
      end

      def build_client_metadata(config, client_dir)
        app = config["app"].is_a?(Hash) ? config["app"] : {}
        current_pubspec = load_client_pubspec(client_dir)
        current_name = current_pubspec["name"].to_s
        inferred_display_name = app["app_name"] || app["name"] || config["name"] || humanize_name(File.basename(Dir.pwd))
        configured_app_name = first_present(app["app_name"], app["display_name"], app["name"])
        package_source = first_present(app["package_name"], config["package_name"], configured_app_name)
        package_source = current_name if package_source.nil?
        package_name = normalize_package_name(package_source)
        display_name = first_present(app["app_name"], app["display_name"], app["name"], config["display_name"], config["name"], humanize_name(package_name))
        organization = normalize_bundle_prefix(
          first_present(app["org"], app["organization"], config["org"], config["organization"], "com.example")
        )
        bundle_identifier = normalize_bundle_identifier(
          first_present(app["bundle_identifier"], config["bundle_identifier"], "#{organization}.#{package_name}")
        )
        identity_errors = []
        named = first_present(app["name"], app["app_name"], app["display_name"])
        identity_errors << "app.name" if named.nil?
        identity_errors << "app.package_name" if app["package_name"].to_s.strip.empty?
        identity_errors << "app.organization" if first_present(app["organization"], app["org"]).nil?

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
          ios_bundle_identifier: normalize_apple_bundle_identifier(
            first_present(app["ios_bundle_identifier"], config["ios_bundle_identifier"], bundle_identifier)
          ),
          macos_bundle_identifier: normalize_apple_bundle_identifier(
            first_present(app["macos_bundle_identifier"], config["macos_bundle_identifier"], bundle_identifier)
          ),
          linux_application_id: normalize_bundle_identifier(
            first_present(app["linux_application_id"], config["linux_application_id"], bundle_identifier)
          ),
          short_name: first_present(app["short_name"], config["short_name"], display_name),
          mobile_identity_errors: identity_errors.uniq
        }
      end

      def validate_mobile_app_identity(metadata, platform:)
        return true unless %w[apk android aab ios].include?(platform.to_s)
        return true unless metadata

        errors = Array(metadata[:mobile_identity_errors])
        return true if errors.empty?

        warn "build config error: ruflet.yaml must define #{errors.join(', ')}"
        warn "A mobile build needs app.name, app.package_name and app.organization."
        false
      end

      def load_client_pubspec(client_dir)
        pubspec_path = File.join(client_dir, "pubspec.yaml")
        return {} unless File.file?(pubspec_path)

        YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
      rescue StandardError
        {}
      end

      def apply_pubspec_metadata(client_dir, metadata)
        pubspec_path = File.join(client_dir, "pubspec.yaml")
        return unless File.file?(pubspec_path)

        data = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
        data["name"] = metadata[:package_name]
        data["description"] = metadata[:description]
        data["version"] = metadata[:version]
        write_pubspec_yaml(pubspec_path, data)
      end

      def apply_android_metadata(client_dir, metadata)
        manifest_path = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
        replace_in_file(
          manifest_path,
          /android:label="[^"]*"/,
          %(android:label="#{xml_escape(metadata[:display_name])}")
        )
      end

      # The signing team belongs to whoever ships the app, so it comes from the
      # project rather than being baked into the client.
      def apply_ios_signing_team(client_dir, config)
        team = ios_signing_team(config)
        pbxproj_path = File.join(client_dir, "ios", "Runner.xcodeproj", "project.pbxproj")
        return unless File.file?(pbxproj_path)

        if team.to_s.strip.empty?
          build_note("No ios.team_id configured; Xcode will pick the signing team")
          replace_in_file(pbxproj_path, /DEVELOPMENT_TEAM = [^;]*;/, "DEVELOPMENT_TEAM = \"\";")
          return
        end

        replace_in_file(pbxproj_path, /DEVELOPMENT_TEAM = [^;]*;/, "DEVELOPMENT_TEAM = #{team};")
        build_note("iOS signing team set to #{team}")
      end

      def ios_signing_team(config)
        app = config["app"].is_a?(Hash) ? config["app"] : {}
        first_present(
          platform_build_config(config, "ios")["team_id"],
          app["ios_team_id"],
          app["team_id"],
          ENV["RUFLET_IOS_TEAM_ID"]
        )
      end

      def apply_ios_metadata(client_dir, metadata)
        info_plist_path = File.join(client_dir, "ios", "Runner", "Info.plist")
        replace_plist_value(info_plist_path, "CFBundleDisplayName", metadata[:display_name])
        replace_plist_value(info_plist_path, "CFBundleName", metadata[:display_name])

        pbxproj_path = File.join(client_dir, "ios", "Runner.xcodeproj", "project.pbxproj")
        return unless File.file?(pbxproj_path)

        content = read_text_file(pbxproj_path)
        content.gsub!(/INFOPLIST_KEY_CFBundleDisplayName = "[^"]*";/, %(INFOPLIST_KEY_CFBundleDisplayName = "#{xcode_escape(metadata[:display_name])}";))
        write_text_file(pbxproj_path, content)
      end

      def apply_mobile_package_name(client_dir, metadata, platform:, tools:, verbose: false)
        return true unless metadata

        package_name, platform_flag = case platform.to_s
        when "apk", "android", "aab"
          [metadata[:android_application_id], "--android"]
        when "ios"
          [metadata[:ios_bundle_identifier], "--ios"]
        else
          return true
        end

        build_note("Applying #{platform_flag.delete_prefix('--')} package name #{package_name}")
        build_log(verbose, "running change_app_package_name for #{package_name} #{platform_flag}")
        ok = run_external_command(
          tools[:env],
          tools[:dart],
          "run",
          "change_app_package_name:main",
          package_name,
          platform_flag,
          chdir: client_dir,
          unbundled: true
        )
        warn "change_app_package_name failed for #{package_name}" unless ok
        ok
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
          data = JSON.parse(read_text_file(manifest_path))
          data["name"] = metadata[:display_name]
          data["short_name"] = metadata[:short_name]
          data["description"] = metadata[:description]
          write_text_file(manifest_path, JSON.pretty_generate(data) + "\n")
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

      # Native project files are UTF-8 and the values written into them are too
      # (the macOS copyright line carries a ©). Reading them with the default
      # external encoding fails outright under a non-UTF-8 locale, so pin it.
      def read_text_file(path)
        File.read(path, encoding: Encoding::UTF_8)
      end

      def write_text_file(path, content)
        File.write(path, content, encoding: Encoding::UTF_8)
      end

      def replace_plist_value(path, key, value)
        return unless File.file?(path)

        content = read_text_file(path)
        pattern = %r{(<key>#{Regexp.escape(key)}</key>\s*<string>)(.*?)(</string>)}m
        updated = content.gsub(pattern) do
          "#{Regexp.last_match(1)}#{xml_escape(value)}#{Regexp.last_match(3)}"
        end
        write_text_file(path, updated) unless updated == content
      end

      def replace_in_file(path, pattern, replacement)
        return unless File.file?(path)

        content = read_text_file(path)
        updated = content.gsub(pattern) { replacement }
        write_text_file(path, updated) unless updated == content
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

      def normalize_apple_bundle_identifier(value)
        segments = value.to_s.strip.downcase.split(".").map do |segment|
          normalized = segment.gsub(/[^a-z0-9-]+/, "-")
          normalized.gsub!(/\A-+|-+\z/, "")
          normalized.gsub!(/-+/, "-")
          normalized = "app" if normalized.empty?
          normalized = "app-#{normalized}" if normalized.match?(/\A\d/)
          normalized
        end
        segments.reject!(&:empty?)
        segments = %w[com example app] if segments.empty?
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

      def apply_service_extension_config(client_dir, config = {}, self_contained: @ruflet_self_contained_build)
        services = configured_service_entries(config).map { |entry| entry[:name] }
        requested_extensions = Array(config["extensions"]).map { |value| normalize_extension_key(value) }.compact
        protected_extensions = services.flat_map { |name| PROTECTED_SERVICE_EXTENSIONS.fetch(name, []) }
        extension_keys = (requested_extensions + protected_extensions + services).uniq
        extension_packages = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:package) }.uniq
        extension_aliases = extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:alias) }.uniq

        external = external_extension_entries(config)

        pubspec_path = File.join(client_dir, "pubspec.yaml")
        if File.file?(pubspec_path)
          sync_client_extension_dependencies(pubspec_path, extension_packages)
          prune_client_pubspec(pubspec_path, extension_packages)
          sync_external_extension_dependencies(pubspec_path, external)
        end
        sync_client_package_directories(client_dir, extension_packages)
        client_entrypoint_paths(client_dir).each do |entrypoint|
          next unless File.file?(entrypoint)

          sync_client_main_extensions(entrypoint, extension_aliases)
          prune_client_main(entrypoint, extension_aliases)
          sync_external_extension_registrations(entrypoint, external)
        end
      end

      # An extension may name a package the template does not bundle, declared
      # with the source to fetch it from:
      #
      #   extensions:
      #     - charts
      #     - my_package:
      #         git:
      #           url: https://github.com/owner/my_package
      #           ref: main
      #
      # `branch` is accepted for `ref`, and `path` for a local checkout.
      def external_extension_entries(config)
        Array(config["extensions"]).filter_map do |entry|
          next unless entry.is_a?(Hash)
          next unless entry.size == 1

          name, source = entry.first
          package = name.to_s.strip
          next if package.empty?

          dependency = external_extension_dependency(source)
          next unless dependency

          { name: package, dependency: dependency }
        end
      end

      def external_extension_dependency(source)
        return nil unless source.is_a?(Hash)

        normalized = source.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
        git = normalized["git"] || normalized["github"] || normalized["repository"]
        git = normalized if git.nil? && normalized.key?("url")

        if git.is_a?(String)
          return { "git" => git }
        elsif git.is_a?(Hash)
          git = git.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
          url = git["url"].to_s.strip
          return nil if url.empty?

          spec = { "url" => url }
          ref = (git["ref"] || git["branch"] || git["tag"]).to_s.strip
          spec["ref"] = ref unless ref.empty?
          path = git["path"].to_s.strip
          spec["path"] = path unless path.empty?
          return { "git" => spec }
        end

        local = normalized["path"]
        return { "path" => local.to_s } if local.is_a?(String) && !local.to_s.strip.empty?

        nil
      end

      def sync_external_extension_dependencies(pubspec_path, entries)
        return if entries.empty?

        data = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
        dependencies = (data["dependencies"] || {}).dup
        entries.each { |entry| dependencies[entry[:name]] = entry[:dependency] }
        data["dependencies"] = dependencies
        write_pubspec_yaml(pubspec_path, data)
        build_note("Added #{entries.map { |e| e[:name] }.join(', ')} from the extension configuration")
      end

      # Flet extension packages expose an Extension class from a library named
      # after the package, so the import and registration can be derived.
      def sync_external_extension_registrations(path, entries)
        return if entries.empty?

        content = read_text_file(path)
        original = content.dup

        entries.each do |entry|
          name = entry[:name]
          import_line = %(import 'package:#{name}/#{name}.dart' as #{name};\n)
          extension_line = "    #{name}.Extension(),\n"

          content = insert_missing_import(content, import_line) unless content.include?("package:#{name}/#{name}.dart")
          content = insert_missing_extension(content, extension_line) unless content.match?(/^\s*#{Regexp.escape(name)}\.Extension\(\),/)
        end

        write_text_file(path, content) unless content == original
      end

      def configured_service_entries(config)
        Array(config["services"]).filter_map do |entry|
          case entry
          when Hash
            name, options = entry.first
            key = normalize_extension_key(name)
            next unless key

            description = options.is_a?(Hash) ? options["description"] || options[:description] : options
            { name: key, description: description.to_s.strip }
          else
            key = normalize_extension_key(entry)
            { name: key, description: "" } if key
          end
        end
      end

      ANDROID_SIGNING_KEYS = {
        "storeFile" => "RUFLET_ANDROID_KEYSTORE",
        "storePassword" => "RUFLET_ANDROID_KEYSTORE_PASSWORD",
        "keyAlias" => "RUFLET_ANDROID_KEY_ALIAS",
        "keyPassword" => "RUFLET_ANDROID_KEY_PASSWORD"
      }.freeze

      # Release signing is read from the project, never from the managed client,
      # so nobody has to edit build/client by hand. Either keep an
      # android/key.properties beside the app, or set the RUFLET_ANDROID_*
      # variables. Without one of those, Gradle falls back to the debug key.
      def apply_android_signing_config(client_dir, platform, verbose: false)
        return unless %w[apk android aab appbundle].include?(platform.to_s)

        android_dir = File.join(client_dir, "android")
        return unless Dir.exist?(android_dir)

        destination = File.join(android_dir, "key.properties")
        properties = android_signing_properties
        if properties.empty?
          File.delete(destination) if File.file?(destination)
          build_note("No Android signing configured; the release build will use the debug key")
          return
        end

        missing = ANDROID_SIGNING_KEYS.keys - properties.keys
        unless missing.empty?
          warn "build config error: Android signing is missing #{missing.join(', ')}"
          warn "Set them in android/key.properties or the matching RUFLET_ANDROID_* variables."
          return
        end

        body = ANDROID_SIGNING_KEYS.keys.map { |key| "#{key}=#{properties.fetch(key)}" }.join("\n")
        write_text_file(destination, "#{body}\n")
        build_log(verbose, "wrote #{destination}")
        build_note("Android release signing configured from #{properties.fetch("_source")}")
      end

      def android_signing_properties
        from_env = ANDROID_SIGNING_KEYS.each_with_object({}) do |(key, variable), out|
          value = ENV[variable].to_s.strip
          out[key] = value unless value.empty?
        end
        unless from_env.empty?
          from_env["storeFile"] = File.expand_path(from_env["storeFile"]) if from_env["storeFile"]
          return from_env.merge("_source" => "the RUFLET_ANDROID_* environment")
        end

        source = project_android_key_properties_path
        return {} unless source

        parsed = read_text_file(source).each_line.with_object({}) do |line, out|
          next if line.strip.empty? || line.strip.start_with?("#")

          key, value = line.split("=", 2)
          out[key.to_s.strip] = value.to_s.strip unless value.nil?
        end
        return {} if parsed.empty?

        # storeFile is written relative to the project; the client sits deeper.
        if parsed["storeFile"] && !Pathname.new(parsed["storeFile"]).absolute?
          parsed["storeFile"] = File.expand_path(parsed["storeFile"], File.dirname(source))
        end
        parsed.merge("_source" => source)
      end

      def project_android_key_properties_path
        [
          File.join(Dir.pwd, "android", "key.properties"),
          File.join(Dir.pwd, "key.properties")
        ].find { |path| File.file?(path) }
      end

      def apply_native_service_permissions(client_dir, config)
        entries = configured_service_entries(config)
        configured_extensions = Array(config["extensions"]).filter_map { |entry| normalize_extension_key(entry) }
        extension_services = configured_extensions.flat_map do |extension|
          EXTENSION_REQUIRED_SERVICES.fetch(extension, [])
        end
        extension_services.each do |service|
          entries << { name: service, description: "" } unless entries.any? { |entry| entry[:name] == service }
        end
        apply_android_service_permissions(client_dir, entries)
        apply_ios_service_usage_descriptions(client_dir, entries)
      end

      def apply_android_service_permissions(client_dir, entries)
        path = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
        return unless File.file?(path)

        content = read_text_file(path)
        MANAGED_ANDROID_PERMISSIONS.each do |permission|
          content.gsub!(
            %r{^\s*<uses-permission\b[^>]*android:name="#{Regexp.escape(permission)}"[^>]*/>\s*\n?},
            ""
          )
        end
        entries.flat_map { |entry| ANDROID_SERVICE_PERMISSIONS.fetch(entry[:name], []) }.uniq.each do |permission|
          next if content.include?(%(android:name="#{permission}"))

          content.sub!(/<manifest\b[^>]*>\s*/, "\\0    <uses-permission android:name=\"#{permission}\"/>\n")
        end
        write_text_file(path, content)
      end

      def apply_ios_service_usage_descriptions(client_dir, entries)
        path = File.join(client_dir, "ios", "Runner", "Info.plist")
        return unless File.file?(path)

        content = read_text_file(path)
        MANAGED_IOS_USAGE_KEYS.each do |key|
          content.gsub!(
            %r{\s*<key>#{Regexp.escape(key)}</key>\s*<string>.*?</string>}m,
            ""
          )
        end
        entries.each do |entry|
          key = IOS_SERVICE_USAGE_KEYS[entry[:name]]
          next unless key

          description = entry[:description]
          description = "This app uses #{entry[:name]} access for its Ruflet features." if description.empty?
          escaped_description = xml_escape(description)
          pair = "\t<key>#{key}</key>\n\t<string>#{escaped_description}</string>\n"

          if content.match?(%r{<key>#{Regexp.escape(key)}</key>})
            content.sub!(%r{<key>#{Regexp.escape(key)}</key>\s*<string>.*?</string>}m, "<key>#{key}</key>\n\t<string>#{escaped_description}</string>")
          else
            content.sub!(%r{</dict>\s*</plist>}m, "#{pair}</dict>\n</plist>")
          end
        end
        write_text_file(path, content)
      end

      def clear_flutter_build_state(client_dir, verbose: false)
        flutter_build_dir = File.join(client_dir, ".dart_tool", "flutter_build")
        return unless Dir.exist?(flutter_build_dir)

        FileUtils.rm_rf(flutter_build_dir)
        build_log(verbose, "cleared .dart_tool/flutter_build")
      end

      def clear_stale_platform_outputs(client_dir, platform, verbose: false)
        return unless platform == "ios"

        stale_paths = %w[
          build/ios/Debug-iphonesimulator
          build/ios/iphonesimulator
        ]

        stale_paths.each do |relative_path|
          path = File.join(client_dir, relative_path)
          next unless Dir.exist?(path)

          FileUtils.rm_rf(path)
          build_log(verbose, "cleared stale #{relative_path}")
        end
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
          remove_local_ruby_runtime_override(client_dir, verbose: verbose)
        else
          remove_self_contained_project_assets(client_dir, verbose: verbose)
          remove_local_ruby_runtime_override(client_dir, verbose: verbose)
        end
        true
      end

      def sync_client_pubspec_for_runtime_mode(client_dir, self_contained:)
        pubspec_path = File.join(client_dir, "pubspec.yaml")
        return unless File.file?(pubspec_path)

        data = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
        dependencies = data["dependencies"]
        dependencies = data["dependencies"] = {} unless dependencies.is_a?(Hash)
        flutter = data["flutter"]
        flutter = data["flutter"] = {} unless flutter.is_a?(Hash)
        assets = Array(flutter["assets"]).map(&:to_s)

        if self_contained
          dependencies["ruby_runtime"] = ruby_runtime_dependency(dependencies["ruby_runtime"])
          # Flutter does not recurse into asset directories, so every subdirectory
          # of the embedded project (e.g. standalone_apps/<slug>/) must be listed
          # explicitly or its files never reach the bundle/manifest on device.
          self_contained_project_asset_dirs.each do |dir_entry|
            assets << dir_entry unless assets.include?(dir_entry)
          end
        else
          dependencies.delete("ruby_runtime")
          project_prefix = "assets/#{self_contained_project_name}/"
          assets.reject! { |a| a.to_s == project_prefix || a.to_s.start_with?(project_prefix) }
        end

        flutter["assets"] = assets unless assets.empty?
        flutter.delete("assets") if assets.empty?
        write_pubspec_yaml(pubspec_path, data)
      end

      # A self-contained build needs the embedded VM. Prefer a local checkout so
      # the runtime under development is the one packaged, and otherwise resolve
      # the published package.
      PUBLISHED_RUBY_RUNTIME_CONSTRAINT = "^0.0.9"

      def ruby_runtime_dependency(current_dependency = nil)
        local_path = explicit_local_ruby_runtime_path || source_checkout_ruby_runtime_path
        return { "path" => local_path } if local_path

        current_dependency || PUBLISHED_RUBY_RUNTIME_CONSTRAINT
      end

      def explicit_local_ruby_runtime_path
        env_path = ENV["RUFLET_RUBY_RUNTIME_PATH"].to_s.strip
        return nil if env_path.empty?

        candidate = Pathname.new(env_path).expand_path
        return candidate.to_s if candidate.join("pubspec.yaml").file?

        nil
      end

      def source_checkout_ruby_runtime_path
        candidate = Pathname.new(File.expand_path("../../../../../ruby_runtime", __dir__))
        return candidate.to_s if candidate.join("pubspec.yaml").file?

        nil
      end

      def refresh_managed_client_template_files(client_dir, platform: nil, verbose: false)
        template_root =
          if Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)
            Ruflet::CLI.send(:resolve_ruflet_client_template_root)
          end
        return unless template_root && Dir.exist?(template_root)

        managed_files = [
          "lib/main.dart",
          "lib/main.self.dart",
          "lib/main.server.dart",
          "lib/native_renderer.dart",
          "lib/connection_probe.dart",
          "lib/connection_probe_io.dart",
          "lib/connection_probe_stub.dart",
          "ios/Podfile",
          # Carries the usage descriptions and the local-network/ATS policy a
          # preview client needs. Without refreshing it, a client generated
          # before those keys existed keeps a plist that silently blocks
          # connections to a development server on the local network.
          "ios/Runner/Info.plist",
          "windows/CMakeLists.txt",
          # Release signing lives here; an existing client would otherwise keep
          # signing release builds with the debug key.
          "android/app/build.gradle.kts"
        ]

        case platform.to_s
        when "ios", "ipa"
          managed_files.concat(
            [
              "ios/Runner/AppDelegate.swift",
              "ios/Runner/RufletEngineChoice.swift",
              "ios/Runner.xcodeproj/project.pbxproj"
            ]
          )
        when "macos"
          managed_files.concat(
            [
              "macos/Runner/MainFlutterWindow.swift",
              "macos/Runner/RufletEngineChoice.swift",
              "macos/Runner.xcodeproj/project.pbxproj"
            ]
          )
        end

        managed_files.each do |relative_path|
          source = File.join(template_root, relative_path)
          next unless File.file?(source)

          destination = File.join(client_dir, relative_path)
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(source, destination)
          build_log(verbose, "refreshed template file #{relative_path}")
        end

        if %w[ios ipa macos].include?(platform.to_s)
          sync_managed_template_tree(
            template_root, client_dir, "apple_packages/ruflet_apple", verbose: verbose)
        end

        # Older managed clients carried a macOS-only FilePicker override. Flet's
        # core service owns FilePicker now, so this duplicate must not survive a
        # template refresh.
        FileUtils.rm_f(File.join(client_dir, "lib", "ruflet_file_picker_service.dart"))
      end

      def sync_managed_template_tree(template_root, client_dir, relative_path, verbose: false)
        source = File.join(template_root, relative_path)
        return unless Dir.exist?(source)

        destination = File.join(client_dir, relative_path)
        FileUtils.rm_rf(destination)
        FileUtils.mkdir_p(destination)
        # SwiftPM and Dart create mutable caches directly inside the package.
        # Copying the whole directory and deleting those caches afterwards is
        # too late: framework resource symlinks inside `.build` can collide or
        # escape while FileUtils is still traversing them. Treat only the
        # package's source tree as managed template input from the outset.
        generated_entries = %w[.build .swiftpm .dart_tool .claude]
        Dir.children(source).each do |entry|
          next if generated_entries.include?(entry)

          FileUtils.cp_r(
            File.join(source, entry), File.join(destination, entry),
            preserve: true)
        end
        build_log(verbose, "refreshed template tree #{relative_path}")
      end

      def configure_native_apple_runtime(
        client_dir, platform:, self_contained:, verbose: false
      )
        plist_paths = case platform.to_s
        when "ios", "ipa"
          [File.join(client_dir, "ios", "Runner", "Info.plist")]
        when "macos"
          [File.join(client_dir, "macos", "Runner", "Info.plist")]
        else
          []
        end

        plist_paths.each do |path|
          next unless File.file?(path)

          upsert_plist_string(
            path, "RufletEmbeddedProject",
            self_contained ? self_contained_project_name : "")
          message = if self_contained
            "native Apple runtime embeds #{self_contained_project_name}"
          else
            "native Apple runtime uses the server URL resolved by Dart"
          end
          build_log(verbose, message)
        end
      end

      def upsert_plist_string(path, key, value)
        content = read_text_file(path)
        pair = "\t<key>#{key}</key>\n\t<string>#{xml_escape(value)}</string>"
        pattern = %r{<key>#{Regexp.escape(key)}</key>\s*<string>.*?</string>}m
        if content.match?(pattern)
          content.sub!(pattern, pair.strip)
        else
          content.sub!(%r{</dict>\s*</plist>}m, "#{pair}\n</dict>\n</plist>")
        end
        write_text_file(path, content)
      end

      def write_pubspec_yaml(path, data)
        content = YAML.dump(data)
        content = content.sub(/\A---\n/, "")

        content = indent_pubspec_sequences(content)

        write_text_file(path, content)
      end

      def indent_pubspec_sequences(content)
        current_key_indent = nil
        content.lines.map do |line|
          if (match = line.match(/\A(\s*)[^#\s][^:]*:\s*(?:#.*)?\n?\z/))
            current_key_indent = match[1].length
          elsif (match = line.match(/\A(\s*)-\s/)) && current_key_indent && match[1].length <= current_key_indent
            line = (" " * (current_key_indent + 2)) + line.lstrip
          end

          line
        end.join
      end

      # Flutter asset directory entries for every folder of the embedded project
      # that contains packaged files. Derived from the exact copy list so the
      # pubspec asset dirs match what sync_self_contained_project_assets writes.
      def self_contained_project_asset_dirs
        prefix = "assets/#{self_contained_project_name}"
        dirs = project_asset_relative_paths.map { |rel| File.dirname(rel) }.uniq
        project_dirs = dirs.map { |dir| dir == "." ? "#{prefix}/" : "#{prefix}/#{dir}/" }
        project_dirs.sort
      end

      def sync_self_contained_project_assets(client_dir, verbose: false)
        project_root = Pathname.new(Dir.pwd)
        assets_root = File.join(client_dir, "assets")
        destination_root = File.join(assets_root, self_contained_project_name)
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

        build_log(verbose, "copied #{copied} project file#{copied == 1 ? '' : 's'} to assets/#{self_contained_project_name}")
      end

      def remove_self_contained_project_assets(client_dir, verbose: false)
        assets_root = File.join(client_dir, "assets")
        removed = false

        project_root = File.join(assets_root, self_contained_project_name)
        if Dir.exist?(project_root)
          FileUtils.rm_rf(project_root)
          removed = true
        end

        build_log(verbose, "removed embedded self-contained project assets") if removed
      end

      def project_asset_relative_paths
        root = Pathname.new(Dir.pwd)
        included = []

        Find.find(root.to_s) do |path|
          pathname = Pathname.new(path)
          relative = pathname.relative_path_from(root).to_s
          next if relative.empty? || relative == "."

          if pathname.directory?
            if skip_project_asset_directory?(relative)
              Find.prune
              next
            else
              next
            end
          end

          next unless include_project_asset_file?(relative)

          included << relative
        end

        included.sort
      end

      def self_contained_project_name
        name = File.basename(Dir.pwd.to_s)
        name = "app" if name.to_s.strip.empty?
        name
      end

      def skip_project_asset_directory?(relative)
        excluded_directories = %w[
          .git
          .bundle
          .dart_tool
          .idea
          .ruby-lsp
          .vscode
          build
          coverage
          credentials
          fastlane
          log
          node_modules
          pkg
          ruflet_client
          tmp
          vendor
        ]
        relative.split(File::SEPARATOR).any? do |component|
          component.start_with?(".") || excluded_directories.include?(component)
        end
      end

      # Anything embedded here is readable by anyone who unpacks the shipped
      # app, so signing keys and local environment files must never be copied
      # in even when a project keeps them beside its source.
      SECRET_ASSET_EXTENSIONS = %w[.p8 .p12 .pem .key .jks .keystore .mobileprovision].freeze
      SECRET_ASSET_BASENAMES = %w[.env .netrc key.properties].freeze

      def secret_project_asset?(relative)
        basename = File.basename(relative)
        return true if SECRET_ASSET_BASENAMES.include?(basename)
        return true if basename.start_with?(".env.") && basename != ".env.example"
        return true if SECRET_ASSET_EXTENSIONS.include?(File.extname(basename).downcase)
        return true if basename.match?(/\Agoogle-play.*\.json\z/i)

        false
      end

      # What a self-contained build actually needs from the project at runtime:
      # the entrypoint, the Ruby under lib/, and the assets that code loads by
      # path (image(src: "assets/logo.png"), lottie(...), fonts, audio).
      #
      # Everything else is already consumed by the time the app runs. The gems
      # are compiled into the VM, ruflet.yaml and services.yaml have been turned
      # into native configuration, and lockfiles, tests, CI and store artwork
      # were never runtime inputs. Listing what belongs in rather than guessing
      # what to leave out keeps unexpected directories from being shipped --
      # release artwork once carried a lockfile that Apple read as an unsigned
      # code object and rejected the whole upload over.
      SELF_CONTAINED_PROJECT_ENTRYPOINT = "main.rb"
      SELF_CONTAINED_PROJECT_DIRECTORIES = %w[lib assets].freeze

      def include_project_asset_file?(relative)
        basename = File.basename(relative)
        return false if basename == ".DS_Store"

        unless self_contained_project_path?(relative)
          return false
        end

        if secret_project_asset?(relative)
          build_note("Excluded #{relative} from the embedded project; it looks like a credential")
          return false
        end
        true
      end

      def self_contained_project_path?(relative)
        return true if relative == SELF_CONTAINED_PROJECT_ENTRYPOINT

        top = relative.split(File::SEPARATOR).first
        SELF_CONTAINED_PROJECT_DIRECTORIES.include?(top)
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

      def remove_local_ruby_runtime_override(client_dir, verbose: false)
        overrides_path = File.join(client_dir, "pubspec_overrides.yaml")
        return unless File.file?(overrides_path)

        File.delete(overrides_path)
        build_log(verbose, "removed ruby_runtime override")
      rescue StandardError => e
        warn "Failed to remove ruby_runtime override: #{e.class}: #{e.message}"
      end

      def normalize_extension_key(value)
        key = value.to_s.strip.downcase
        return nil if key.empty?

        key.tr!("-", "_")
        key.gsub!(/\A(flet_)+/, "")
        key.gsub!(/\A(ruflet_)+/, "")
        key.gsub!(/\Aservice_/, "")
        key
      end

      def prune_client_pubspec(path, selected_packages)
        data = YAML.safe_load(read_text_file(path), aliases: true) || {}
        deps = (data["dependencies"] || {}).dup
        optional_packages = CLIENT_EXTENSION_MAP.values.map { |entry| entry.fetch(:package) }.uniq

        deps.keys.each do |name|
          next unless optional_packages.include?(name)
          next if selected_packages.include?(name)

          deps.delete(name)
        end

        data["dependencies"] = deps
        write_pubspec_yaml(path, data)
      end

      def sync_client_package_directories(client_dir, selected_packages)
        packages_root = File.join(client_dir, "flet_packages")
        return unless Dir.exist?(packages_root)

        kept_packages = (["flet"] + selected_packages).uniq
        template_root =
          if Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)
            Ruflet::CLI.send(:resolve_ruflet_client_template_root)
          end
        template_packages_root = template_root && File.join(template_root, "flet_packages")

        # A declaration can change between builds. Restore newly selected local
        # packages from the immutable template before pruning the old selection.
        kept_packages.each do |package_name|
          destination = File.join(packages_root, package_name)
          next if Dir.exist?(destination)
          next unless template_packages_root

          source = File.join(template_packages_root, package_name)
          next unless Dir.exist?(source)
          next if File.expand_path(source) == File.expand_path(destination)

          FileUtils.cp_r(source, destination)
        end

        Dir.children(packages_root).each do |entry|
          path = File.join(packages_root, entry)
          next unless Dir.exist?(path)
          next if kept_packages.include?(entry)

          FileUtils.rm_rf(path)
        end
      end

      def sync_client_extension_dependencies(path, selected_packages)
        return if selected_packages.empty?

        template_deps = template_client_pubspec_dependencies
        return if template_deps.empty?

        data = YAML.safe_load(read_text_file(path), aliases: true) || {}
        deps = (data["dependencies"] || {}).dup
        selected_packages.each do |package_name|
          deps[package_name] = template_deps[package_name] if template_deps.key?(package_name)
        end

        data["dependencies"] = deps
        write_pubspec_yaml(path, data)
      end

      def template_client_pubspec_dependencies
        template_root =
          if Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)
            Ruflet::CLI.send(:resolve_ruflet_client_template_root)
          end
        return {} unless template_root

        pubspec_path = File.join(template_root, "pubspec.yaml")
        return {} unless File.file?(pubspec_path)

        data = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
        deps = data["dependencies"]
        deps.is_a?(Hash) ? deps : {}
      rescue StandardError
        {}
      end

      def sync_client_main_extensions(path, selected_aliases)
        return if selected_aliases.empty?

        template_path = template_client_entrypoint_path(File.basename(path))
        return unless template_path

        content = read_text_file(path)
        template = read_text_file(template_path)

        selected_aliases.each do |extension_alias|
          import_line = template.lines.find { |line| line.match?(/\sas #{Regexp.escape(extension_alias)};\s*\z/) }
          extension_line = template.lines.find do |line|
            line.match?(/^\s*#{Regexp.escape(extension_alias)}\.[A-Za-z0-9_]+\(\),\s*$/)
          end

          content = insert_missing_import(content, import_line) if import_line && !content.include?(import_line)
          content = insert_missing_extension(content, extension_line) if extension_line && !content.include?(extension_line)
        end

        write_text_file(path, content)
      end

      def template_client_entrypoint_path(name)
        template_root =
          if Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)
            Ruflet::CLI.send(:resolve_ruflet_client_template_root)
          end
        return nil unless template_root

        path = File.join(template_root, "lib", name)
        File.file?(path) ? path : nil
      end

      def insert_missing_import(content, import_line)
        lines = content.lines
        last_import_index = lines.rindex { |line| line.start_with?("import ") }
        if last_import_index
          lines.insert(last_import_index + 1, import_line)
        else
          lines.unshift(import_line)
        end
        lines.join
      end

      def insert_missing_extension(content, extension_line)
        lines = content.lines
        marker_index = lines.index { |line| line.include?("// --FAT_CLIENT_START--") }
        if marker_index
          lines.insert(marker_index, extension_line)
        else
          list_index = lines.index { |line| line.include?("final extensions = <FletExtension>[") }
          lines.insert(list_index ? list_index + 1 : lines.length, extension_line)
        end
        lines.join
      end

      def prune_client_main(path, selected_aliases)
        content = read_text_file(path)
        alias_to_package = {}
        optional_aliases = CLIENT_EXTENSION_MAP.values.map { |entry| entry.fetch(:alias) }.uniq

        content.scan(%r{^import 'package:([^/]+)/[^']+'\s+as ([a-zA-Z0-9_]+);$}m) do |package_name, import_alias|
          alias_to_package[import_alias] = package_name
        end
        content.scan(%r{^import '([^']+)'\s+as ([a-zA-Z0-9_]+);$}m) do |_source, import_alias|
          alias_to_package[import_alias] = :local if optional_aliases.include?(import_alias)
        end

        content = content.gsub(%r{^import 'package:([^/]+)/[^']+'\s+as ([a-zA-Z0-9_]+);\n}m) do |match|
          package_name = Regexp.last_match(1)
          import_alias = Regexp.last_match(2)
          if !optional_aliases.include?(import_alias) || selected_aliases.include?(import_alias)
            match
          else
            ""
          end
        end
        content = content.gsub(%r{^import '([^']+)'\s+as ([a-zA-Z0-9_]+);\n}m) do |match|
          import_alias = Regexp.last_match(2)
          if !optional_aliases.include?(import_alias) || selected_aliases.include?(import_alias)
            match
          else
            ""
          end
        end

        content = content.gsub(/^(\s*)([a-zA-Z0-9_]+)\.[A-Za-z0-9_]+\(\),\s*$/) do |match|
          extension_alias = Regexp.last_match(2)
          package_name = alias_to_package[extension_alias]
          if package_name.nil? || !optional_aliases.include?(extension_alias) || selected_aliases.include?(extension_alias)
            match
          else
            ""
          end
        end

        write_text_file(path, content)
      end

      # update_pubspec_value only rewrites blocks that already exist. Create the
      # block first so a template without it still receives the configured values.
      def ensure_pubspec_block(path, block)
        return unless File.file?(path)

        content = read_text_file(path)
        return if content.lines.any? { |line| line.start_with?("#{block}:") }

        content += "\n" unless content.empty? || content.end_with?("\n")
        write_text_file(path, "#{content}#{block}:\n")
      end

      # Writes `block: -> section: -> key: value`, creating the block and the
      # nested section when they are missing (for example flutter_native_splash's
      # android_12 section).
      def update_pubspec_nested_value(path, block, section, key, value)
        return unless File.file?(path)

        ensure_pubspec_block(path, block)
        lines = read_text_file(path).split("\n", -1)
        block_start = lines.index { |line| line.start_with?("#{block}:") }
        return unless block_start

        block_end = block_start + 1
        block_end += 1 while block_end < lines.length && (lines[block_end].strip.empty? || lines[block_end].start_with?(" ", "\t"))
        block_end -= 1 while block_end > block_start + 1 && lines[block_end - 1].strip.empty?

        section_index = (block_start + 1...block_end).find do |index|
          lines[index] =~ /\A\s{2}#{Regexp.escape(section)}:\s*(#.*)?\z/
        end

        if section_index.nil?
          lines.insert(block_end, "  #{section}:", "    #{key}: #{value}")
        else
          section_end = section_index + 1
          section_end += 1 while section_end < block_end && lines[section_end] =~ /\A\s{3,}\S/
          existing = (section_index + 1...section_end).find { |index| lines[index].strip.start_with?("#{key}:") }
          if existing
            lines[existing] = "#{lines[existing][/\A\s*/]}#{key}: #{value}"
          else
            lines.insert(section_end, "    #{key}: #{value}")
          end
        end

        write_text_file(path, indent_pubspec_sequences(lines.join("\n")))
      end

      def update_pubspec_value(path, block, key, value, multiple: false)
        lines = read_text_file(path).split("\n", -1)
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
        write_text_file(path, indent_pubspec_sequences(out.join("\n")))
      end

      def flutter_build_command(platform)
        case platform
        when "apk", "android"
          ["build", "apk"]
        when "aab", "appbundle"
          ["build", "appbundle"]
        when "ios"
          ["build", "ios"]
        when "ipa"
          ["build", "ipa"]
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

      def ios_device_build_needs_codesign_flag?(platform, build_args)
        return false unless platform == "ios"
        return false if build_args.include?("--simulator")
        return false if build_args.include?("--no-codesign")
        return false if build_args.include?("--codesign")

        true
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

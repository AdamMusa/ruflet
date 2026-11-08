# frozen_string_literal: true

require "fileutils"
require "find"
require "digest"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "uri"
require "yaml"

require_relative "build/support"
require_relative "build/config_loader"
require_relative "build/config_schema"
require_relative "build/config_schema/sections"
require_relative "build/config_schema/app_identity"
require_relative "build/config_schema/backend"
require_relative "build/config_schema/signing"
require_relative "build/config_schema/runtime"
require_relative "build/config_schema/services"
require_relative "build/config_schema/extensions"
require_relative "build/config_schema/assets"
require_relative "build/context"
require_relative "build/contributors"
require_relative "build/client_dir"
require_relative "build/flutter_tooling"
require_relative "build/exports"
require_relative "build/pipeline"
require_relative "build/embedded_project"
require_relative "build/embedded_runtime"
require_relative "build/native_config/android_manifest"
require_relative "build/native_config/apple_plist"
require_relative "build/native_config/apple_pbxproj"
require_relative "build/native_config/entitlements"
require_relative "build/native_config/gradle"
require_relative "build/native_config/podfile"
require_relative "build/native_config/pubspec"
# Each contributor registers itself as it loads, so this is the order they
# run in (build_contributors_test pins it).
require_relative "build/contributors/template_refresh"
require_relative "build/contributors/apple_host"
require_relative "build/contributors/app_identity"
require_relative "build/contributors/protected_services"
require_relative "build/contributors/signing"
require_relative "build/contributors/runtime_mode"
require_relative "build/contributors/extensions"
require_relative "build/contributors/assets"

module Ruflet
  module CLI
    # `ruflet build` and `ruflet install`. Everything they use is defined in
    # cli/build/ and mixed in here, so Ruflet::CLI and code that includes this
    # module reach the same methods and constants as before the split.
    module BuildCommand
      include FlutterSdk
      include TemplateSurfaceCheck
      include Build::Support
      include Build::ConfigLoader
      include Build::ClientDir
      include Build::FlutterTooling
      include Build::Exports
      include Build::Pipeline
      include Build::EmbeddedProject
      include Build::EmbeddedRuntime
      include Build::NativeConfig::AndroidManifest
      include Build::NativeConfig::ApplePlist
      include Build::NativeConfig::ApplePbxproj
      include Build::NativeConfig::Entitlements
      include Build::NativeConfig::Gradle
      include Build::NativeConfig::Podfile
      include Build::NativeConfig::Pubspec
      include Build::Contributors::TemplateRefresh
      include Build::Contributors::AppleHost
      include Build::Contributors::AppIdentity
      include Build::Contributors::ProtectedServices
      include Build::Contributors::Signing
      include Build::Contributors::RuntimeMode
      include Build::Contributors::Extensions
      include Build::Contributors::Assets

      def command_build(args)
        self_contained_flag = args.delete("--self")
        lite = args.delete("--lite")
        full = args.delete("--full")
        strict = args.delete("--strict")
        if lite && full
          warn "build config error: --lite and --full are mutually exclusive"
          return 1
        end
        # --self enables the embedded runtime and defaults its profile to lite.
        # An explicit profile still wins, so --self --full selects full CRuby.
        self_contained = self_contained_flag || lite || full
        runtime_profile = full ? :full : :lite
        @ruflet_runtime_profile = self_contained ? runtime_profile : :server
        @ruflet_runtime_profile_explicit = !!(lite || full)
        verbose = args.delete("--verbose") || args.delete("-v")
        platform = extract_build_target!(args)
        if platform.empty?
          warn "Usage: ruflet build <apk|android|aab|ios|ipa|web|macos|windows|linux> [--lite|--full|--self] [--verbose]"
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
        @ruflet_build_platform = platform

        # The embedded Ruby VM is a native plugin with no browser
        # implementation, so a self-contained web build produces an app that
        # cannot start. Say so rather than shipping one that hangs.
        if self_contained && platform == "web"
          profile_flag = @ruflet_runtime_profile_explicit ? "--#{runtime_profile}" : "--self"
          warn "build config error: #{profile_flag} is not supported for web"
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

        mode = self_contained ? "self-contained #{runtime_profile}" : "server-driven"
        build_note("Preparing #{platform} build (#{mode})")
        config = load_ruflet_config
        return 1 unless check_template_surface(build_template_surface_root(client_dir), strict: !!strict, config: config)

        if runtime_profile == :full && self_contained
          return 1 unless configure_full_runtime_distribution(config, platform, verbose: !!verbose)
        end
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

        # Flutter runs in build/client; relative path flags mean the project.
        build_args = [*flutter_cmd, *resolve_flutter_path_args(args)]
        build_args << "--codesign" if ios_device_build_needs_codesign_flag?(requested_platform, build_args)
        target_entrypoint = flutter_target_entrypoint(client_dir, self_contained: !!self_contained)
        build_args += ["--target", target_entrypoint] if target_entrypoint
        backend_url = configured_backend_url(config)
        if self_contained
          # Pin the embedded project for platform autostart instead of asking
          # the native layer to infer it from every main.rb/main.mrb in the
          # bundled asset tree.
          build_args += ["--dart-define", "RUFLET_EMBEDDED_PROJECT=#{self_contained_project_name}"]
          if @ruflet_runtime_profile_explicit
            build_args += ["--dart-define", "RUFLET_RUNTIME_PROFILE=#{runtime_profile}"]
          end
          # The platform layer starts the VM before Flutter exists, so the app
          # bundle -- not a Dart define -- has to carry the same decision.
          configure_platform_autostart(client_dir, platform, verbose: !!verbose)
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

        logged_mode = if self_contained
          @ruflet_runtime_profile_explicit ? runtime_profile : "self"
        else
          "server"
        end
        build_log(verbose, "mode=#{logged_mode}")
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
        if ok && self_contained && requested_platform == "ios" &&
            !build_args.include?("--simulator") && !full_runtime_device_only?
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
        device_id = extract_option_value!(args, "--device", "-d") || extract_equals_option_value!(args, "--device")

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
    end
  end
end

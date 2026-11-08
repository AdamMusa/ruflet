# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Prepares the managed client for one `ruflet build`.
      module Pipeline
        private

        def prepare_flutter_client(client_dir, platform:, tools:, config:, self_contained: false, verbose: false)
          refreshed = refresh_managed_client_template_files(
            client_dir, platform: platform, verbose: verbose)
          return false if refreshed == false
          unless remove_native_apple_renderer_integration(
            client_dir, platform: platform, verbose: verbose)
            return false
          end
          metadata = sync_client_metadata(client_dir, config, verbose: verbose)
          return false unless validate_mobile_app_identity(metadata, platform: platform)

          apply_native_service_permissions(client_dir, config)
          apply_android_signing_config(client_dir, platform, verbose: !!verbose)
          apply_ios_signing_team(client_dir, config) if %w[ios ipa macos].include?(platform.to_s)
          configured = configure_client_runtime_mode(client_dir, self_contained: self_contained, verbose: verbose)
          return false if configured == false
          configure_native_apple_runtime(
            client_dir, platform: platform, self_contained: self_contained,
            config: config, verbose: verbose)
          configure_android_runtime(
            client_dir, platform: platform, self_contained: self_contained,
            verbose: verbose)
          @ruflet_self_contained_build = self_contained
          extension_keys = apply_service_extension_config(client_dir, config)
          if @ruflet_extension_selection_applied && !validate_flutter_extension_selection(client_dir)
            return false
          end
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
          if @ruflet_extension_selection_applied && !validate_local_ruflet_packages(client_dir)
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
      end
    end
  end
end

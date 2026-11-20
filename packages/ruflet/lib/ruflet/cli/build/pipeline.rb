# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Prepares the managed client for one `ruflet build`: the registered
      # contributors write its configuration, then Flutter resolves packages
      # and the generators run.
      module Pipeline
        private

        def build_contributors
          Contributors.entries
        end

        def prepare_flutter_client(client_dir, platform:, tools:, config:, self_contained: false, verbose: false)
          build = Context.new(
            client_dir: client_dir, platform: platform, tools: tools, config: config,
            self_contained: self_contained, verbose: verbose, asset_flags: {}
          )
          build_contributors.each do |contributor|
            return false unless __send__(contributor.handler, build)
          end
          metadata = build.metadata
          asset_flags = build.asset_flags

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

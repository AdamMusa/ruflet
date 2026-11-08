# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module Contributors
        # Restores the Flutter-only Apple host in clients generated while the Swift
        # renderer existed.
        module AppleHost
          private

          def contribute_apple_host(build)
            remove_native_apple_renderer_integration(
              build.client_dir, platform: build.platform, verbose: build.verbose)
          end

          # Ruflet had a second, Swift-rendered Apple host. It is gone: every
          # platform renders through the Ruflet Flutter engine. A client generated
          # while it existed still carries the Swift package, the engine-choice
          # shim and the Xcode references, so a rebuild strips them.
          def remove_native_apple_renderer_integration(client_dir, platform:, verbose: false)
            apple_platform = case platform.to_s
            when "ios", "ipa" then "ios"
            when "macos" then "macos"
            end
            return true unless apple_platform

            unless restore_flutter_apple_host(client_dir, apple_platform, verbose: verbose)
              return false
            end
            strip_native_apple_xcode_project(client_dir, apple_platform)
            FileUtils.rm_f(File.join(client_dir, apple_platform, "Runner", "RufletEngineChoice.swift"))
            FileUtils.rm_rf(File.join(client_dir, "apple_packages"))
            FileUtils.rm_rf(File.join(client_dir, "apple_extensions"))
            configure_ios_scene_delegate(client_dir) if apple_platform == "ios"
            apple_info_plist_paths(client_dir).each do |path|
              remove_plist_value(path, "RufletExperimentalNativeRenderer")
              remove_plist_value(path, "GADApplicationIdentifier")
            end
            build_log(verbose, "removed native Apple renderer integration")
            true
          end

          def restore_flutter_apple_host(client_dir, platform, verbose: false)
            template_root = if Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)
              Ruflet::CLI.send(:resolve_ruflet_client_template_root)
            end
            filename = platform == "ios" ? "AppDelegate.swift" : "MainFlutterWindow.swift"
            source = template_root && File.join(template_root, "flutter_hosts", platform, "Runner", filename)
            unless source && File.file?(source)
              warn "build config error: the Ruflet client template is missing the Flutter-only #{platform} host"
              return false
            end

            destination = File.join(client_dir, platform, "Runner", filename)
            FileUtils.mkdir_p(File.dirname(destination))
            FileUtils.cp(source, destination)
            build_log(verbose, "restored Flutter-only #{platform} host")
            true
          end

          # Only the Flutter host remains, so the scene delegate is Flutter's own.
          # A client built against the Swift renderer names RufletSceneDelegate,
          # which lived in the deleted package -- launching it would trap on a
          # missing class. FlutterSceneDelegate comes from the Flutter framework,
          # so it carries no $(PRODUCT_MODULE_NAME) prefix.
          def configure_ios_scene_delegate(client_dir)
            path = File.join(client_dir, "ios", "Runner", "Info.plist")
            return unless File.file?(path)

            content = read_text_file(path)
            content.gsub!(
              %r{(<key>UISceneDelegateClassName</key>\s*<string>)(?:\$\(PRODUCT_MODULE_NAME\)\.)?(?:RufletSceneDelegate|FlutterSceneDelegate|SceneDelegate)(</string>)}m,
              "\\1FlutterSceneDelegate\\2"
            )
            write_text_file(path, content)
          end
        end

        register :apple_host, :contribute_apple_host
      end
    end
  end
end

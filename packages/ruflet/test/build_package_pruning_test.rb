# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class RufletCliBuildPackagePruningTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  def test_keeps_only_core_and_packages_declared_by_services_and_extensions
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_root = File.join(dir, "template")
      client_dir = File.join(dir, "client")
      package_names = %w[
        ruflet ruflet_audio_recorder ruflet_permission_handler ruflet_spinkit ruflet_video
      ]
      package_names.each do |name|
        FileUtils.mkdir_p(File.join(template_root, "ruflet_packages", name))
        File.write(File.join(template_root, "ruflet_packages", name, "marker"), name)
        FileUtils.mkdir_p(File.join(client_dir, "ruflet_packages", name))
      end
      FileUtils.mkdir_p(File.join(client_dir, "ruflet_packages", "ruflet_ads"))
      File.write(File.join(client_dir, "ruflet_packages", "ruflet", "obsolete"), "stale")
      FileUtils.mkdir_p(File.join(template_root, "ruflet_packages", "ruflet", ".cache"))
      File.write(File.join(template_root, "ruflet_packages", "ruflet", ".cache", "developer-cache"), "not distributable")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(
        File.join(template_root, "pubspec.yaml"),
        <<~YAML
          dependencies:
            ruflet_audio_recorder:
              path: ruflet_packages/ruflet_audio_recorder
            ruflet_permission_handler:
              path: ruflet_packages/ruflet_permission_handler
            ruflet_spinkit:
              path: ruflet_packages/ruflet_spinkit
            ruflet_video:
              path: ruflet_packages/ruflet_video
        YAML
      )
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        "dependencies:\n  ruflet:\n    path: ruflet_packages/ruflet\n"
      )

      Ruflet::CLI.stub(:resolve_ruflet_client_template_root, template_root) do
        builder.send(
          :apply_service_extension_config,
          client_dir,
          { "services" => ["microphone"], "extensions" => ["spinkit"] }
        )

        assert_equal(
          %w[ruflet ruflet_audio_recorder ruflet_permission_handler ruflet_spinkit],
          package_directories(client_dir)
        )
        assert_equal "ruflet", File.read(File.join(client_dir, "ruflet_packages", "ruflet", "marker"))
        refute File.exist?(File.join(client_dir, "ruflet_packages", "ruflet", "obsolete"))
        refute Dir.exist?(File.join(client_dir, "ruflet_packages", "ruflet", ".cache"))

        # A later build with a different declaration restores its package from
        # the immutable template before pruning packages no longer selected.
        builder.send(
          :apply_service_extension_config,
          client_dir,
          { "extensions" => ["video"] }
        )
        assert_equal %w[ruflet ruflet_video], package_directories(client_dir)
        assert_equal "ruflet_video", File.read(File.join(client_dir, "ruflet_packages", "ruflet_video", "marker"))
      end
    end
  end

  def test_experimental_apple_build_keeps_native_selection_but_removes_flutter_extension_plugins
    builder = DummyBuilder.new
    builder.instance_variable_set(:@ruflet_experimental_native_renderer, true)

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      %w[ruflet ruflet_audio ruflet_audio_recorder ruflet_permission_handler ruflet_video].each do |name|
        FileUtils.mkdir_p(File.join(client_dir, "ruflet_packages", name))
      end
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            ruflet:
              path: ruflet_packages/ruflet
            ruflet_audio:
              path: ruflet_packages/ruflet_audio
            ruflet_audio_recorder:
              path: ruflet_packages/ruflet_audio_recorder
            ruflet_permission_handler:
              path: ruflet_packages/ruflet_permission_handler
            ruflet_video:
              path: ruflet_packages/ruflet_video
        YAML
      )
      File.write(
        File.join(client_dir, "lib", "main.self.dart"),
        <<~DART
          import 'package:ruflet/ruflet.dart';
          import 'package:ruflet_audio/ruflet_audio.dart' as ruflet_audio;
          import 'package:ruflet_audio_recorder/ruflet_audio_recorder.dart' as ruflet_audio_recorder;
          import 'package:ruflet_permission_handler/ruflet_permission_handler.dart' as ruflet_permission_handler;
          import 'package:ruflet_video/ruflet_video.dart' as ruflet_video;

          final extensions = <RufletExtension>[
            ruflet_audio.Extension(),
            ruflet_audio_recorder.Extension(),
            ruflet_permission_handler.Extension(),
            ruflet_video.Extension(),
          ];
        DART
      )

      native_keys = builder.send(
        :apply_service_extension_config,
        client_dir,
        { "services" => ["microphone"], "extensions" => ["audio", "video"] }
      )

      assert_equal %w[audio video audio_recorder permission_handler microphone].sort, native_keys.sort
      assert_equal %w[ruflet], package_directories(client_dir)
      dependencies = YAML.safe_load(
        File.read(File.join(client_dir, "pubspec.yaml")), aliases: true
      ).fetch("dependencies")
      assert_equal %w[ruflet], dependencies.keys
      main = File.read(File.join(client_dir, "lib", "main.self.dart"))
      refute_includes main, "ruflet_audio"
      refute_includes main, "ruflet_video"
      refute_includes main, "ruflet_permission_handler.Extension()"
      assert builder.send(:validate_flutter_extension_selection, client_dir)
    end
  end

  def test_removes_external_extension_left_by_an_earlier_build
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      FileUtils.mkdir_p(File.join(client_dir, ".ruflet"))
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            ruflet: any
            old_extension:
              git: https://example.test/old_extension.git
        YAML
      )
      File.write(
        File.join(client_dir, "lib", "main.server.dart"),
        <<~DART
          import 'package:ruflet/ruflet.dart';
          import 'package:old_extension/old_extension.dart' as old_extension;
          final extensions = <RufletExtension>[
            old_extension.Extension(),
          ];
        DART
      )
      File.write(
        File.join(client_dir, ".ruflet", "extension_dependencies.json"),
        JSON.generate("external_packages" => ["old_extension"])
      )

      builder.send(:apply_service_extension_config, client_dir, {})

      dependencies = YAML.safe_load(
        File.read(File.join(client_dir, "pubspec.yaml")), aliases: true
      ).fetch("dependencies")
      refute dependencies.key?("old_extension")
      main = File.read(File.join(client_dir, "lib", "main.server.dart"))
      refute_includes main, "package:old_extension"
      refute_includes main, "old_extension.Extension()"
      assert builder.send(:validate_flutter_extension_selection, client_dir)
    end
  end

  def test_native_permissions_are_replaced_by_current_service_declarations
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      manifest = File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml")
      plist = File.join(dir, "ios", "Runner", "Info.plist")
      FileUtils.mkdir_p(File.dirname(manifest))
      FileUtils.mkdir_p(File.dirname(plist))
      File.write(
        manifest,
        <<~XML
          <manifest xmlns:android="http://schemas.android.com/apk/res/android">
            <uses-permission android:name="android.permission.INTERNET"/>
            <uses-permission android:name="android.permission.CAMERA"/>
            <uses-permission android:name="android.permission.RECORD_AUDIO"/>
            <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
            <uses-permission android:name="android.permission.FLASHLIGHT"/>
            <application/>
          </manifest>
        XML
      )
      File.write(
        plist,
        <<~XML
          <plist><dict>
            <key>NSCameraUsageDescription</key><string>old camera</string>
            <key>NSMicrophoneUsageDescription</key><string>old microphone</string>
            <key>NSLocationWhenInUseUsageDescription</key><string>old location</string>
            <key>NSPhotoLibraryUsageDescription</key><string>old photos</string>
          </dict></plist>
        XML
      )

      builder.send(
        :apply_native_service_permissions,
        dir,
        { "services" => [{ "microphone" => { "description" => "Record voice notes." } }] }
      )

      android = File.read(manifest)
      assert_includes android, "android.permission.INTERNET"
      assert_includes android, "android.permission.RECORD_AUDIO"
      refute_includes android, "android.permission.CAMERA"
      refute_includes android, "android.permission.ACCESS_FINE_LOCATION"
      refute_includes android, "android.permission.FLASHLIGHT"

      ios = File.read(plist)
      assert_includes ios, "NSMicrophoneUsageDescription"
      assert_includes ios, "Record voice notes."
      refute_includes ios, "NSCameraUsageDescription"
      refute_includes ios, "NSLocationWhenInUseUsageDescription"
      refute_includes ios, "NSPhotoLibraryUsageDescription"
    end
  end

  private

  def package_directories(client_dir)
    Dir.children(File.join(client_dir, "ruflet_packages"))
      .select { |entry| Dir.exist?(File.join(client_dir, "ruflet_packages", entry)) }
      .sort
  end
end

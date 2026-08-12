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
        flet flet_audio_recorder flet_permission_handler flet_spinkit flet_video
      ]
      package_names.each do |name|
        FileUtils.mkdir_p(File.join(template_root, "flet_packages", name))
        File.write(File.join(template_root, "flet_packages", name, "marker"), name)
        FileUtils.mkdir_p(File.join(client_dir, "flet_packages", name))
      end
      FileUtils.mkdir_p(File.join(client_dir, "flet_packages", "flet_ads"))
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(
        File.join(template_root, "pubspec.yaml"),
        <<~YAML
          dependencies:
            flet_audio_recorder:
              path: flet_packages/flet_audio_recorder
            flet_permission_handler:
              path: flet_packages/flet_permission_handler
            flet_spinkit:
              path: flet_packages/flet_spinkit
            flet_video:
              path: flet_packages/flet_video
        YAML
      )
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        "dependencies:\n  flet:\n    path: flet_packages/flet\n"
      )

      Ruflet::CLI.stub(:resolve_ruflet_client_template_root, template_root) do
        builder.send(
          :apply_service_extension_config,
          client_dir,
          { "services" => ["microphone"], "extensions" => ["spinkit"] }
        )

        assert_equal(
          %w[flet flet_audio_recorder flet_permission_handler flet_spinkit],
          package_directories(client_dir)
        )

        # A later build with a different declaration restores its package from
        # the immutable template before pruning packages no longer selected.
        builder.send(
          :apply_service_extension_config,
          client_dir,
          { "extensions" => ["video"] }
        )
        assert_equal %w[flet flet_video], package_directories(client_dir)
        assert_equal "flet_video", File.read(File.join(client_dir, "flet_packages", "flet_video", "marker"))
      end
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
    Dir.children(File.join(client_dir, "flet_packages"))
      .select { |entry| Dir.exist?(File.join(client_dir, "flet_packages", entry)) }
      .sort
  end
end

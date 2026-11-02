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

  def test_local_auth_is_selected_by_extension_or_biometrics_service
    builder = DummyBuilder.new

    assert_equal(
      { package: "ruflet_local_auth", alias: "ruflet_local_auth" },
      Ruflet::CLI::BuildCommand::CLIENT_EXTENSION_MAP["local_auth"]
    )
    assert_equal(
      Ruflet::CLI::BuildCommand::CLIENT_EXTENSION_MAP["local_auth"],
      Ruflet::CLI::NewCommand::CLIENT_EXTENSION_MAP["local_auth"]
    )
    assert_includes builder.send(:configured_extension_keys, { "extensions" => ["local_auth"] }), "local_auth"
    assert_includes builder.send(:configured_extension_keys, { "services" => ["biometrics"] }), "local_auth"

    Dir.mktmpdir do |dir|
      template_root = File.join(dir, "template")
      client_dir = File.join(dir, "client")
      %w[ruflet ruflet_local_auth].each do |name|
        FileUtils.mkdir_p(File.join(template_root, "ruflet_packages", name))
        File.write(File.join(template_root, "ruflet_packages", name, "marker"), name)
      end
      FileUtils.mkdir_p(File.join(template_root, "lib"))
      File.write(
        File.join(template_root, "pubspec.yaml"),
        "dependencies:\n  ruflet_local_auth:\n    path: ruflet_packages/ruflet_local_auth\n"
      )
      File.write(
        File.join(template_root, "lib", "main.server.dart"),
        <<~DART
          import 'package:ruflet/ruflet.dart';
          import 'package:ruflet_local_auth/ruflet_local_auth.dart' as ruflet_local_auth;
          final extensions = <RufletExtension>[
            ruflet_local_auth.Extension(),
          ];
        DART
      )
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(client_dir, "pubspec.yaml"), "dependencies:\n  ruflet:\n    path: ruflet_packages/ruflet\n")
      File.write(
        File.join(client_dir, "lib", "main.server.dart"),
        "import 'package:ruflet/ruflet.dart';\nfinal extensions = <RufletExtension>[\n];\n"
      )

      Ruflet::CLI.stub(:resolve_ruflet_client_template_root, template_root) do
        builder.send(:apply_service_extension_config, client_dir, { "services" => ["biometrics"] })
      end

      assert_equal %w[ruflet ruflet_local_auth], package_directories(client_dir)
      dependencies = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true).fetch("dependencies")
      assert_equal({ "path" => "ruflet_packages/ruflet_local_auth" }, dependencies["ruflet_local_auth"])
      main = File.read(File.join(client_dir, "lib", "main.server.dart"))
      assert_includes main, "import 'package:ruflet_local_auth/ruflet_local_auth.dart' as ruflet_local_auth;"
      assert_includes main, "ruflet_local_auth.Extension(),"
      assert builder.send(:validate_flutter_extension_selection, client_dir)
    end
  end

  def test_local_auth_adds_the_face_id_usage_description
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      plist = File.join(dir, "ios", "Runner", "Info.plist")
      FileUtils.mkdir_p(File.dirname(plist))
      File.write(plist, "<plist><dict>\n</dict></plist>\n")

      builder.send(:apply_native_service_permissions, dir, { "extensions" => ["local_auth"] })
      assert_includes File.read(plist), "<key>NSFaceIDUsageDescription</key>"

      builder.send(
        :apply_native_service_permissions, dir,
        { "services" => [{ "biometrics" => { "description" => "Unlock your notes with Face ID." } }] }
      )
      ios = File.read(plist)
      assert_includes ios, "<key>NSFaceIDUsageDescription</key>\n\t<string>Unlock your notes with Face ID.</string>"
      assert_equal 1, ios.scan("NSFaceIDUsageDescription").length

      builder.send(:apply_native_service_permissions, dir, {})
      refute_includes File.read(plist), "NSFaceIDUsageDescription"
    end
  end

  def test_local_auth_switches_the_android_activity_to_a_fragment_activity
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      kotlin = File.join(dir, "android", "app", "src", "main", "kotlin", "com", "example", "app", "MainActivity.kt")
      java = File.join(dir, "android", "app", "src", "main", "java", "com", "example", "legacy", "MainActivity.java")
      custom = File.join(dir, "android", "app", "src", "main", "kotlin", "com", "example", "custom", "MainActivity.kt")
      [kotlin, java, custom].each { |path| FileUtils.mkdir_p(File.dirname(path)) }
      kotlin_source = <<~KOTLIN
        package com.example.app

        import io.flutter.embedding.android.FlutterActivity

        class MainActivity : FlutterActivity()
      KOTLIN
      java_source = <<~JAVA
        package com.example.legacy;

        import io.flutter.embedding.android.FlutterActivity;

        public class MainActivity extends FlutterActivity {
        }
      JAVA
      custom_source = <<~KOTLIN
        package com.example.custom

        import io.flutter.embedding.android.FlutterActivity

        class MainActivity : MyBaseActivity()
      KOTLIN
      File.write(kotlin, kotlin_source)
      File.write(java, java_source)
      File.write(custom, custom_source)

      builder.send(:apply_android_activity_base, dir, %w[charts local_auth])

      assert_equal kotlin_source.gsub("FlutterActivity", "FlutterFragmentActivity"), File.read(kotlin)
      assert_equal java_source.gsub("FlutterActivity", "FlutterFragmentActivity"), File.read(java)
      assert_equal custom_source, File.read(custom)

      # Idempotent, then reverted once local_auth is no longer selected.
      builder.send(:apply_android_activity_base, dir, %w[local_auth])
      assert_equal kotlin_source.gsub("FlutterActivity", "FlutterFragmentActivity"), File.read(kotlin)
      builder.send(:apply_android_activity_base, dir, %w[charts])
      assert_equal kotlin_source, File.read(kotlin)
      assert_equal java_source, File.read(java)
      assert_equal custom_source, File.read(custom)
    end
  end

  private

  def package_directories(client_dir)
    Dir.children(File.join(client_dir, "ruflet_packages"))
      .select { |entry| Dir.exist?(File.join(client_dir, "ruflet_packages", entry)) }
      .sort
  end
end

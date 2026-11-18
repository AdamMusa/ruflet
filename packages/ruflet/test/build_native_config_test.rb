# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

# The native_config writers own one host file each; contributors decide what
# goes in. These pin the writers the services contributor uses, which later
# features (raw manifest keys, entitlements) will call too.
class RufletCliBuildNativeConfigTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  MANIFEST = <<~XML
    <manifest xmlns:android="http://schemas.android.com/apk/res/android">
        <uses-permission android:name="android.permission.INTERNET"/>
        <uses-permission android:name="android.permission.CAMERA"/>
        <uses-permission android:name="android.permission.FLASHLIGHT"/>
        <application android:label="app">
        </application>
    </manifest>
  XML

  ENTITLEMENTS = <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0">
    <dict>
    \t<key>com.apple.security.app-sandbox</key>
    \t<true/>
    \t<key>com.apple.security.device.camera</key>
    \t<true/>
    </dict>
    </plist>
  PLIST

  def builder
    @builder ||= DummyBuilder.new
  end

  def manifest_path(client_dir)
    File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def test_android_permissions_replace_the_managed_set_and_keep_the_rest
    Dir.mktmpdir do |dir|
      write(manifest_path(dir), MANIFEST)
      managed = %w[android.permission.CAMERA android.permission.FLASHLIGHT android.permission.RECORD_AUDIO]

      2.times do
        builder.send(:write_android_manifest_permissions, dir,
          managed: managed, permissions: %w[android.permission.RECORD_AUDIO android.permission.INTERNET])
      end

      manifest = File.read(manifest_path(dir))
      assert_equal 1, manifest.scan("android.permission.INTERNET").size
      assert_equal 1, manifest.scan("android.permission.RECORD_AUDIO").size
      refute_includes manifest, "android.permission.CAMERA"
      refute_includes manifest, "android.permission.FLASHLIGHT"
      assert_match(%r{<manifest[^>]*>\s*<uses-permission android:name="android.permission.RECORD_AUDIO"/>\n}, manifest)
    end
  end

  def test_android_permissions_skip_a_client_without_an_android_host
    Dir.mktmpdir do |dir|
      builder.send(:write_android_manifest_permissions, dir, managed: [], permissions: %w[android.permission.CAMERA])

      refute File.exist?(manifest_path(dir))
    end
  end

  def test_macos_entitlements_replace_the_managed_set_in_both_files
    Dir.mktmpdir do |dir|
      names = %w[DebugProfile.entitlements Release.entitlements]
      names.each { |name| write(File.join(dir, "macos", "Runner", name), ENTITLEMENTS) }
      managed = %w[com.apple.security.device.camera com.apple.security.device.audio-input]

      2.times do
        builder.send(:write_macos_entitlements, dir,
          managed: managed, enabled: %w[com.apple.security.device.audio-input])
      end

      names.each do |name|
        content = File.read(File.join(dir, "macos", "Runner", name))
        assert_includes content, "<key>com.apple.security.app-sandbox</key>"
        refute_includes content, "com.apple.security.device.camera"
        assert_equal 1, content.scan("com.apple.security.device.audio-input").size
        assert content.end_with?("\t<key>com.apple.security.device.audio-input</key>\n\t<true/>\n</dict>\n</plist>\n"), name
      end
    end
  end

  def test_macos_entitlements_skip_missing_files
    Dir.mktmpdir do |dir|
      write(File.join(dir, "macos", "Runner", "Release.entitlements"), ENTITLEMENTS)

      builder.send(:write_macos_entitlements, dir, managed: [], enabled: %w[com.apple.security.device.audio-input])

      refute File.exist?(File.join(dir, "macos", "Runner", "DebugProfile.entitlements"))
      release = File.read(File.join(dir, "macos", "Runner", "Release.entitlements"))
      assert_includes release, "com.apple.security.device.camera"
      assert_includes release, "com.apple.security.device.audio-input"
    end
  end
end

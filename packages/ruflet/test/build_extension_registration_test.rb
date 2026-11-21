# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

# Where a build writes an extension's `Extension()` registration in a client
# entrypoint. The template brackets some imports at the top of main.self.dart
# and main.server.dart with FAT_CLIENT markers, as well as entries in the
# extensions list; only the list's markers place a registration. A file with no
# extensions list (lib/main.dart) gets no registration.
class RufletCliBuildExtensionRegistrationTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  # The shape of the template's lib/main.server.dart: FAT_CLIENT blocks in the
  # imports, then the extensions list with its own FAT_CLIENT block.
  ENTRYPOINT = <<~DART
    import 'dart:async';

    import 'package:ruflet/ruflet.dart';
    import 'package:ruflet_ads/ruflet_ads.dart' as ruflet_ads;
    // --FAT_CLIENT_START--
    import 'package:ruflet_audio/ruflet_audio.dart' as ruflet_audio;
    // --FAT_CLIENT_END--
    import 'package:ruflet_spinkit/ruflet_spinkit.dart' as ruflet_spinkit;
    // --FAT_CLIENT_START--
    // --FAT_CLIENT_END--
    import 'package:flutter/material.dart';

    Future<void> main() async {
      final extensions = <RufletExtension>[
        ruflet_ads.Extension(),
        ruflet_spinkit.Extension(),

        // --FAT_CLIENT_START--
        ruflet_audio.Extension(),
        // --FAT_CLIENT_END--
      ];

      for (final extension in extensions) {
        extension.ensureInitialized();
      }
    }
  DART

  def test_external_extension_is_registered_in_the_list_not_the_imports
    Dir.mktmpdir do |dir|
      path = File.join(dir, "main.server.dart")
      File.write(path, ENTRYPOINT)

      DummyBuilder.new.send(:sync_external_extension_registrations, path, [{ name: "ext_pkg" }])

      assert_equal <<~DART, File.read(path)
        import 'dart:async';

        import 'package:ruflet/ruflet.dart';
        import 'package:ruflet_ads/ruflet_ads.dart' as ruflet_ads;
        // --FAT_CLIENT_START--
        import 'package:ruflet_audio/ruflet_audio.dart' as ruflet_audio;
        // --FAT_CLIENT_END--
        import 'package:ruflet_spinkit/ruflet_spinkit.dart' as ruflet_spinkit;
        // --FAT_CLIENT_START--
        // --FAT_CLIENT_END--
        import 'package:flutter/material.dart';
        import 'package:ext_pkg/ext_pkg.dart' as ext_pkg;

        Future<void> main() async {
          final extensions = <RufletExtension>[
            ruflet_ads.Extension(),
            ruflet_spinkit.Extension(),

            ext_pkg.Extension(),
            // --FAT_CLIENT_START--
            ruflet_audio.Extension(),
            // --FAT_CLIENT_END--
          ];

          for (final extension in extensions) {
            extension.ensureInitialized();
          }
        }
      DART
    end
  end

  def test_a_rebuild_does_not_register_the_extension_twice
    Dir.mktmpdir do |dir|
      path = File.join(dir, "main.self.dart")
      File.write(path, ENTRYPOINT)
      builder = DummyBuilder.new

      2.times { builder.send(:sync_external_extension_registrations, path, [{ name: "ext_pkg" }]) }

      content = File.read(path)
      assert_equal 1, content.scan("ext_pkg.Extension(),").length
      assert_equal 1, content.scan("import 'package:ext_pkg/ext_pkg.dart' as ext_pkg;").length
    end
  end

  def test_an_entrypoint_without_a_list_is_left_unchanged
    # The template's lib/main.dart: it only calls main.self.dart, which
    # registers the extensions.
    wrapper = <<~DART
      import 'main.self.dart' as self_app;

      Future<void> main() => self_app.main();
    DART

    Dir.mktmpdir do |dir|
      path = File.join(dir, "main.dart")
      File.write(path, wrapper)

      DummyBuilder.new.send(:sync_external_extension_registrations, path, [{ name: "ext_pkg" }])

      assert_equal wrapper, File.read(path)
    end
    assert_equal wrapper, insert(wrapper, "    ext_pkg.Extension(),\n")
  end

  def test_a_list_without_its_own_marker_gets_the_registration_first
    # Markers above and below the list are not the list's.
    content = <<~DART
      // --FAT_CLIENT_START--
      import 'package:ruflet_audio/ruflet_audio.dart' as ruflet_audio;
      // --FAT_CLIENT_END--

      final extensions = <RufletExtension>[
        ruflet_ads.Extension(),
      ];

      // --FAT_CLIENT_START--
      // --FAT_CLIENT_END--
    DART

    assert_equal <<~DART, insert(content, "  ext_pkg.Extension(),\n")
      // --FAT_CLIENT_START--
      import 'package:ruflet_audio/ruflet_audio.dart' as ruflet_audio;
      // --FAT_CLIENT_END--

      final extensions = <RufletExtension>[
        ext_pkg.Extension(),
        ruflet_ads.Extension(),
      ];

      // --FAT_CLIENT_START--
      // --FAT_CLIENT_END--
    DART
  end

  def test_an_unclosed_list_gets_the_registration_right_after_its_opening
    content = <<~DART
      // --FAT_CLIENT_START--
      // --FAT_CLIENT_END--
      final extensions = <RufletExtension>[
        ruflet_ads.Extension(),
        // --FAT_CLIENT_START--
    DART

    assert_equal <<~DART, insert(content, "  ext_pkg.Extension(),\n")
      // --FAT_CLIENT_START--
      // --FAT_CLIENT_END--
      final extensions = <RufletExtension>[
        ext_pkg.Extension(),
        ruflet_ads.Extension(),
        // --FAT_CLIENT_START--
    DART
  end

  private

  def insert(content, extension_line)
    DummyBuilder.new.send(:insert_missing_extension, content, extension_line)
  end
end

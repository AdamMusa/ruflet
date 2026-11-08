# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

# lib/ruflet_bootstrap.g.dart carries the ordered hook lists the template
# entrypoints run before runApp and after the first frame (WP-00 R3).
class RufletCliClientBootstrapTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  # What every build writes while no feature adds a hook. ruflet-template ships
  # this exact file as lib/ruflet_bootstrap.g.dart, so a client built from it is
  # byte-identical whether or not the gem writes the file.
  DEFAULT_BOOTSTRAP = <<~DART
    // GENERATED FILE. DO NOT EDIT.
    //
    // `ruflet build` writes this file into the Flutter client on every build.
    // lib/main.self.dart and lib/main.server.dart run its hooks in list order:
    //
    // * rufletPreRunAppHooks are awaited one at a time just before runApp, once
    //   the Flutter binding and every extension are initialized.
    // * rufletPostFirstFrameHooks run one at a time after the first frame.
    //
    // A hook that throws is reported through FlutterError.reportError and does
    // not stop the hooks after it or the app. With both lists empty the
    // entrypoints skip the hooks entirely. Build features add hooks through
    // Ruflet::CLI::ClientBootstrap in the ruflet gem.

    import 'dart:async';

    /// A bootstrap hook: a top-level or static function that takes no
    /// arguments.
    typedef RufletBootstrapHook = FutureOr<void> Function();

    const rufletPreRunAppHooks = <RufletBootstrapHook>[];

    const rufletPostFirstFrameHooks = <RufletBootstrapHook>[];
  DART

  def test_default_bootstrap_has_empty_hook_lists
    assert_equal DEFAULT_BOOTSTRAP, DummyBuilder.new.send(:render_client_bootstrap, [])
  end

  def test_build_writes_the_default_bootstrap_when_no_feature_adds_a_hook
    Dir.mktmpdir do |client_dir|
      path = DummyBuilder.new.send(
        :write_client_bootstrap, client_dir, { "app" => { "name" => "demo" } },
        platform: "apk", self_contained: false
      )

      assert_equal File.join(client_dir, "lib", "ruflet_bootstrap.g.dart"), path
      assert_equal DEFAULT_BOOTSTRAP, File.binread(path)
    end
  end

  def test_rewrite_replaces_a_stale_bootstrap_and_leaves_a_current_one_untouched
    builder = DummyBuilder.new

    Dir.mktmpdir do |client_dir|
      path = File.join(client_dir, "lib", "ruflet_bootstrap.g.dart")
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, "// left by an earlier build\n")

      builder.send(:write_client_bootstrap, client_dir, {}, platform: "ios", self_contained: true)
      assert_equal DEFAULT_BOOTSTRAP, File.binread(path)

      stamp = Time.at(1_700_000_000)
      File.utime(stamp, stamp, path)
      builder.send(:write_client_bootstrap, client_dir, {}, platform: "ios", self_contained: true)
      assert_equal stamp, File.mtime(path), "an unchanged bootstrap must not be rewritten"
    end
  end

  def test_hooks_render_in_provider_order_with_one_import_per_library
    hooks = [
      { phase: :pre_run_app, import: "package:ruflet/ruflet.dart",
        function: "RufletDeepLinkingBootstrap.install" },
      { phase: "post_first_frame", import: "package:ruflet_trace/ruflet_trace.dart",
        function: "markFirstFrame" },
      { "phase" => "pre_run_app", "import" => "package:ruflet_trace/ruflet_trace.dart",
        "function" => "markMainLoaded" },
      { phase: :pre_run_app, import: "package:ruflet/ruflet.dart",
        function: "installErrorHooks" }
    ]

    expected = DEFAULT_BOOTSTRAP
      .sub(
        "import 'dart:async';\n",
        <<~DART
          import 'dart:async';

          import 'package:ruflet/ruflet.dart' as bootstrap_1;
          import 'package:ruflet_trace/ruflet_trace.dart' as bootstrap_2;
        DART
      )
      .sub(
        "const rufletPreRunAppHooks = <RufletBootstrapHook>[];\n",
        <<~DART
          const rufletPreRunAppHooks = <RufletBootstrapHook>[
            bootstrap_1.RufletDeepLinkingBootstrap.install,
            bootstrap_2.markMainLoaded,
            bootstrap_1.installErrorHooks,
          ];
        DART
      )
      .sub(
        "const rufletPostFirstFrameHooks = <RufletBootstrapHook>[];\n",
        <<~DART
          const rufletPostFirstFrameHooks = <RufletBootstrapHook>[
            bootstrap_2.markFirstFrame,
          ];
        DART
      )

    assert_equal expected, DummyBuilder.new.send(:render_client_bootstrap, hooks)
  end

  def test_providers_supply_the_hooks_a_build_writes
    builder_class = Class.new(DummyBuilder) do
      attr_reader :calls

      def client_bootstrap_hook_providers
        %i[first_hooks second_hooks]
      end

      def first_hooks(config, platform:, self_contained:)
        (@calls ||= []) << [:first, config, platform, self_contained]
        [{ phase: :post_first_frame, import: "package:a/a.dart", function: "a" }]
      end

      def second_hooks(_config, platform:, self_contained:)
        (@calls ||= []) << [:second, platform, self_contained]
        { phase: :pre_run_app, import: "package:b/b.dart", function: "b" }
      end
    end
    builder = builder_class.new
    config = { "deep_links" => { "schemes" => ["demo"] } }

    Dir.mktmpdir do |client_dir|
      path = builder.send(:write_client_bootstrap, client_dir, config, platform: "web", self_contained: false)
      content = File.binread(path)

      assert_equal [[:first, config, "web", false], [:second, "web", false]], builder.calls
      assert_includes content, "import 'package:a/a.dart' as bootstrap_1;\n" \
                               "import 'package:b/b.dart' as bootstrap_2;\n"
      assert_includes content, "const rufletPreRunAppHooks = <RufletBootstrapHook>[\n  bootstrap_2.b,\n];\n"
      assert_includes content, "const rufletPostFirstFrameHooks = <RufletBootstrapHook>[\n  bootstrap_1.a,\n];\n"
    end
  end

  def test_no_build_feature_registers_a_hook_yet
    assert_empty Ruflet::CLI::ClientBootstrap::CLIENT_BOOTSTRAP_HOOK_PROVIDERS
    assert_predicate Ruflet::CLI::ClientBootstrap::CLIENT_BOOTSTRAP_HOOK_PROVIDERS, :frozen?
  end

  def test_rejects_hooks_the_entrypoints_could_not_run
    builder = DummyBuilder.new
    valid = { phase: :pre_run_app, import: "package:a/a.dart", function: "a" }
    [
      valid.merge(phase: :before_main),
      valid.merge(phase: nil),
      valid.merge(import: "package:a/a.dart' as x; import 'dart:io"),
      valid.merge(import: "a\n.dart"),
      valid.merge(import: ""),
      valid.merge(function: "a()"),
      valid.merge(function: "a; print(1)"),
      valid.merge(function: "A.b.c"),
      valid.merge(function: "")
    ].each do |hook|
      assert_raises(ArgumentError, hook.inspect) { builder.send(:render_client_bootstrap, [hook]) }
    end
  end
end

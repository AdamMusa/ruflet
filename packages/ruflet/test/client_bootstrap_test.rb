# frozen_string_literal: true

require_relative "test_helper"
require_relative "compat/lib/tar"
require "fileutils"

# Startup hooks the template entrypoints run before runApp and after the first
# frame (WP-00 R3). The entrypoints declare both lists empty themselves, so a
# build without hooks must leave the client exactly as the template and the
# rest of the build leave it; only a build that adds hooks writes
# lib/ruflet_bootstrap.g.dart and points the entrypoints at it.
class RufletCliClientBootstrapTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  ENTRYPOINTS = %w[lib/main.self.dart lib/main.server.dart].freeze
  GENERATED = "lib/ruflet_bootstrap.g.dart"

  # The block ruflet-template's entrypoints carry (pinned there by
  # tool/conformance/test_bootstrap_hooks_contract.rb).
  TEMPLATE_HOOK_BLOCK = <<~DART

    // Startup hooks for build features. main() above awaits rufletPreRunAppHooks
    // one at a time just before runApp and runs rufletPostFirstFrameHooks after
    // the first frame. Both lists are empty here, so this file builds on its own
    // with every ruflet gem. Only while a build feature adds hooks does
    // `ruflet build` write them to lib/ruflet_bootstrap.g.dart, import that file
    // and empty this block (Ruflet::CLI::ClientBootstrap in the ruflet gem).
    // --RUFLET_BOOTSTRAP_HOOKS_START--
    const rufletPreRunAppHooks = <RufletBootstrapHook>[];
    const rufletPostFirstFrameHooks = <RufletBootstrapHook>[];
    // --RUFLET_BOOTSTRAP_HOOKS_END--

    /// A startup hook: a top-level or static function that takes no arguments.
    typedef RufletBootstrapHook = FutureOr<void> Function();
  DART

  # The file a build writes while an entrypoint imports it but no feature adds
  # a hook.
  EMPTY_BOOTSTRAP = <<~DART
    // GENERATED FILE. DO NOT EDIT.
    //
    // `ruflet build` writes this file only while a build feature adds startup
    // hooks, and imports it from lib/main.self.dart and lib/main.server.dart
    // in place of their own empty lists. They run the hooks in list order:
    //
    // * rufletPreRunAppHooks are awaited one at a time just before runApp, once
    //   the Flutter binding and every extension are initialized.
    // * rufletPostFirstFrameHooks run one at a time after the first frame.
    //
    // A hook that throws is reported through FlutterError.reportError and does
    // not stop the hooks after it or the app. Build features add hooks through
    // Ruflet::CLI::ClientBootstrap in the ruflet gem.

    import 'dart:async';

    const rufletPreRunAppHooks = <FutureOr<void> Function()>[];

    const rufletPostFirstFrameHooks = <FutureOr<void> Function()>[];
  DART

  HOOKS = [
    { phase: :pre_run_app, import: "package:ruflet/ruflet.dart",
      function: "RufletDeepLinkingBootstrap.install" },
    { phase: "post_first_frame", import: "package:ruflet_trace/ruflet_trace.dart",
      function: "markFirstFrame" },
    { "phase" => "pre_run_app", "import" => "package:ruflet_trace/ruflet_trace.dart",
      "function" => "markMainLoaded" },
    { phase: :pre_run_app, import: "package:ruflet/ruflet.dart",
      function: "installErrorHooks" }
  ].freeze

  HOOKED_BOOTSTRAP = EMPTY_BOOTSTRAP
    .sub(
      "import 'dart:async';\n",
      <<~DART
        import 'dart:async';

        import 'package:ruflet/ruflet.dart' as bootstrap_1;
        import 'package:ruflet_trace/ruflet_trace.dart' as bootstrap_2;
      DART
    )
    .sub(
      "const rufletPreRunAppHooks = <FutureOr<void> Function()>[];\n",
      <<~DART
        const rufletPreRunAppHooks = <FutureOr<void> Function()>[
          bootstrap_1.RufletDeepLinkingBootstrap.install,
          bootstrap_2.markMainLoaded,
          bootstrap_1.installErrorHooks,
        ];
      DART
    )
    .sub(
      "const rufletPostFirstFrameHooks = <FutureOr<void> Function()>[];\n",
      <<~DART
        const rufletPostFirstFrameHooks = <FutureOr<void> Function()>[
          bootstrap_2.markFirstFrame,
        ];
      DART
    )
    .freeze

  class HookedBuilder < DummyBuilder
    attr_reader :calls

    def client_bootstrap_hook_providers
      %i[first_hooks second_hooks third_hooks]
    end

    def first_hooks(config, platform:, self_contained:)
      (@calls ||= []) << [:first, config, platform, self_contained]
      HOOKS[0, 2]
    end

    # A provider may return a single Hash.
    def second_hooks(_config, platform:, self_contained:)
      (@calls ||= []) << [:second, platform, self_contained]
      HOOKS[2]
    end

    def third_hooks(_config, platform:, self_contained:)
      (@calls ||= []) << [:third, platform, self_contained]
      [HOOKS[3]]
    end
  end

  # The entrypoints of the template every released gem ships against today
  # (the H1 fixture, ruflet-template e32c873): no hook block, no import.
  def self.released_entrypoints
    @released_entrypoints ||= begin
      archive = File.join(__dir__, "compat", "fixtures", "template", "ruflet_flutter_template.tar")
      entries = File.open(archive, "rb") { |io| RufletCompat::Tar.read(io) }
      ENTRYPOINTS.to_h do |relative_path|
        entry = entries.find { |candidate| candidate.path == "ruflet_flutter_template/#{relative_path}" }
        [relative_path, entry.data.dup.force_encoding(Encoding::UTF_8).freeze]
      end.freeze
    end
  end

  # The same entrypoints with the template's hook block.
  def self.marked_entrypoints
    @marked_entrypoints ||= released_entrypoints.transform_values { |source| (source + TEMPLATE_HOOK_BLOCK).freeze }.freeze
  end

  def test_no_hooks_and_no_import_writes_nothing
    [self.class.released_entrypoints, self.class.marked_entrypoints].each do |entrypoints|
      with_client(entrypoints) do |client_dir|
        before = snapshot(client_dir)

        assert_nil DummyBuilder.new.send(
          :write_client_bootstrap, client_dir, { "app" => { "name" => "demo" } },
          platform: "apk", self_contained: false
        )
        assert_equal before, snapshot(client_dir)
      end
    end
  end

  # RUFLET_CLIENT_DIR, ./ruflet_client and templates/ruflet_flutter_template are
  # the developer's own directories: a build without hooks adds nothing there
  # either, not even an empty lib/.
  def test_no_hooks_leaves_a_client_dir_without_lib_untouched
    Dir.mktmpdir do |client_dir|
      File.write(File.join(client_dir, "pubspec.yaml"), "name: ruflet_client\n")
      before = snapshot(client_dir)

      assert_nil DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal before, snapshot(client_dir)
      refute Dir.exist?(File.join(client_dir, "lib"))
    end
  end

  def test_hooks_are_written_and_the_marked_entrypoints_import_them
    builder = HookedBuilder.new
    config = { "deep_links" => { "schemes" => ["demo"] } }

    with_client(self.class.marked_entrypoints) do |client_dir|
      path = builder.send(:write_client_bootstrap, client_dir, config, platform: "web", self_contained: false)

      assert_equal File.join(client_dir, GENERATED), path
      assert_equal HOOKED_BOOTSTRAP, File.binread(path)
      assert_equal [[:first, config, "web", false], [:second, "web", false], [:third, "web", false]], builder.calls

      self.class.marked_entrypoints.each do |relative_path, source|
        assert_equal routed(source), read_utf8(client_dir, relative_path), relative_path
      end
    end
  end

  def test_routing_twice_changes_nothing_the_second_time
    builder = HookedBuilder.new

    with_client(self.class.marked_entrypoints) do |client_dir|
      builder.send(:write_client_bootstrap, client_dir, {}, platform: "ios", self_contained: true)
      stamp = Time.at(1_700_000_000)
      files = (ENTRYPOINTS + [GENERATED]).map { |relative_path| File.join(client_dir, relative_path) }
      files.each { |file| File.utime(stamp, stamp, file) }
      before = snapshot(client_dir)

      builder.send(:write_client_bootstrap, client_dir, {}, platform: "ios", self_contained: true)

      assert_equal before, snapshot(client_dir)
      files.each { |file| assert_equal stamp, File.mtime(file), "#{file} must not be rewritten" }
    end
  end

  # Every build copies lib/main*.dart from the template first. The generated
  # file a build with hooks left behind is then imported by nothing and goes.
  def test_a_build_without_hooks_after_one_with_hooks_restores_the_template_client
    with_client(self.class.marked_entrypoints) do |template_client|
      before = snapshot(template_client)
      HookedBuilder.new.send(:write_client_bootstrap, template_client, {}, platform: "web")
      self.class.marked_entrypoints.each do |relative_path, source|
        File.binwrite(File.join(template_client, relative_path), source)
      end

      assert_nil DummyBuilder.new.send(:write_client_bootstrap, template_client, {}, platform: "web")
      assert_equal contents(before), contents(snapshot(template_client))
    end
  end

  def test_hooks_with_entrypoints_that_have_no_block_warn_and_write_nothing
    with_client(self.class.released_entrypoints) do |client_dir|
      before = snapshot(client_dir)

      _out, err = capture_io do
        assert_nil HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "apk")
      end

      assert_equal before, snapshot(client_dir)
      assert_equal "warning: lib/main.self.dart and lib/main.server.dart have no " \
                   "// --RUFLET_BOOTSTRAP_HOOKS_START-- block, so the 4 startup hooks this build " \
                   "adds will not run from them. Update the Flutter client from the current " \
                   "ruflet-template.\n", err
    end
  end

  def test_hooks_reach_the_marked_entrypoint_when_the_other_has_no_block
    entrypoints = self.class.marked_entrypoints.merge(
      "lib/main.self.dart" => self.class.released_entrypoints.fetch("lib/main.self.dart")
    )

    with_client(entrypoints) do |client_dir|
      _out, err = capture_io do
        assert_equal File.join(client_dir, GENERATED),
                     HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "apk")
      end

      assert_match(/\Awarning: lib\/main\.self\.dart has no .* will not run from it\./, err)
      assert_equal entrypoints.fetch("lib/main.self.dart"), read_utf8(client_dir, "lib/main.self.dart")
      assert_equal routed(entrypoints.fetch("lib/main.server.dart")),
                   read_utf8(client_dir, "lib/main.server.dart")
      assert_equal HOOKED_BOOTSTRAP, File.binread(File.join(client_dir, GENERATED))
    end
  end

  # For example entrypoints a build with hooks pointed at the file when no
  # template was available to copy them from again.
  def test_an_imported_bootstrap_gets_empty_lists_without_hooks
    entrypoints = self.class.marked_entrypoints.transform_values { |source| routed(source) }

    with_client(entrypoints) do |client_dir|
      path = File.join(client_dir, GENERATED)
      File.binwrite(path, HOOKED_BOOTSTRAP)

      assert_equal path, DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal EMPTY_BOOTSTRAP, File.binread(path)
      entrypoints.each do |relative_path, source|
        assert_equal source, read_utf8(client_dir, relative_path), relative_path
      end

      stamp = Time.at(1_700_000_000)
      File.utime(stamp, stamp, path)
      DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal stamp, File.mtime(path), "an unchanged bootstrap must not be rewritten"
    end
  end

  def test_only_a_generated_file_is_ever_removed
    with_client(self.class.released_entrypoints) do |client_dir|
      path = File.join(client_dir, GENERATED)
      File.binwrite(path, "// The developer's own file.\nconst rufletPreRunAppHooks = [];\n")

      DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert File.file?(path), "a file the CLI did not write must stay"

      File.binwrite(path, HOOKED_BOOTSTRAP)
      DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      refute File.exist?(path), "a generated file nothing imports must go"
    end
  end

  # Detecting the import must not fail a build that works today, whatever a
  # developer keeps under lib/.
  def test_a_client_with_files_that_are_not_utf8_still_builds
    with_client(self.class.marked_entrypoints) do |client_dir|
      File.binwrite(File.join(client_dir, "lib", "latin1.dart"), "// caf\xE9 ruflet_bootstrap.g.dart\n".b)
      FileUtils.mkdir_p(File.join(client_dir, "lib", "folder.dart"))
      before = snapshot(client_dir)

      assert_nil DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal before, snapshot(client_dir)
    end
  end

  def test_recognises_imports_of_the_generated_file_only
    pattern = Ruflet::CLI::ClientBootstrap::CLIENT_BOOTSTRAP_IMPORT_LINE

    ["import 'ruflet_bootstrap.g.dart';", "import \"ruflet_bootstrap.g.dart\";",
     "  import 'package:ruflet_client/ruflet_bootstrap.g.dart' as hooks;"].each do |line|
      assert_match pattern, line
    end
    ["import 'my_ruflet_bootstrap.g.dart';", "// import 'ruflet_bootstrap.g.dart';",
     "export 'ruflet_bootstrap.g.dart';", "import 'ruflet_bootstrap.g.dart\";"].each do |line|
      refute_match pattern, line
    end
  end

  def test_hooks_render_in_provider_order_with_one_import_per_library
    assert_equal HOOKED_BOOTSTRAP, DummyBuilder.new.send(:render_client_bootstrap, HOOKS)
    assert_equal EMPTY_BOOTSTRAP, DummyBuilder.new.send(:render_client_bootstrap, [])
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
      valid.merge(function: ""),
      "package:a/a.dart"
    ].each do |hook|
      assert_raises(ArgumentError, hook.inspect) { builder.send(:render_client_bootstrap, [hook]) }
    end
  end

  def test_a_malformed_hook_fails_before_any_file_changes
    builder_class = Class.new(DummyBuilder) do
      def client_bootstrap_hook_providers
        [:bad_hooks]
      end

      def bad_hooks(_config, platform:, self_contained:)
        [HOOKS.first, { phase: :pre_run_app, import: "package:a/a.dart", function: "a()" }]
      end
    end

    with_client(self.class.marked_entrypoints) do |client_dir|
      before = snapshot(client_dir)

      assert_raises(ArgumentError) { builder_class.new.send(:write_client_bootstrap, client_dir, {}, platform: "web") }
      assert_equal before, snapshot(client_dir)
    end
  end

  private

  def with_client(entrypoints)
    Dir.mktmpdir do |client_dir|
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(client_dir, "lib", "main.dart"),
                 "import 'main.self.dart' as self_app;\n\nFuture<void> main() => self_app.main();\n")
      File.write(File.join(client_dir, "lib", "connection_probe.dart"), "// probe\n")
      entrypoints.each { |relative_path, source| File.binwrite(File.join(client_dir, relative_path), source) }
      yield client_dir
    end
  end

  # Every file under the client with its bytes and mtime.
  def snapshot(client_dir)
    Dir.glob("**/*", File::FNM_DOTMATCH, base: client_dir).sort.to_h do |relative_path|
      path = File.join(client_dir, relative_path)
      [relative_path, File.file?(path) ? [File.binread(path), File.mtime(path)] : :directory]
    end
  end

  def read_utf8(client_dir, relative_path)
    File.read(File.join(client_dir, relative_path), encoding: Encoding::UTF_8)
  end

  def contents(snapshot)
    snapshot.transform_values { |entry| entry == :directory ? entry : entry.first }
  end

  # What a build with hooks makes of an entrypoint that has the template's
  # block: the import after the last import directive, and a pointer in place
  # of the empty lists. Nothing else changes.
  def routed(source)
    source
      .sub("import 'package:ruflet_webview/ruflet_webview.dart' as ruflet_webview;\n",
           "\\0import 'ruflet_bootstrap.g.dart';\n")
      .sub("const rufletPreRunAppHooks = <RufletBootstrapHook>[];\n" \
           "const rufletPostFirstFrameHooks = <RufletBootstrapHook>[];\n",
           "// This build's hooks are in lib/ruflet_bootstrap.g.dart.\n")
      .tap { |result| raise "fixture did not change" if result == source }
  end
end

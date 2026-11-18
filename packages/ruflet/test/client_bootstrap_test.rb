# frozen_string_literal: true

require_relative "test_helper"
require_relative "compat/lib/tar"
require "fileutils"
require "json"
require "pathname"
require "yaml"

# Startup hooks the template entrypoints run before runApp and after the first
# frame (WP-00 R3). The entrypoints declare both lists empty themselves, so a
# build without hooks must leave the client exactly as the template and the
# rest of the build leave it; only a build that adds hooks writes
# lib/ruflet_bootstrap.g.dart and points the entrypoints at it. A
# lib/ruflet_bootstrap.g.dart the build did not write is never touched.
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

  # The H1 fixture template (ruflet-template e32c873, the template every
  # released gem ships against today), as tar entries.
  def self.template_entries
    @template_entries ||= begin
      archive = File.join(__dir__, "compat", "fixtures", "template", "ruflet_flutter_template.tar")
      File.open(archive, "rb") { |io| RufletCompat::Tar.read(io) }.freeze
    end
  end

  # Its entrypoints: no hook block, no import.
  def self.released_entrypoints
    @released_entrypoints ||= ENTRYPOINTS.to_h do |relative_path|
      entry = template_entries.find { |candidate| candidate.path == "ruflet_flutter_template/#{relative_path}" }
      [relative_path, entry.data.dup.force_encoding(Encoding::UTF_8).freeze]
    end.freeze
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

  # An entrypoint without the block that already imports the generated file,
  # for example one a developer pointed at it by hand, gets the hooks through
  # that import: nothing in it changes and there is nothing to warn about.
  def test_hooks_reach_an_entrypoint_that_imports_them_without_the_block
    imported = self.class.released_entrypoints.fetch("lib/main.server.dart")
                   .sub(LAST_IMPORT, "\\0import 'ruflet_bootstrap.g.dart';\n")
    entrypoints = self.class.marked_entrypoints.merge("lib/main.server.dart" => imported)

    with_client(entrypoints) do |client_dir|
      _out, err = capture_io do
        assert_equal File.join(client_dir, GENERATED),
                     HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "apk")
      end

      assert_empty err
      assert_equal imported, read_utf8(client_dir, "lib/main.server.dart")
      assert_equal routed(entrypoints.fetch("lib/main.self.dart")), read_utf8(client_dir, "lib/main.self.dart")
      assert_equal HOOKED_BOOTSTRAP, File.binread(File.join(client_dir, GENERATED))
    end
  end

  # Every build copies both entrypoints from the template first, so only a
  # client prepared without a template can lack one. The hooks then reach the
  # other, and the missing one is not created.
  def test_hooks_skip_a_missing_entrypoint
    entrypoints = self.class.marked_entrypoints.except("lib/main.self.dart")

    with_client(entrypoints) do |client_dir|
      _out, err = capture_io do
        assert_equal File.join(client_dir, GENERATED),
                     HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "apk")
      end

      assert_empty err
      refute File.exist?(File.join(client_dir, "lib/main.self.dart"))
      assert_equal routed(entrypoints.fetch("lib/main.server.dart")), read_utf8(client_dir, "lib/main.server.dart")
    end
  end

  # An export of the generated file does not put the hook lists in the
  # entrypoint's own scope, so the build still imports the file there.
  def test_an_entrypoint_that_only_exports_the_hooks_still_imports_them
    entrypoints = self.class.marked_entrypoints.transform_values do |source|
      source.sub(LAST_IMPORT, "\\0export 'ruflet_bootstrap.g.dart';\n")
    end

    with_client(entrypoints) do |client_dir|
      assert_equal File.join(client_dir, GENERATED),
                   HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      entrypoints.each do |relative_path, source|
        assert_equal routed(source), read_utf8(client_dir, relative_path), relative_path
      end
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

  # Without hooks, an entrypoint that imports the file does not make the build
  # create it: only a file an earlier build with hooks wrote is kept in step.
  def test_no_hooks_never_creates_the_file_an_entrypoint_imports
    entrypoints = self.class.marked_entrypoints.transform_values { |source| routed(source) }

    with_client(entrypoints) do |client_dir|
      before = snapshot(client_dir)

      _out, err = capture_io do
        assert_nil DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      end
      assert_equal before, snapshot(client_dir)
      assert_empty err
    end
  end

  # Review probe A: the developer's own lib/ruflet_bootstrap.g.dart, imported
  # from lib/, in a client dir they own.
  OWN_BOOTSTRAP = "// my own file\nconst mine = 1;\n"
  FOREIGN_WARNING = "warning: lib/ruflet_bootstrap.g.dart was not written by `ruflet build`, so it is " \
                    "left as it is and the 4 startup hooks this build adds will not run. Rename that file " \
                    "to let the build generate it.\n"

  def test_a_developers_own_bootstrap_file_is_never_overwritten
    with_client({ "lib/main.server.dart" => "import 'x.dart';\n" }) do |client_dir|
      File.write(File.join(client_dir, "lib", "mine.dart"), "import 'ruflet_bootstrap.g.dart';\n")
      File.write(File.join(client_dir, GENERATED), OWN_BOOTSTRAP)
      before = snapshot(client_dir)

      _out, err = capture_io do
        assert_nil DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      end
      assert_equal before, snapshot(client_dir)
      assert_equal OWN_BOOTSTRAP, File.binread(File.join(client_dir, GENERATED))
      assert_empty err, "nothing would have changed, so there is nothing to warn about"
    end
  end

  # With hooks the build would need the file, so it says why the hooks will
  # not run, and leaves the file and the entrypoints exactly as they are.
  def test_hooks_leave_a_developers_own_bootstrap_file_and_the_entrypoints_alone
    owners = {
      "the developer's own file" => ->(path) { File.write(path, OWN_BOOTSTRAP) },
      "another tool's generated file" => ->(path) { File.write(path, "// GENERATED CODE - DO NOT MODIFY BY HAND\n") },
      "the header alone, without the rest of the signature" =>
        ->(path) { File.write(path, "// GENERATED FILE. DO NOT EDIT.\nconst mine = 1;\n") },
      "a directory" => ->(path) { FileUtils.mkdir_p(path) }
    }
    owners.each do |label, plant|
      with_client(self.class.marked_entrypoints) do |client_dir|
        plant.call(File.join(client_dir, GENERATED))
        before = snapshot(client_dir)

        _out, err = capture_io do
          assert_nil HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web"), label
        end
        assert_equal before, snapshot(client_dir), label
        assert_equal FOREIGN_WARNING, err, label
      end
    end
  end

  # A symlink is not a file the build wrote, even when it points at one: the
  # write would land wherever the link points.
  def test_a_symlinked_bootstrap_file_is_never_written_through
    entrypoints = self.class.marked_entrypoints.transform_values { |source| routed(source) }

    with_client(entrypoints) do |client_dir|
      target = File.join(client_dir, "elsewhere.g.dart")
      File.binwrite(target, HOOKED_BOOTSTRAP)
      begin
        File.symlink(target, File.join(client_dir, GENERATED))
      rescue NotImplementedError, SystemCallError
        skip "symlinks are not available here"
      end
      before = snapshot(client_dir)

      assert_nil DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      _out, err = capture_io do
        assert_nil HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      end
      assert_equal before, snapshot(client_dir)
      assert_equal HOOKED_BOOTSTRAP, File.binread(target)
      assert_equal FOREIGN_WARNING, err
    end
  end

  # A symlink that points nowhere is not an absent file either: writing
  # through it would create the file it points at.
  def test_a_dangling_symlinked_bootstrap_file_is_never_written_through
    with_client(self.class.marked_entrypoints) do |client_dir|
      target = File.join(client_dir, "elsewhere.g.dart")
      link = File.join(client_dir, GENERATED)
      begin
        File.symlink(target, link)
      rescue NotImplementedError, SystemCallError
        skip "symlinks are not available here"
      end
      before = snapshot(client_dir)

      assert_nil DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      _out, err = capture_io do
        assert_nil HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      end
      assert_equal before, snapshot(client_dir)
      refute File.exist?(target), "the link's target must not be created"
      assert_equal target, File.readlink(link)
      assert_equal FOREIGN_WARNING, err
    end
  end

  # Review probe B: another package's file of the same name is not this
  # client's lib/ruflet_bootstrap.g.dart.
  def test_another_packages_ruflet_bootstrap_is_not_this_clients
    with_client({ "lib/main.server.dart" => "import 'package:other/ruflet_bootstrap.g.dart';\n" }) do |client_dir|
      File.write(File.join(client_dir, "pubspec.yaml"), "name: demo\n")
      before = snapshot(client_dir)

      assert_nil DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal before, snapshot(client_dir)
      refute File.exist?(File.join(client_dir, GENERATED))

      # A generated file only that import names is imported by nothing.
      File.binwrite(File.join(client_dir, GENERATED), HOOKED_BOOTSTRAP)
      assert_nil DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      refute File.exist?(File.join(client_dir, GENERATED))
    end
  end

  # Review probe cases 3 and 4. Without hooks, a generated file stays while
  # any directive under lib/ names it, in any form: an import, an export, a
  # part, or one alternative of a conditional import or export, the rule
  # ruflet-template's conformance test applies to the entrypoints. Removing
  # it would stop that file compiling.
  DIRECTIVES_NAMING_THE_BOOTSTRAP = {
    "lib/mine.dart" => [
      "export 'ruflet_bootstrap.g.dart';",
      "import 'stub.dart' if (dart.library.io) 'ruflet_bootstrap.g.dart';",
      "part 'ruflet_bootstrap.g.dart';",
      "export \"package:demo/ruflet_bootstrap.g.dart\" show rufletPreRunAppHooks;",
      "import 'stub.dart'\n    if (dart.library.js_interop) 'web.dart'\n    if (dart.library.io) './ruflet_bootstrap.g.dart';",
      "export 'stub.dart' if (dart.library.io) 'package:demo/ruflet_bootstrap.g.dart';",
      "  import\n    \"ruflet_bootstrap.g.dart\"\r\n    as hooks;"
    ],
    "lib/sub/mine.dart" => [
      "export '../ruflet_bootstrap.g.dart';",
      "import 'stub.dart' if (dart.library.io) '../ruflet_bootstrap.g.dart';"
    ]
  }.freeze
  # ... and nothing else that mentions the name.
  DIRECTIVES_NAMING_SOMETHING_ELSE = {
    "lib/mine.dart" => [
      "part of 'ruflet_bootstrap.g.dart';",
      "// export 'ruflet_bootstrap.g.dart';",
      "export 'package:other/ruflet_bootstrap.g.dart';",
      "import 'stub.dart' if (dart.library.io) 'sub/ruflet_bootstrap.g.dart';",
      "export '/ruflet_bootstrap.g.dart';",
      "export 'x:/../ruflet_bootstrap.g.dart';",
      "void f() {\n  imported = 'ruflet_bootstrap.g.dart';\n  parts = ['ruflet_bootstrap.g.dart'];\n}",
      "const s = 'export ruflet_bootstrap.g.dart';",
      "export 'ruflet_bootstrap.g.dart\";"
    ],
    "lib/sub/mine.dart" => [
      "export 'ruflet_bootstrap.g.dart';",
      "import 'stub.dart' if (dart.library.io) 'ruflet_bootstrap.g.dart';"
    ]
  }.freeze

  def test_recognises_every_directive_that_names_this_clients_generated_file
    builder = DummyBuilder.new

    DIRECTIVES_NAMING_THE_BOOTSTRAP.each do |importer, directives|
      directives.each do |directive|
        assert builder.send(:client_bootstrap_reference_in?, "#{directive}\n", importer, "demo"), "#{importer}: #{directive}"
      end
    end
    DIRECTIVES_NAMING_SOMETHING_ELSE.each do |importer, directives|
      directives.each do |directive|
        refute builder.send(:client_bootstrap_reference_in?, "#{directive}\n", importer, "demo"), "#{importer}: #{directive}"
      end
    end
  end

  def test_no_hooks_keeps_the_generated_file_while_any_directive_names_it
    {
      DIRECTIVES_NAMING_THE_BOOTSTRAP => true, DIRECTIVES_NAMING_SOMETHING_ELSE => false
    }.each do |table, kept|
      table.each do |importer, directives|
        directives.each do |directive|
          with_client(self.class.released_entrypoints) do |client_dir|
            File.write(File.join(client_dir, "pubspec.yaml"), "name: demo\n")
            FileUtils.mkdir_p(File.dirname(File.join(client_dir, importer)))
            File.write(File.join(client_dir, importer), "#{directive}\n")
            path = File.join(client_dir, GENERATED)
            File.binwrite(path, HOOKED_BOOTSTRAP)

            result = DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
            if kept
              assert_equal path, result, "#{importer}: #{directive}"
              assert_equal EMPTY_BOOTSTRAP, File.binread(path), "#{importer}: #{directive}"
            else
              assert_nil result, "#{importer}: #{directive}"
              refute File.exist?(path), "#{importer}: #{directive}"
            end
          end
        end
      end
    end
  end

  # The client's own package path names the client's file, in either quote
  # style; the package name is the one in the client's pubspec.yaml.
  def test_the_clients_own_package_import_names_its_bootstrap
    ["import 'package:demo/ruflet_bootstrap.g.dart';\n",
     "import \"package:demo/ruflet_bootstrap.g.dart\" as hooks;\n"].each do |import|
      with_client({ "lib/main.server.dart" => "import 'x.dart';\n#{import}" }) do |client_dir|
        File.write(File.join(client_dir, "pubspec.yaml"), "# The app.\nname: 'demo' # renamed by ruflet build\n")
        path = File.join(client_dir, GENERATED)
        File.binwrite(path, HOOKED_BOOTSTRAP)

        assert_equal path, DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web"), import
        assert_equal EMPTY_BOOTSTRAP, File.binread(path), import
      end
    end
  end

  # Detecting the import must not fail a build that works today, whatever a
  # developer keeps under lib/.
  def test_a_client_with_files_that_are_not_utf8_still_builds
    with_client(self.class.released_entrypoints) do |client_dir|
      File.binwrite(File.join(client_dir, "lib", "latin1.dart"), "// caf\xE9\nimport 'ruflet_bootstrap.g.dart';\n".b)
      FileUtils.mkdir_p(File.join(client_dir, "lib", "folder.dart"))
      path = File.join(client_dir, GENERATED)
      File.binwrite(path, HOOKED_BOOTSTRAP)

      assert_equal path, DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal EMPTY_BOOTSTRAP, File.binread(path)
    end
  end

  # Review probe case 5. With hooks, an entrypoint that is not valid UTF-8 is
  # routed like the others and keeps its other bytes as they are. The next
  # build with hooks finds its import, and a build without hooks keeps the
  # file it imports.
  def test_hooks_route_an_entrypoint_that_is_not_utf8
    server = self.class.marked_entrypoints.fetch("lib/main.server.dart")
    entrypoints = self.class.marked_entrypoints.merge("lib/main.server.dart" => latin1(server))

    with_client(entrypoints) do |client_dir|
      path = File.join(client_dir, GENERATED)
      _out, err = capture_io do
        assert_equal path, HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      end

      assert_empty err
      assert_equal HOOKED_BOOTSTRAP, File.binread(path)
      assert_equal latin1(routed(server)), File.binread(File.join(client_dir, "lib/main.server.dart"))
      assert_equal routed(entrypoints.fetch("lib/main.self.dart")), read_utf8(client_dir, "lib/main.self.dart")

      before = snapshot(client_dir)
      HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal contents(before), contents(snapshot(client_dir))

      # Only the Latin-1 entrypoint still imports the file.
      File.binwrite(File.join(client_dir, "lib/main.self.dart"), entrypoints.fetch("lib/main.self.dart"))
      assert_equal path, DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal EMPTY_BOOTSTRAP, File.binread(path)
    end
  end

  # Nor can a file or directory under lib/ that cannot be read, or a
  # lib/ruflet_bootstrap.g.dart that cannot be read (which is then treated as
  # the developer's own).
  def test_unreadable_files_cannot_fail_the_build
    with_client(self.class.marked_entrypoints) do |client_dir|
      # Both sort before the entrypoints, so the scan reaches them first.
      secret = File.join(client_dir, "lib", "a_secret.dart")
      File.write(secret, "import 'ruflet_bootstrap.g.dart';\n")
      sub = File.join(client_dir, "lib", "a_sub")
      FileUtils.mkdir_p(sub)
      File.write(File.join(sub, "inner.dart"), "import '../ruflet_bootstrap.g.dart';\n")

      unreadable(secret, sub) do
        assert_equal File.join(client_dir, GENERATED),
                     HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      end
      assert_equal HOOKED_BOOTSTRAP, File.binread(File.join(client_dir, GENERATED))
      self.class.marked_entrypoints.each do |relative_path, source|
        assert_equal routed(source), read_utf8(client_dir, relative_path), relative_path
      end

      # The next build without hooks, with the entrypoints still routed.
      unreadable(secret, sub) do
        assert_equal File.join(client_dir, GENERATED),
                     DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      end
      assert_equal EMPTY_BOOTSTRAP, File.binread(File.join(client_dir, GENERATED))
    end

    entrypoints = self.class.marked_entrypoints.transform_values { |source| routed(source) }
    with_client(entrypoints) do |client_dir|
      path = File.join(client_dir, GENERATED)
      File.binwrite(path, HOOKED_BOOTSTRAP)
      unreadable(path) do
        before = snapshot(client_dir)
        assert_nil DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
        _out, err = capture_io do
          assert_nil HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
        end
        assert_equal before, snapshot(client_dir)
        assert_equal FOREIGN_WARNING, err
      end
      assert_equal HOOKED_BOOTSTRAP, File.binread(path)
    end
  end

  # The import goes after the end of the last import directive, also when
  # that directive spans lines or ends in a comment.
  LAST_IMPORT = "import 'package:ruflet_webview/ruflet_webview.dart' as ruflet_webview;\n"

  def test_hooks_are_imported_after_a_last_import_that_spans_lines_or_ends_in_a_comment
    [
      "import 'package:ruflet_webview/ruflet_webview.dart'\n    as ruflet_webview;\n",
      "import 'package:ruflet_webview/ruflet_webview.dart'\n    show RufletWebviewExtension\n    hide Unused;\n",
      "import 'package:ruflet_webview/ruflet_webview.dart' as ruflet_webview; // the last extension\n",
      "import 'package:ruflet_webview/ruflet_webview.dart' // the last extension\n    as ruflet_webview;\n"
    ].each do |last_import|
      entrypoints = self.class.marked_entrypoints.transform_values do |source|
        source.sub(LAST_IMPORT, last_import).tap { |result| raise "fixture did not change" if result == source }
      end

      with_client(entrypoints) do |client_dir|
        assert_equal File.join(client_dir, GENERATED),
                     HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web"), last_import
        entrypoints.each do |relative_path, source|
          expected = routed(source.sub(last_import, LAST_IMPORT)).sub(LAST_IMPORT, last_import)
          assert_equal expected, read_utf8(client_dir, relative_path), "#{last_import.inspect}: #{relative_path}"
        end
      end
    end
  end

  # A CRLF entrypoint (for example one checked out with core.autocrlf) is
  # found by its markers and stays CRLF; the generated file stays LF.
  def test_a_crlf_entrypoint_is_routed_and_stays_crlf
    entrypoints = self.class.marked_entrypoints.transform_values { |source| source.gsub("\n", "\r\n") }

    with_client(entrypoints) do |client_dir|
      path = File.join(client_dir, GENERATED)
      assert_equal path, HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal HOOKED_BOOTSTRAP, File.binread(path)
      routed_entrypoints = self.class.marked_entrypoints.to_h do |relative_path, source|
        [relative_path, routed(source).gsub("\n", "\r\n")]
      end
      routed_entrypoints.each do |relative_path, source|
        assert_equal source, File.binread(File.join(client_dir, relative_path)).force_encoding(Encoding::UTF_8), relative_path
      end

      # A second build with hooks finds the import and changes nothing, and a
      # build without hooks keeps the still-imported file in step.
      before = snapshot(client_dir)
      HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal contents(before), contents(snapshot(client_dir))
      assert_equal path, DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web")
      assert_equal EMPTY_BOOTSTRAP, File.binread(path)
    end
  end

  # RUFLET_CLIENT_DIR and ./ruflet_client can sit under any directory name.
  # Glob characters in it must not hide the entrypoints that import the file:
  # the hooks would then be routed to a file that is never written.
  GLOB_CHARACTER_DIRS = ["my app [v2]", "proj{1}", "a,b{c,d}"].freeze

  def test_hooks_reach_a_client_dir_whose_path_has_glob_characters
    GLOB_CHARACTER_DIRS.each do |name|
      with_client(self.class.marked_entrypoints, name: name) do |client_dir|
        assert_equal File.join(client_dir, GENERATED),
                     HookedBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web"), name
        assert_equal HOOKED_BOOTSTRAP, File.binread(File.join(client_dir, GENERATED)), name
        self.class.marked_entrypoints.each do |relative_path, source|
          assert_equal routed(source), read_utf8(client_dir, relative_path), "#{name}: #{relative_path}"
        end
      end
    end
  end

  # ... and without hooks, a generated file something still imports there must
  # be kept, not taken for a leftover and deleted.
  def test_an_imported_bootstrap_is_kept_in_a_client_dir_whose_path_has_glob_characters
    entrypoints = self.class.marked_entrypoints.transform_values { |source| routed(source) }

    GLOB_CHARACTER_DIRS.each do |name|
      with_client(entrypoints, name: name) do |client_dir|
        path = File.join(client_dir, GENERATED)
        File.binwrite(path, HOOKED_BOOTSTRAP)

        assert_equal path, DummyBuilder.new.send(:write_client_bootstrap, client_dir, {}, platform: "web"), name
        assert_equal EMPTY_BOOTSTRAP, File.binread(path), name
      end
    end
  end

  # Only an import that resolves to this client's lib/ruflet_bootstrap.g.dart
  # counts: relative to the importing file, or through the client's own
  # package name (here "demo").
  def test_recognises_imports_of_this_clients_generated_file_only
    builder = DummyBuilder.new
    imports = {
      "lib/main.server.dart" => [
        "import 'ruflet_bootstrap.g.dart';", "import \"ruflet_bootstrap.g.dart\";",
        "import './ruflet_bootstrap.g.dart';", "  import 'ruflet_bootstrap.g.dart' as hooks;",
        "import 'package:demo/ruflet_bootstrap.g.dart';", "import \"package:demo/ruflet_bootstrap.g.dart\" as hooks;",
        "import '../lib/ruflet_bootstrap.g.dart';", "import\n    'ruflet_bootstrap.g.dart';",
        "import 'ruflet_bootstrap.g.dart'\r\n    show rufletPreRunAppHooks;"
      ],
      "lib/sub/deeper.dart" => ["import '../ruflet_bootstrap.g.dart';", "import 'package:demo/ruflet_bootstrap.g.dart';"]
    }
    others = {
      "lib/main.server.dart" => [
        "import 'package:other/ruflet_bootstrap.g.dart';", "import \"package:other/ruflet_bootstrap.g.dart\";",
        "import 'package:ruflet_client/ruflet_bootstrap.g.dart';", "import 'package:demo/sub/ruflet_bootstrap.g.dart';",
        "import 'package:demox/ruflet_bootstrap.g.dart';", "import 'sub/ruflet_bootstrap.g.dart';",
        "import 'my_ruflet_bootstrap.g.dart';", "import 'ruflet_bootstrap.g.dart.dart';",
        "import '../ruflet_bootstrap.g.dart';", "import '../../lib/ruflet_bootstrap.g.dart';",
        "import '/lib/ruflet_bootstrap.g.dart';", "import 'file:///lib/ruflet_bootstrap.g.dart';",
        "import 'dart:ruflet_bootstrap.g.dart';", "// import 'ruflet_bootstrap.g.dart';",
        "export 'ruflet_bootstrap.g.dart';", "part 'ruflet_bootstrap.g.dart';",
        "import 'ruflet_bootstrap.g.dart\";", "const s = 'import ruflet_bootstrap.g.dart';",
        "import '/ruflet_bootstrap.g.dart';", "import 'x:/../ruflet_bootstrap.g.dart';",
        "import 'stub.dart' if (dart.library.io) 'ruflet_bootstrap.g.dart';"
      ],
      "lib/sub/deeper.dart" => ["import 'ruflet_bootstrap.g.dart';", "import '../../ruflet_bootstrap.g.dart';"]
    }

    imports.each do |importer, lines|
      lines.each do |line|
        assert builder.send(:client_bootstrap_import_in?, "#{line}\n", importer, "demo"), "#{importer}: #{line}"
      end
    end
    others.each do |importer, lines|
      lines.each do |line|
        refute builder.send(:client_bootstrap_import_in?, "#{line}\n", importer, "demo"), "#{importer}: #{line}"
      end
    end
    # Without a package name, no package: import is the client's.
    refute builder.send(:client_bootstrap_import_in?, "import 'package:demo/ruflet_bootstrap.g.dart';\n",
                        "lib/main.server.dart", nil)
  end

  def test_reads_the_package_name_from_the_clients_pubspec
    builder = DummyBuilder.new
    {
      "name: demo\n" => "demo",
      "# The app.\nname: 'demo_app' # renamed\r\nversion: 1.0.0\n" => "demo_app",
      "name: \"demo\"\n" => "demo",
      "description: x\n  name: nested\n" => nil,
      "name: 'demo\"\n" => nil,
      "\xFF\nname: demo\n".b => "demo"
    }.each do |pubspec, name|
      Dir.mktmpdir do |client_dir|
        File.binwrite(File.join(client_dir, "pubspec.yaml"), pubspec)
        actual = builder.send(:client_package_name, client_dir)
        name ? assert_equal(name, actual, pubspec.inspect) : assert_nil(actual, pubspec.inspect)
      end
    end
    Dir.mktmpdir { |client_dir| assert_nil builder.send(:client_package_name, client_dir) }
    Dir.mktmpdir do |client_dir|
      pubspec = File.join(client_dir, "pubspec.yaml")
      File.write(pubspec, "name: demo\n")
      unreadable(pubspec) { assert_nil builder.send(:client_package_name, client_dir) }
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

  # The seam inside the build.
  #
  # prepare_flutter_client is where every `ruflet build` target readies the
  # Flutter client. The tests below run it for real against the H1 fixture
  # template plus the marked block (what ruflet-template#3 ships), with only
  # the flutter commands faked. They pin what no unit test above and no H1
  # golden can see while no build feature registers a provider: that the build
  # calls the seam at all, hands it this build's config, platform and
  # self_contained, and calls it only once the extension selection is applied
  # and verified, before Flutter resolves the client.

  # Runs prepare_flutter_client and records, in order, the steps around the
  # seam: extension selection, its verification, the hook provider (with what
  # it was given and the entrypoints it saw) and every external command.
  class RecordingBuilder < DummyBuilder
    attr_reader :events

    def initialize(client_dir, hooks: nil, fail_extension_validation: false)
      super()
      @client_dir = client_dir
      @hooks = hooks
      @fail_extension_validation = fail_extension_validation
      @events = []
    end

    # nil: the providers the gem itself registers (none yet).
    def client_bootstrap_hook_providers
      @hooks ? [:recorded_hooks] : super
    end

    def recorded_hooks(config, platform:, self_contained:)
      entrypoints = ENTRYPOINTS.to_h do |relative_path|
        [relative_path, File.binread(File.join(@client_dir, relative_path)).force_encoding(Encoding::UTF_8)]
      end
      @events << [:hooks, { config: config, platform: platform, self_contained: self_contained, entrypoints: entrypoints }]
      @hooks
    end

    def apply_service_extension_config(*args, **kwargs)
      @events << [:apply_service_extension_config]
      super
    end

    def validate_flutter_extension_selection(client_dir)
      @events << [:validate_flutter_extension_selection]
      @fail_extension_validation ? false : super
    end

    # Every flutter/dart/pod command the build runs. `flutter pub get` writes
    # the package config the build then verifies, as the H1 harness's does.
    def system(_env, *argv, chdir: nil, **_options)
      @events << [:command, argv.map(&:to_s).join(" ")]
      emulate_pub_get(chdir) if argv.map(&:to_s).drop(1).first(2) == %w[pub get]
      true
    end

    def event_index(name)
      @events.index { |event| event.first == name || event == [:command, name] }
    end

    def hook_calls
      @events.select { |event| event.first == :hooks }.map(&:last)
    end

    private

    def emulate_pub_get(client_dir)
      packages = {}
      queue = [client_dir]
      until queue.empty?
        root = queue.shift
        manifest = YAML.safe_load(File.read(File.join(root, "pubspec.yaml")), aliases: true) || {}
        (manifest["dependencies"] || {}).each do |name, dependency|
          next unless dependency.is_a?(Hash) && dependency["path"] && !packages.key?(name)

          packages[name] = File.expand_path(dependency["path"].to_s, root)
          queue << packages[name] if File.file?(File.join(packages[name], "pubspec.yaml"))
        end
      end
      dart_tool = File.join(client_dir, ".dart_tool")
      FileUtils.mkdir_p(dart_tool)
      entries = packages.sort.map do |name, root|
        { "name" => name, "rootUri" => Pathname.new(root).relative_path_from(Pathname.new(dart_tool)).to_s,
          "packageUri" => "lib/" }
      end
      File.write(File.join(dart_tool, "package_config.json"),
                 JSON.generate("configVersion" => 2, "packages" => entries))
    end
  end

  BUILD_CONFIG = {
    "app" => { "app_name" => "Demo", "package_name" => "demo", "organization" => "com.example" },
    "extensions" => ["spinkit"]
  }.freeze

  # A server-driven web build and a self-contained iOS build: every
  # combination of the two arguments the build passes on is seen.
  BUILDS = [["web", false], ["ios", true]].freeze

  def test_prepare_flutter_client_runs_the_hooks_with_this_builds_config_platform_and_self_contained
    with_template do |template_root|
      BUILDS.each do |platform, self_contained|
        label = "#{platform} self_contained=#{self_contained}"
        plain = prepared_client(template_root, platform: platform, self_contained: self_contained)
        hooked = prepared_client(template_root, platform: platform, self_contained: self_contained, hooks: HOOKS)

        assert_equal true, hooked[:result], label
        assert_equal 1, hooked[:builder].hook_calls.size, label
        call = hooked[:builder].hook_calls.first
        assert_same hooked[:config], call[:config], label
        assert_equal platform, call[:platform], label
        assert_equal self_contained, call[:self_contained], label

        # The build wrote the hooks and pointed both entrypoints at them.
        # Nothing else in the client differs from the same build without hooks.
        assert_equal HOOKED_BOOTSTRAP, hooked[:files].fetch(GENERATED), label
        refute plain[:files].key?(GENERATED), label
        assert_equal (ENTRYPOINTS + [GENERATED]).sort,
                     (plain[:files].keys | hooked[:files].keys).reject { |path| plain[:files][path] == hooked[:files][path] }.sort,
                     label
        ENTRYPOINTS.each do |relative_path|
          assert_routed plain[:files].fetch(relative_path), hooked[:files].fetch(relative_path), "#{label}: #{relative_path}"
        end
      end
    end
  end

  # A hook may rely on the extensions this build selected: by the time the
  # provider runs, the entrypoints are the ones the build ships without hooks,
  # pruned to the selection and verified.
  def test_prepare_flutter_client_runs_the_hooks_after_the_extension_selection_is_verified
    with_template do |template_root|
      BUILDS.each do |platform, self_contained|
        label = "#{platform} self_contained=#{self_contained}"
        plain = prepared_client(template_root, platform: platform, self_contained: self_contained)
        builder = prepared_client(template_root, platform: platform, self_contained: self_contained, hooks: HOOKS)[:builder]

        selected = builder.event_index(:apply_service_extension_config)
        verified = builder.event_index(:validate_flutter_extension_selection)
        hooks = builder.event_index(:hooks)
        pub_get = builder.event_index("flutter pub get")
        assert selected && verified && hooks && pub_get, "#{label}: #{builder.events.map(&:first).inspect}"
        assert_operator selected, :<, verified, label
        assert_operator verified, :<, hooks, "#{label}: the hooks must run after the extension selection is verified"
        assert_operator hooks, :<, pub_get, "#{label}: the hooks must be written before Flutter resolves the client"

        seen = builder.hook_calls.first[:entrypoints]
        ENTRYPOINTS.each do |relative_path|
          assert_equal plain[:files].fetch(relative_path), seen.fetch(relative_path), "#{label}: #{relative_path}"
          assert_includes seen.fetch(relative_path), "package:ruflet_spinkit/", "#{label}: #{relative_path}"
          refute_includes seen.fetch(relative_path), "package:ruflet_webview/", "#{label}: #{relative_path}"
        end
      end
    end
  end

  # A build that stops at the extension check runs no hook and leaves no
  # generated file or routed entrypoint behind.
  def test_prepare_flutter_client_runs_no_hook_when_the_extension_check_fails
    with_template do |template_root|
      BUILDS.each do |platform, self_contained|
        label = "#{platform} self_contained=#{self_contained}"
        failed = prepared_client(template_root, platform: platform, self_contained: self_contained,
                                                hooks: HOOKS, fail_extension_validation: true)

        assert_equal false, failed[:result], label
        assert_empty failed[:builder].hook_calls, label
        refute failed[:files].key?(GENERATED), label
        ENTRYPOINTS.each do |relative_path|
          source = failed[:files].fetch(relative_path)
          assert_includes source, TEMPLATE_HOOK_BLOCK, "#{label}: #{relative_path}"
          refute_includes source, Ruflet::CLI::ClientBootstrap::CLIENT_BOOTSTRAP_IMPORT, "#{label}: #{relative_path}"
        end
      end
    end
  end

  # Without a provider (every build today) the full preparation writes no
  # generated file, warns about nothing and leaves the marked block in place.
  def test_prepare_flutter_client_without_hooks_leaves_the_template_entrypoints_unrouted
    with_template do |template_root|
      BUILDS.each do |platform, self_contained|
        label = "#{platform} self_contained=#{self_contained}"
        plain = prepared_client(template_root, platform: platform, self_contained: self_contained)

        assert_equal true, plain[:result], label
        refute plain[:files].key?(GENERATED), label
        refute_match(/RUFLET_BOOTSTRAP|startup hook/, plain[:stderr], label)
        ENTRYPOINTS.each do |relative_path|
          source = plain[:files].fetch(relative_path)
          assert_includes source, TEMPLATE_HOOK_BLOCK, "#{label}: #{relative_path}"
          refute_includes source, Ruflet::CLI::ClientBootstrap::CLIENT_BOOTSTRAP_IMPORT, "#{label}: #{relative_path}"
        end
      end
    end
  end

  private

  # The H1 fixture template with the marked block in both entrypoints, as
  # ruflet-template#3 ships them, in a temp dir that also holds the clients.
  def with_template
    Dir.mktmpdir do |dir|
      template_root = File.join(dir, "template")
      self.class.template_entries.each do |entry|
        path = File.join(template_root, entry.path.delete_prefix("ruflet_flutter_template/"))
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, entry.data)
        File.chmod(entry.mode, path)
      end
      self.class.marked_entrypoints.each do |relative_path, source|
        File.binwrite(File.join(template_root, relative_path), source)
      end
      yield template_root
    end
  end

  # A fresh client copied from the template, as build/client is, after a real
  # prepare_flutter_client. Returns the builder, its result, the config it was
  # given, stderr and every file in the client.
  def prepared_client(template_root, platform:, self_contained:, hooks: nil, fail_extension_validation: false)
    @prepared_clients = (@prepared_clients || 0) + 1
    client_dir = File.join(File.dirname(template_root), "client-#{@prepared_clients}")
    FileUtils.cp_r(template_root, client_dir, preserve: true)
    builder = RecordingBuilder.new(client_dir, hooks: hooks, fail_extension_validation: fail_extension_validation)
    config = Marshal.load(Marshal.dump(BUILD_CONFIG))
    result = nil
    _out, err = capture_io do
      Ruflet::CLI.stub(:resolve_ruflet_client_template_root, template_root) do
        result = builder.send(
          :prepare_flutter_client, client_dir,
          platform: platform, tools: { env: {}, flutter: "flutter", dart: "dart" },
          config: config, self_contained: self_contained, verbose: false
        )
      end
    end
    files = Dir.glob("**/*", File::FNM_DOTMATCH, base: client_dir).sort.filter_map do |relative_path|
      path = File.join(client_dir, relative_path)
      [relative_path, File.binread(path).force_encoding(Encoding::UTF_8)] if File.file?(path)
    end.to_h
    { builder: builder, result: result, config: config, stderr: err, files: files }
  end

  # `hooked` is `plain` with the generated file imported right after its last
  # import directive and the marked block's lists replaced by the pointer.
  def assert_routed(plain, hooked, message)
    import = "#{Ruflet::CLI::ClientBootstrap::CLIENT_BOOTSTRAP_IMPORT}\n"
    pointer = "#{Ruflet::CLI::ClientBootstrap::CLIENT_BOOTSTRAP_BLOCK_POINTER}\n"
    lists = "const rufletPreRunAppHooks = <RufletBootstrapHook>[];\n" \
            "const rufletPostFirstFrameHooks = <RufletBootstrapHook>[];\n"
    assert_equal 1, hooked.scan(import).size, message
    assert_equal 1, hooked.scan(pointer).size, message
    assert_equal plain, hooked.sub(import, "").sub(pointer, lists), message

    lines = hooked.lines
    at = lines.index(import)
    assert_operator at, :>, 0, message
    assert lines[at - 1].rstrip.end_with?(";"), "#{message}: the import must follow a complete directive"
    assert lines[0...at].any? { |line| line.start_with?("import ") }, message
    refute lines[(at + 1)..].any? { |line| line.start_with?("import ") }, "#{message}: the import must follow the last import"
  end

  def with_client(entrypoints, name: nil)
    Dir.mktmpdir do |dir|
      client_dir = name ? File.join(dir, name, "client") : dir
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
      [relative_path, File.file?(path) ? [file_bytes(path), File.lstat(path).mtime] : :directory]
    end
  end

  def file_bytes(path)
    File.binread(path)
  rescue SystemCallError
    :unreadable
  end

  # Makes `paths` unreadable while the block runs: chmod 000, and where that
  # does not stop reads (root, Windows), File.binread raising for them as it
  # would for an unreadable file.
  def unreadable(*paths, &block)
    modes = paths.to_h { |path| [path, File.stat(path).mode] }
    paths.each { |path| File.chmod(0o000, path) }
    return yield if paths.none? { |path| File.readable?(path) }

    blocked = paths.map { |path| File.expand_path(path) }
    binread = File.method(:binread)
    File.stub(:binread, lambda { |path, *args|
      raise Errno::EACCES, path if blocked.include?(File.expand_path(path))

      binread.call(path, *args)
    }, &block)
  ensure
    modes&.each { |path, mode| File.chmod(mode, path) }
  end

  # `source` as bytes with Latin-1 text, which is not valid UTF-8, in a
  # comment at the top and in one right after the hook block.
  def latin1(source)
    "// caf\xE9 cr\xE8me\n".b +
      source.b.sub("// --RUFLET_BOOTSTRAP_HOOKS_END--\n", "\\0// \xE0 la carte\n".b)
            .tap { |result| raise "fixture did not change" if result == source.b }
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

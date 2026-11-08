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

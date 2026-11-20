# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"

# CRIT-04(b): build, run and doctor read the template's
# tool/conformance/ruflet_control_surface.json and warn when the app uses a
# control, service or bundled extension the template lacks, naming the first
# template revision that has it. --strict makes that an error. A template
# without the file (older templates) is not checked.
class RufletTemplateSurfaceTest < Minitest::Test
  Surface = Ruflet::CLI::TemplateSurface
  Check = Ruflet::CLI::TemplateSurfaceCheck
  FORM_REVISION = "e793ccef345b6e4777e9b1acf40dd7f9895cd86e"
  LOCAL_AUTH_REVISION = "cdbc2aaf6036e67e7216ce7eaf2a89c1178554a6"
  BASELINE_REVISION = "19ac4c9eb87d9ea1ce1083c2cafc74354cbb56d5"
  # Rendered before BASELINE_REVISION, but listed in no surface until it.
  UNLISTED_BEFORE_BASELINE = %w[
    Lottie Rive CodeEditor ColorPicker BlockPicker Map Marker TileLayer BannerAd InterstitialAd NativeAd
    BarChartRod PieChartSection LineChartData DataTable2 DataRow2 Picker TimerPicker ActionSheet ContextMenuAction
  ].freeze

  FORM_APP = <<~RUBY
    require "ruflet"

    Ruflet.run do |page|
      page.add(form(controls: [text_field(label: "Email")]))
    end
  RUBY

  # A template whose surface renders wire_types, with these bundled packages.
  def write_template(root, wire_types:, packages: [])
    surface = File.join(root, "tool", "conformance", "ruflet_control_surface.json")
    FileUtils.mkdir_p(File.dirname(surface))
    entries = wire_types.map { |wire| { "dsl_name" => wire.downcase, "family" => "visual", "wire_type" => wire, "keywords" => [] } }
    File.write(surface, JSON.generate("contract_version" => 1, "entries" => entries))
    packages.each { |package| FileUtils.mkdir_p(File.join(root, "ruflet_packages", package)) }
    root
  end

  # The template main had before the CRIT-04a sync: everything up to the
  # wire types and packages that arrive with it.
  def old_template(root)
    write_template(
      root,
      wire_types: Surface::BASELINE_WIRE_TYPES + Surface::WIRE_TYPES.reject { |_wire, (_f, _n, revision)| revision == FORM_REVISION }.keys,
      packages: Surface::EXTENSION_PACKAGES.keys - %w[ruflet_local_auth]
    )
  end

  def new_template(root)
    write_template(root, wire_types: Surface::BASELINE_WIRE_TYPES + Surface::WIRE_TYPES.keys, packages: Surface::EXTENSION_PACKAGES.keys)
  end

  def project(files)
    Dir.mktmpdir do |dir|
      files.each do |path, content|
        full = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, content)
      end
      yield dir
    end
  end

  def calls(source, name = "form")
    project("main.rb" => source) { |dir| Surface.app_calls(dir, [name]) }
  end

  # --- the table ---------------------------------------------------------------

  # In a child process: the tool loads ruflet_core, which this process must not.
  def test_the_table_is_current_for_this_checkout
    tool = File.expand_path("../../../tools/template_surface_revisions.rb", __dir__)
    skip "not running from a source checkout" unless File.file?(tool) && Dir.exist?(File.expand_path("../../ruflet_core/lib", __dir__))

    out, err, status = Open3.capture3(RbConfig.ruby, tool, "--check", "--offline")
    assert status.success?,
           "a control, service or extension changed: run ruby tools/template_surface_revisions.rb " \
           "(--offline without a ruflet-template clone)\n#{out}#{err}"
  end

  def test_the_table_names_the_revisions_form_and_local_auth_arrive_in
    assert_equal ["visual", %w[form], FORM_REVISION], Surface::WIRE_TYPES.fetch("Form")
    assert_equal FORM_REVISION, Surface::WIRE_TYPES.fetch("NestedScrollView").last
    assert_equal FORM_REVISION, Surface::WIRE_TYPES.fetch("FadeTransition").last
    assert_equal ["service", %w[local_authentication localauthentication], FORM_REVISION], Surface::WIRE_TYPES.fetch("LocalAuthentication")
    assert_equal LOCAL_AUTH_REVISION, Surface::EXTENSION_PACKAGES.fetch("ruflet_local_auth")
    refute Surface::WIRE_TYPES.key?("Text"), "baseline wire types are not listed"
    assert_includes Surface::BASELINE_WIRE_TYPES, "Text"
  end

  # Surfaces from 0c02f475 up to 19ac4c9e leave out wire types their Dart
  # already renders, so the table dates wire types from 19ac4c9e: those count
  # as rendered by every checked template.
  def test_wire_types_are_dated_from_the_first_surface_that_matches_its_renderers
    assert_equal BASELINE_REVISION, Surface::BASELINE_REVISION
    UNLISTED_BEFORE_BASELINE.each do |wire|
      assert_includes Surface::BASELINE_WIRE_TYPES, wire
      refute Surface::WIRE_TYPES.key?(wire), wire
    end
    assert_equal [FORM_REVISION], Surface::WIRE_TYPES.values.map(&:last).uniq
  end

  def test_controls_an_older_surface_leaves_out_are_not_reported
    app = "lottie(src: \"a.json\")\ncupertino_picker(controls: [])\ncode_editor(value: \"\")\nrive(src: \"b.riv\")\n"
    project("main.rb" => app) do |dir|
      template = write_template(File.join(dir, "template"), wire_types: Surface::BASELINE_WIRE_TYPES - UNLISTED_BEFORE_BASELINE)
      assert_empty Surface.problems(template, project_root: dir)

      File.write(File.join(dir, "main.rb"), "#{app}form\n")
      assert_equal [["form", FORM_REVISION]], Surface.problems(template, project_root: dir).map { |p| [p.name, p.revision] }
    end
  end

  # --- reading a template -----------------------------------------------------------

  def test_a_template_without_a_surface_file_is_not_checked
    project("main.rb" => FORM_APP) do |dir|
      template = File.join(dir, "template")
      FileUtils.mkdir_p(template)

      assert_nil Surface.load(template)
      assert_empty Surface.problems(template, project_root: dir)
      assert_empty Surface.problems(nil, project_root: dir)
    end
  end

  def test_an_unreadable_surface_file_is_not_checked
    project("main.rb" => FORM_APP) do |dir|
      surface = File.join(dir, "template", "tool", "conformance", "ruflet_control_surface.json")
      FileUtils.mkdir_p(File.dirname(surface))
      ["{", "[]", "{\"entries\": 3}"].each do |content|
        File.write(surface, content)
        assert_nil Surface.load(File.join(dir, "template")), content
        assert_empty Surface.problems(File.join(dir, "template"), project_root: dir), content
      end
    end
  end

  def test_load_reads_wire_types_and_bundled_packages
    Dir.mktmpdir do |dir|
      write_template(dir, wire_types: %w[Text Text Form], packages: %w[ruflet_charts])
      File.write(File.join(dir, "ruflet_packages", "README.md"), "not a package")

      assert_equal({ wire_types: %w[Text Form], packages: %w[ruflet_charts] }, Surface.load(dir))
    end
  end

  # --- what is reported -----------------------------------------------------------

  def test_form_against_the_old_surface_names_the_minimum_revision
    project("main.rb" => FORM_APP) do |dir|
      template = old_template(File.join(dir, "template"))
      problems = Surface.problems(template, project_root: dir)

      assert_equal 1, problems.length
      problem = problems.first
      assert_equal [:control, "form", "Form", FORM_REVISION, "main.rb:4"],
                   [problem.kind, problem.name, problem.provides, problem.revision, problem.location]
    end
  end

  def test_form_against_the_new_surface_reports_nothing
    project("main.rb" => FORM_APP, "services.yaml" => "services:\n  - biometrics\n") do |dir|
      template = new_template(File.join(dir, "template"))

      assert_empty Surface.problems(template, project_root: dir, extensions: { "local_auth" => "ruflet_local_auth" })
    end
  end

  def test_services_and_extensions_are_reported
    app = "Ruflet.run do |page|\n  page.services << local_authentication\nend\n"
    project("main.rb" => app) do |dir|
      template = old_template(File.join(dir, "template"))
      problems = Surface.problems(template, project_root: dir, extensions: { "local_auth" => "ruflet_local_auth", "charts" => "ruflet_charts", "my_pkg" => "my_pkg" })

      assert_equal [[:service, "local_authentication", "LocalAuthentication", FORM_REVISION],
                    [:extension, "local_auth", "ruflet_local_auth", LOCAL_AUTH_REVISION]],
                   problems.map { |p| [p.kind, p.name, p.provides, p.revision] }
    end
  end

  def test_a_wire_type_no_template_has_yet_says_so
    project("main.rb" => "future_thing(key: 1)\n") do |dir|
      template = new_template(File.join(dir, "template"))
      with_wire_type("FutureThing", ["visual", %w[future_thing], nil]) do
        problem = Surface.problems(template, project_root: dir).first

        assert_equal ["future_thing", nil], [problem.name, problem.revision]
        assert_includes Surface.report([problem], template_root: template).join("\n"), "no ruflet-template revision has it yet"
      end
    end
  end

  # --- how usage is found -----------------------------------------------------------

  def test_calls_in_every_form_count
    {
      "form(controls: [])" => "main.rb:1",
      "form controls: []" => "main.rb:1",
      "form do\nend" => "main.rb:1",
      "form { }" => "main.rb:1",
      "column(controls: [\n  text(\"a\"),\n  form\n])" => "main.rb:3",
      "x = 1\npage.add(form(key: \"f\"))" => "main.rb:2"
    }.each do |source, location|
      assert_equal({ "form" => location }, calls(source), source)
    end
  end

  def test_words_that_are_not_calls_do_not_count
    [
      "# form(controls: [])",
      "text(\"form\")",
      "x = :form",
      "form = 1\nputs form",
      "page.form(controls: [])",
      "form_with(url: \"/\")",
      "my_form(1)",
      "{ form: 1 }",
      "def form; end\nform(controls: [])",
      "def self.form; end\nform"
    ].each do |source|
      assert_empty calls(source), source
    end
  end

  # Names the app defines without `def` are its own methods.
  def test_names_the_app_defines_do_not_count
    [
      "attr_reader :form",
      "attr_accessor :x, :form",
      "attr :form",
      "attr_reader \"form\"",
      "attr_reader(*%i[x form])",
      "let(:form) { 1 }",
      "let!(:form) { 1 }",
      "subject(:form) { 1 }",
      "define_method(:form) { 1 }",
      "define_method :form do\nend",
      "alias_method :form, :x",
      "alias form x",
      "Struct.new(:x, :form)",
      "::Struct.new :form do\nend",
      "Data.define(:form)",
      "delegate :x, :form, to: :y",
      "def_delegator :@y, :form",
      "def_delegators :@y, :x, :form",
      "belongs_to :form",
      "has_one :form"
    ].each do |definition|
      assert_empty calls("#{definition}\nform(controls: [])\n"), definition
    end
  end

  def test_names_a_definer_does_not_define_still_count
    [
      "alias_method :x, :form",
      "alias x form",
      "let(:x) { form }",
      "delegate :x, to: :form",
      "def_delegators :form, :x",
      "attr_writer :form",
      "has_many :form"
    ].each do |source|
      assert_equal ["form"], calls("#{source}\nform(controls: [])\n").keys, source
    end
  end

  def test_the_first_call_is_named
    project("main.rb" => "text(\"a\")\nform\n", "lib/b.rb" => "form\n", "lib/a.rb" => "\n\nform\n") do |dir|
      assert_equal({ "form" => "lib/a.rb:3" }, Surface.app_calls(dir, ["form"]))
    end
  end

  def test_build_output_dependencies_and_dot_directories_are_not_read
    files = { "main.rb" => "text(\"a\")\n" }
    %w[build vendor node_modules tmp log coverage spec test lib/test .git .bundle].each { |dir| files["#{dir}/x.rb"] = "form\n" }
    project(files) do |dir|
      assert_empty Surface.app_calls(dir, ["form"])
    end
  end

  def test_a_directory_that_is_not_a_ruflet_project_is_not_read
    project("script.rb" => "form\n") do |dir|
      assert_empty Surface.ruby_files(dir)
      assert_empty Surface.app_calls(dir, ["form"])
    end
  end

  def test_a_rails_app_is_read_from_app_views_ruflet
    project(
      "config/application.rb" => "form\n",
      "app/models/user.rb" => "form\n",
      "app/views/ruflet/main.rb" => "text(\"a\")\n",
      "app/views/ruflet/screens/signup.rb" => "form(controls: [])\n"
    ) do |dir|
      assert_equal({ "form" => "app/views/ruflet/screens/signup.rb:1" }, Surface.app_calls(dir, ["form"]))
    end
  end

  def test_an_explicit_script_outside_the_project_is_read
    project("main.rb" => "text(\"a\")\n") do |dir|
      Dir.mktmpdir do |other|
        script = File.join(other, "admin.rb")
        File.write(script, "form\n")

        assert_equal({ "form" => "#{File.expand_path(script)}:1" }, Surface.app_calls(dir, ["form"], files: [script]))
      end
    end
  end

  def test_unparseable_and_binary_files_are_skipped
    project("main.rb" => "form(\n", "lib/blob.rb" => "\xFF\xFEform".b) do |dir|
      assert_empty Surface.app_calls(dir, ["form"])
    end
  end

  def test_no_app_file_is_read_when_the_template_has_everything
    project("main.rb" => FORM_APP) do |dir|
      template = new_template(File.join(dir, "template"))
      Surface.stub(:ruby_files, ->(*) { flunk("no app file is read") }) do
        assert_empty Surface.problems(template, project_root: dir)
      end
    end
  end

  # --- what is printed ----------------------------------------------------------------

  def test_the_warning_and_the_strict_error
    problems = [
      Surface::Problem.new(kind: :control, name: "form", provides: "Form", revision: FORM_REVISION, location: "main.rb:4"),
      Surface::Problem.new(kind: :extension, name: "local_auth", provides: "ruflet_local_auth", revision: LOCAL_AUTH_REVISION)
    ]

    assert_equal <<~TEXT, "#{Surface.report(problems, template_root: '/t', revision: 'c0ffee00c0ffee00').join("\n")}\n"
      warning: the Flutter template lacks 1 control and 1 extension this app uses:
        form (Form), main.rb:4: needs ruflet-template e793ccef345b or newer
        extension local_auth (ruflet_local_auth): needs ruflet-template cdbc2aaf6036 or newer
        Template: /t (revision c0ffee00c0ff)
        An app built from this template shows "Unknown control" in place of a control it lacks.
        Fetch the latest template with `ruflet doctor --fix`, or pass --strict to fail instead.
    TEXT
    assert_equal <<~TEXT, "#{Surface.report(problems.last(1), template_root: '/t', strict: true).join("\n")}\n"
      error: the Flutter template lacks 1 extension this app uses:
        extension local_auth (ruflet_local_auth): needs ruflet-template cdbc2aaf6036 or newer
        Template: /t
        Failing because of --strict. Fetch the latest template with `ruflet doctor --fix`.
    TEXT
  end

  # --- the commands -------------------------------------------------------------------

  class Host
    include Ruflet::CLI::BuildCommand
    include Ruflet::CLI::ExtraCommand
  end

  # The check is called, not mixed in. Including a module into RunCommand,
  # BuildCommand or ExtraCommand reorders Ruflet::CLI's ancestors: FlutterSdk
  # fell below RunCommand, so `ruflet run --web`, `ruflet update` and the
  # Flutter SDK download ran RunCommand's download_file and extract_archive.
  def test_the_cli_resolves_every_method_to_the_same_module_as_before
    ancestors = Ruflet::CLI.singleton_class.ancestors
    refute_includes ancestors, Check
    %w[RunCommand BuildCommand ExtraCommand].each do |name|
      refute_includes Ruflet::CLI.const_get(name).ancestors, Check, name
    end
    assert_equal Ruflet::CLI::FlutterSdk, Ruflet::CLI.method(:download_file).owner
    assert_equal Ruflet::CLI::FlutterSdk, Ruflet::CLI.method(:extract_archive).owner
    assert_equal Ruflet::CLI::Build::ClientDir, Ruflet::CLI.method(:hidden_flutter_client_dir).owner
    assert_equal Ruflet::CLI::Build::Contributors::AppIdentity, Ruflet::CLI.method(:humanize_name).owner
    assert_operator ancestors.index(Ruflet::CLI::FlutterSdk), :<, ancestors.index(Ruflet::CLI::RunCommand)
  end

  def test_check_warns_and_fails_only_with_strict
    project("main.rb" => FORM_APP) do |dir|
      template = old_template(File.join(dir, "template"))
      Dir.chdir(dir) do
        result = nil
        _out, err = capture_io { result = Check.check(Host.new, template) }
        assert result
        assert err.start_with?("warning: the Flutter template lacks 1 control this app uses:\n  form (Form), main.rb:4:")

        _out, err = capture_io { result = Check.check(Host.new, template, strict: true) }
        refute result
        assert err.start_with?("error: ")

        new_root = new_template(File.join(dir, "new_template"))
        out, err = capture_io { result = Check.check(Host.new, new_root, strict: true) }
        assert result
        assert_empty out
        assert_empty err
      end
    end
  end

  def test_check_reads_the_extensions_the_config_selects
    project("main.rb" => "text(\"a\")\n") do |dir|
      template = old_template(File.join(dir, "template"))
      Dir.chdir(dir) do
        _out, err = capture_io { Check.check(Host.new, template, config: { "services" => ["biometrics"] }) }
        assert_includes err, "extension local_auth (ruflet_local_auth): needs ruflet-template cdbc2aaf6036 or newer"

        _out, err = capture_io { Check.check(Host.new, template, config: -> { { "services" => ["biometrics"] } }) }
        assert_includes err, "extension local_auth (ruflet_local_auth): needs ruflet-template cdbc2aaf6036 or newer"
      end
    end
  end

  # doctor passes its config as a callable: it is read only when the template
  # lacks a bundled package, so a project whose ruflet.yaml does not parse
  # gets no new output from doctor.
  def test_the_config_is_read_only_when_the_template_lacks_a_bundled_package
    project("main.rb" => "text(\"a\")\n") do |dir|
      template = new_template(File.join(dir, "template"))
      out, err = capture_io { assert Check.check(Host.new, template, strict: true, config: -> { flunk("config read") }) }
      assert_empty out
      assert_empty err
    end
  end

  def test_doctor_reads_a_config_it_cannot_parse_quietly
    project("main.rb" => "text(\"a\")\n", "ruflet.yaml" => "app: [unclosed\n") do |dir|
      template = old_template(File.join(dir, "template"))
      Dir.chdir(dir) do
        host = Host.new
        config = nil
        out, err = capture_io { config = host.send(:doctor_project_config) }
        assert_equal({}, config)
        assert_empty out
        assert_empty err

        out, err = capture_io { assert Check.check(host, template, strict: true, config: -> { host.send(:doctor_project_config) }) }
        assert_empty out
        assert_empty err
      end
    end
  end

  def test_check_never_raises
    host = Host.new
    Surface.stub(:problems, ->(*) { raise "boom" }) do
      out, err = capture_io { assert Check.check(host, "/nowhere", strict: true) }
      assert_empty out
      assert_empty err
    end
  end

  def test_which_template_is_checked
    host = Host.new
    host.define_singleton_method(:resolve_ruflet_client_template_root) { "/installed" }
    assert_equal "/installed", Check.installed_root(host)
    assert_equal "/installed", Check.build_root(host, "/project/build/client")
    with_env("RUFLET_CLIENT_DIR" => "/custom") do
      assert_equal "/project/client", Check.build_root(host, "/project/client")
    end
    host.define_singleton_method(:resolve_ruflet_client_template_root) { nil }
    assert_equal "/project/build/client", Check.build_root(host, "/project/build/client")
    host.define_singleton_method(:resolve_ruflet_client_template_root) { raise "boom" }
    assert_nil Check.installed_root(host)
    assert_nil Check.installed_root(Object.new)
  end

  def test_build_fails_with_strict_before_preparing_the_client
    project("main.rb" => FORM_APP) do |dir|
      template = old_template(File.join(dir, "template"))
      host = Host.new
      host.define_singleton_method(:ensure_ruflet_build_assets) { |**| true }
      host.define_singleton_method(:ensure_flutter_client_dir) { |**| template }
      host.define_singleton_method(:resolve_ruflet_client_template_root) { template }
      host.define_singleton_method(:ensure_flutter!) { |*, **| flunk("nothing is prepared") }
      Dir.chdir(dir) do
        code = nil
        _out, err = capture_io { code = host.command_build(%w[apk --self --strict]) }
        assert_equal 1, code
        assert_includes err, "error: the Flutter template lacks 1 control this app uses:"
      end
    end
  end

  def test_the_check_is_quick_on_a_large_project
    files = { "main.rb" => FORM_APP }
    2_000.times { |index| files["lib/screens/screen_#{index}.rb"] = "def screen_#{index}\n  column(controls: [text(\"#{index}\")])\nend\n" * 20 }
    project(files) do |dir|
      template = old_template(File.join(dir, "template"))
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      problems = Surface.problems(template, project_root: dir)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      assert_equal ["form"], problems.map(&:name)
      assert_operator elapsed, :<, 2.0, "2001 files checked in #{elapsed.round(3)}s"
    end
  end

  private

  def with_env(values)
    saved = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end

  def with_wire_type(wire, entry)
    original = Surface::WIRE_TYPES
    Surface.send(:remove_const, :WIRE_TYPES)
    Surface.const_set(:WIRE_TYPES, original.merge(wire => entry).freeze)
    yield
  ensure
    Surface.send(:remove_const, :WIRE_TYPES)
    Surface.const_set(:WIRE_TYPES, original)
  end
end

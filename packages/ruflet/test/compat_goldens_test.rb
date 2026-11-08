# frozen_string_literal: true

require_relative "test_helper"
require_relative "compat/lib/harness"
require_relative "compat/docs_coverage"

# WP-00 H1: compatibility goldens for everything a developer touches today.
#
# For every corpus invocation (test/compat/corpus.rb) the installed `ruflet`
# runs against a sandboxed project with Flutter, pod, git and the network
# replaced by recorders, and the result is compared with the committed golden:
# the flutter/pod/git argv, the CLI's output, and every file it writes
# (build/client relative to the frozen template, plus exports and caches).
# Page goldens hold what a client receives when it registers with each
# fixture app: from Ruflet::Server, and for the Rails apps also from the
# endpoint config/routes.rb mounts.
#
# A difference means behavior changed. If that is intended, regenerate with
#   ruby packages/ruflet/test/compat/compat.rb --regenerate
# review the golden diff, and list it under "Behavior changes" in the PR.
class RufletCompatGoldensTest < Minitest::Test
  parallelize_me!

  HINT = "If intended: ruby packages/ruflet/test/compat/compat.rb --regenerate, " \
         "review the golden diff, and list it under \"Behavior changes\" in the PR."

  # The goldens describe a macOS developer machine (and the CI host): self-
  # contained Apple builds run the real /usr/libexec/PlistBuddy.
  SUPPORTED_HOST = RbConfig::CONFIG["host_os"].match?(/darwin/i) && File.executable?("/usr/libexec/PlistBuddy")

  RufletCompat.validate_corpus!

  def self.golden_test_name(path)
    "test_golden_#{path.delete_prefix("#{RufletCompat::GOLDEN_ROOT}/").sub(/\.(txt|json)\z/, '')}"
  end

  RufletCompat::Corpus::INVOCATIONS.each do |invocation|
    path = RufletCompat.cli_golden_path(invocation)
    define_method(golden_test_name(path)) { check_golden(path) { RufletCompat.render_cli(invocation) } }
  end

  RufletCompat::Corpus::PAGES.each do |page|
    path = RufletCompat.page_golden_path(page)
    define_method(golden_test_name(path)) { check_golden(path) { RufletCompat.render_page(page) } }
  end

  def test_every_golden_belongs_to_a_corpus_entry
    assert_empty RufletCompat.stale_golden_paths.map { |path| path.delete_prefix("#{RufletCompat::GOLDEN_ROOT}/") },
                 "goldens without a corpus entry; run compat.rb --regenerate to remove them"
  end

  # compat/docs_coverage.rb maps every documented invocation to goldens;
  # each must exist (`compat.rb docs-check` checks the other direction).
  def test_every_documented_invocation_has_goldens
    goldens = RufletCompat.expected_golden_paths.map { |path| path.delete_prefix("#{RufletCompat::GOLDEN_ROOT}/cli/").delete_suffix(".txt") }
    missing = RufletCompat::DocsCoverage.golden_ids - goldens
    assert_empty missing, "compat/docs_coverage.rb names goldens that corpus.rb does not produce"
    assert(RufletCompat::DocsCoverage::INVOCATIONS.values.all? { |ids| !ids.empty? })
  end

  def test_vendored_template_matches_its_source_manifest
    source = JSON.parse(File.read(File.join(RufletCompat::FIXTURE_ROOT, "template", "SOURCE.json")))
    archive = File.open(RufletCompat::TEMPLATE_ARCHIVE, "rb") { |io| RufletCompat::Tar.read(io) }
    actual = archive.to_h do |entry|
      [entry.path.delete_prefix("ruflet_flutter_template/"), Digest::SHA256.hexdigest(entry.data)]
    end

    assert_match(/\A[0-9a-f]{40}\z/, source.fetch("commit"))
    assert_equal source.fetch("files").transform_values { |file| file.fetch("sha256") }, actual
  end

  # The comparison must notice a changed flutter argv, a new file, changed
  # output, a CLI edit to a file a stub wrote, a CLI deletion of a file a
  # stub created, and a change in what the rake tasks and the Rails generator
  # pass to the CLI. Probes are added through the public
  # Ruflet::CLI.command_build/command_install/command_update and Page#title=
  # so they keep working however the CLI is reorganized.
  def test_harness_detects_cli_and_page_changes
    skip "compat goldens run on macOS hosts" unless SUPPORTED_HOST

    probed = RufletCompat::Workspace.new
    # ruflet/cli.rb is what bin/ruflet, the Railtie and the generator all load.
    File.open(File.join(probed.gem_libs.fetch("ruflet"), "ruflet", "cli.rb"), "a") do |file|
      file.write(<<~RUBY)
        Ruflet::CLI.singleton_class.prepend(Module.new do
          def command_build(args)
            status = super(args + ["--compat-probe"])
            File.write(File.join("build", "client", "compat-probe.txt"), "probe\\n")
            stub_file = File.join("build", "client", ".dart_tool", "package_config.json")
            File.write(stub_file, File.read(stub_file) + "\\n") if File.file?(stub_file)
            adaptive_icon = File.join("build", "client", "android", "app", "src", "main", "res", "mipmap-anydpi-v26", "launcher_icon.xml")
            File.delete(adaptive_icon) if File.file?(adaptive_icon)
            puts "compat probe"
            status
          end

          def command_install(args)
            puts "compat probe install \#{args.inspect}"
            super
          end

          def command_update(args)
            puts "compat probe update \#{args.inspect}"
            super
          end
        end)
      RUBY
    end
    File.open(File.join(probed.gem_libs.fetch("ruflet_core"), "ruflet.rb"), "a") do |file|
      file.write("Ruflet::Page.prepend(Module.new { def title=(value); super(\"\#{value} (probe)\"); end })\n")
    end

    invocation = RufletCompat::Corpus::INVOCATIONS.find do |entry|
      entry["fixture"] == "default_app" && entry["argv"] == %w[build apk --self] && !entry["id"]
    end
    actual = RufletCompat.render_cli(invocation, workspace: probed)
    golden = File.read(RufletCompat.cli_golden_path(invocation), encoding: Encoding::UTF_8)
    refute_equal golden, actual
    assert_includes actual, "--compat-probe"
    assert_includes actual, "A <PROJECT>/build/client/compat-probe.txt"
    assert_includes actual, "out| compat probe"
    assert_includes actual, "M <PROJECT>/build/client/.dart_tool/package_config.json  stub output ->"
    assert_includes actual, "D <PROJECT>/build/client/android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml  " \
                            "(removed after a stub wrote it)"

    {
      "rake-ruflet_install_emulator-5554" => 'compat probe install ["--device", "emulator-5554"]',
      "rake-ruflet_update_desktop" => 'compat probe update ["desktop"]',
      "generate-ruflet_install--desktop" => 'compat probe update ["desktop"]'
    }.each do |id, probe|
      entry = RufletCompat::Corpus::INVOCATIONS.find { |invocation| RufletCompat.invocation_id(invocation) == id }
      rendered = RufletCompat.render_cli(entry, workspace: probed)
      refute_equal File.read(RufletCompat.cli_golden_path(entry), encoding: Encoding::UTF_8), rendered, id
      assert_includes rendered, "out| #{probe}", id
    end

    page = RufletCompat::Corpus::PAGES.find { |entry| entry["fixture"] == "default_app" }
    page_actual = RufletCompat.render_page(page, workspace: probed)
    refute_equal File.read(RufletCompat.page_golden_path(page), encoding: Encoding::UTF_8), page_actual
    assert_includes page_actual, "Counter Demo (probe)"

    rails_page = RufletCompat::Corpus::PAGES.find { |entry| entry["id"] == "rails_app--rails-endpoint" }
    rails_actual = RufletCompat.render_page(rails_page, workspace: probed)
    refute_equal File.read(RufletCompat.page_golden_path(rails_page), encoding: Encoding::UTF_8), rails_actual
    assert_includes rails_actual, "Rails App (probe)"
  end

  # A fault in the harness's own code must fail the golden, never reach a
  # CLI `rescue` and be rendered as CLI behavior. The injected fault is the
  # one the release fixture's lazy Zlib::GzipWriter used to raise, inside the
  # request `release_by_tag` rescues.
  def test_harness_faults_fail_loudly
    skip "compat goldens run on macOS hosts" unless SUPPORTED_HOST

    invocation = RufletCompat::Corpus::INVOCATIONS.find { |entry| entry["id"] == "run-main.rb--desktop-release" }
    error = assert_raises(RufletCompat::HarnessFault) do
      RufletCompat.render_cli(invocation.merge("inject_fault" => "release_fixture"))
    end
    assert_includes error.message, "not CLI behavior"
    assert_includes error.message, "Zlib::BufError: buffer error (injected)"
    assert_includes error.message, "releases/tags/prebuild-main"
  end

  # The release archives are built once, when release_fixture.rb loads (before
  # the CLI runs), without zlib, are byte-identical in every process, and are
  # valid for the host tools the CLI extracts them with.
  def test_release_fixture_archives_are_fixed_and_valid
    skip "compat goldens run on macOS hosts" unless SUPPORTED_HOST

    fixture = File.join(RufletCompat::COMPAT_ROOT, "lib", "release_fixture.rb")
    loaded, status = Open3.capture2(RbConfig.ruby, "-e", <<~RUBY, fixture)
      require "digest"
      require "json"
      require ARGV.fetch(0)
      assets = RufletCompat::ReleaseFixture::ASSETS
      raise "not frozen" unless assets.frozen? && assets.each_value.all?(&:frozen?)
      raise "not deterministic" unless RufletCompat::ReleaseFixture.build_assets == assets
      print JSON.generate("zlib" => $LOADED_FEATURES.grep(/zlib/),
                          "sha256" => assets.transform_values { |bytes| Digest::SHA256.hexdigest(bytes) })
    RUBY
    assert status.success?
    loaded = JSON.parse(loaded)
    assert_empty loaded["zlib"], "release_fixture.rb must not load zlib"

    require_relative "compat/lib/release_fixture"
    # A second, independent process builds the very same bytes.
    assert_equal RufletCompat::ReleaseFixture::ASSETS.transform_values { |bytes| Digest::SHA256.hexdigest(bytes) },
                 loaded["sha256"]
    Dir.mktmpdir("ruflet-compat-archives-") do |dir|
      RufletCompat::ReleaseFixture.asset_sources.each do |name, (kind, files)|
        next if kind == :raw

        path = File.join(dir, name)
        File.binwrite(path, RufletCompat::ReleaseFixture::ASSETS.fetch(name))
        listing, = Open3.capture2(*(kind == :zip ? ["/usr/bin/unzip", "-Z1", path] : ["/usr/bin/tar", "-tzf", path]))
        assert_equal files.map(&:first), listing.lines.map(&:chomp), name
        out = File.join(dir, "#{name}.out")
        FileUtils.mkdir_p(out)
        system("/usr/bin/tar", "-xf", path, "-C", out, exception: true) # bsdtar reads gzip and zip
        files.each do |relative, mode, data|
          assert_equal data, File.binread(File.join(out, relative)), "#{name}: #{relative}"
          assert_equal mode, File.stat(File.join(out, relative)).mode & 0o777, "#{name}: #{relative}"
        end
      end
    end
  end

  # The generator goldens run against lib/generator_stub, a small stand-in for
  # railties (CI has no rails gem). Where railties 8.1 or later is installed
  # (the line the stub follows), every generator golden must come out
  # byte-identical with the real one.
  def test_generator_stub_matches_railties
    skip "compat goldens run on macOS hosts" unless SUPPORTED_HOST
    unless railties_installed?
      skip "railties >= 8.1 is not installed; the generator stub is checked against it where it is"
    end

    RufletCompat::Corpus::INVOCATIONS.select { |invocation| invocation["generator"] }.each do |invocation|
      path = RufletCompat.cli_golden_path(invocation)
      real = RufletCompat.render_cli(invocation.merge("real_rails" => true))
      expected = File.read(path, encoding: Encoding::UTF_8)
      next pass if expected == real

      diff = RufletCompat::TextDiff.unified(expected, real, old_label: "golden (generator stub)", new_label: "railties")
      flunk "#{path.delete_prefix("#{RufletCompat::GOLDEN_ROOT}/")}: the generator stub and railties disagree.\n#{diff}"
    end
  end

  private

  def railties_installed?
    latest = Gem::Specification.find_all_by_name("railties").map(&:version).max
    !latest.nil? && latest >= Gem::Version.new("8.1")
  rescue StandardError
    false
  end

  def check_golden(path)
    skip "compat goldens run on macOS hosts" unless SUPPORTED_HOST

    actual = yield
    relative = path.delete_prefix("#{RufletCompat::GOLDEN_ROOT}/")
    assert File.file?(path), "missing golden #{relative}. #{HINT}"
    expected = File.read(path, encoding: Encoding::UTF_8)
    return pass if expected == actual

    diff = RufletCompat::TextDiff.unified(expected, actual, old_label: "golden/#{relative}", new_label: "actual")
    lines = diff.lines
    shown = lines.first(120).join
    shown << "... (#{lines.length - 120} more diff lines)\n" if lines.length > 120
    flunk "#{relative} changed.\n#{HINT}\n#{shown}"
  end
end

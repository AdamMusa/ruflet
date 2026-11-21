# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class RufletCliNewCommandTest < Minitest::Test
  def test_command_new_creates_project_scaffold
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        out = StringIO.new
        original_stdout = $stdout
        $stdout = out

        result = Ruflet::CLI.command_new(["demo_app"])

        assert_equal 0, result
        assert File.exist?(File.join(dir, "demo_app", "main.rb"))
        assert File.exist?(File.join(dir, "demo_app", "Gemfile"))
        assert File.exist?(File.join(dir, "demo_app", "README.md"))
        assert File.exist?(File.join(dir, "demo_app", "ruflet.yaml"))
        assert File.exist?(File.join(dir, "demo_app", "services.yaml"))
        config = YAML.safe_load(File.read(File.join(dir, "demo_app", "ruflet.yaml")))
        services = YAML.safe_load(File.read(File.join(dir, "demo_app", "services.yaml")))
        generated_readme = File.read(File.join(dir, "demo_app", "README.md"))
        assert_equal [], config["extensions"]
        assert_equal "Demo App", services.dig("app", "app_name")
        assert_equal "demo_app", services.dig("app", "package_name")
        assert_equal "com.example", services.dig("app", "organization")
        assert_nil config.dig("app", "package_name")
        assert_equal [], services["services"]
        assert_includes generated_readme, "ruflet run main"
        refute_includes generated_readme, "bundle exec ruflet"
        assert_includes out.string, "ruflet run main.rb"
        refute_includes out.string, "bundle exec ruflet"
        assert File.file?(File.join(dir, "demo_app", "assets", "icon.png"))
        assert File.file?(File.join(dir, "demo_app", "assets", "splash.png"))
        # Ruflet renders through the Flutter engine on every platform, so a new
        # project carries no Swift package of its own.
        refute File.exist?(File.join(dir, "demo_app", "apple_extensions"))
        refute File.exist?(File.join(dir, "demo_app", "ruflet_client"))
        refute File.exist?(File.join(dir, "demo_app", ".bundle", "config"))
      ensure
        $stdout = original_stdout
      end
    end
  end

  def test_copy_ruflet_client_template_prefers_flutter_template
    Dir.mktmpdir do |dir|
      target_root = File.join(dir, "demo")
      FileUtils.mkdir_p(target_root)

      Ruflet::CLI.send(:copy_ruflet_client_template, target_root)

      client_dir = File.join(target_root, "build", "client")
      assert File.directory?(client_dir)
      refute File.exist?(File.join(client_dir, "assets", "main.rb"))
      assert File.file?(File.join(client_dir, "lib", "main.dart"))
      assert File.file?(File.join(client_dir, "lib", "main.self.dart"))
      assert File.file?(File.join(client_dir, "lib", "main.server.dart"))
      assert File.file?(File.join(client_dir, "pubspec.yaml"))
      refute File.exist?(File.join(client_dir, "ruflet_flutter_template"))
      refute File.exist?(File.join(client_dir, "ruflet.yaml"))
      refute File.exist?(File.join(client_dir, "services.yaml"))
      assert File.file?(File.join(client_dir, ".ruflet-template-revision"))
    end
  end

  def test_copy_ruflet_client_template_excludes_nested_build_caches
    Dir.mktmpdir do |dir|
      template = File.join(dir, "template")
      target_root = File.join(dir, "demo")
      FileUtils.mkdir_p(File.join(template, "lib"))
      FileUtils.mkdir_p(File.join(template, "ruflet_packages", "ruflet", "lib"))
      FileUtils.mkdir_p(File.join(template, "ruflet_packages", "ruflet", ".build"))
      FileUtils.mkdir_p(File.join(template, "ruflet_packages", "ruflet", ".build-ios-interaction"))
      FileUtils.mkdir_p(File.join(template, "ruflet_packages", "ruflet", "DerivedData"))
      FileUtils.mkdir_p(File.join(template, "ios", "Runner.xcodeproj", "xcuserdata", "developer.xcuserdatad"))
      FileUtils.mkdir_p(File.join(template, "ios", "Runner.xcworkspace", "xcshareddata", "swiftpm"))
      File.write(File.join(template, "pubspec.yaml"), "name: test\n")
      File.write(File.join(template, "lib", "main.dart"), "void main() {}\n")
      File.write(
        File.join(template, "ruflet_packages", "ruflet", "lib", "ruflet.dart"),
        "library ruflet;\n")
      File.write(
        File.join(template, "ruflet_packages", "ruflet", ".build", "stale"),
        "generated\n")
      File.write(
        File.join(template, "ruflet_packages", "ruflet", ".build-ios-interaction", "stale"),
        "generated\n")
      File.write(
        File.join(template, "ruflet_packages", "ruflet", "DerivedData", "stale"),
        "generated\n")
      File.write(
        File.join(template, "ios", "Runner.xcodeproj", "xcuserdata", "developer.xcuserdatad", "UserInterfaceState.xcuserstate"),
        "generated\n")
      File.write(
        File.join(template, "ios", "Runner.xcworkspace", "xcshareddata", "swiftpm", "Package.resolved"),
        "generated\n")

      Ruflet::CLI.stub(:resolve_ruflet_client_template_root, template) do
        Ruflet::CLI.send(:copy_ruflet_client_template, target_root)
      end

      client = File.join(target_root, "build", "client")
      assert File.file?(File.join(client, "pubspec.yaml"))
      assert File.file?(File.join(
        client, "ruflet_packages", "ruflet", "lib", "ruflet.dart"))
      refute File.exist?(File.join(
        client, "ruflet_packages", "ruflet", ".build"))
      refute File.exist?(File.join(
        client, "ruflet_packages", "ruflet", ".build-ios-interaction"))
      refute File.exist?(File.join(
        client, "ruflet_packages", "ruflet", "DerivedData"))
      refute File.exist?(File.join(
        client, "ios", "Runner.xcodeproj", "xcuserdata"))
      refute File.exist?(File.join(
        client, "ios", "Runner.xcworkspace", "xcshareddata", "swiftpm", "Package.resolved"))
      refute File.exist?(File.join(client, "template"))
    end
  end

  def test_cached_template_is_not_downloaded_when_revision_matches_github
    Dir.mktmpdir do |dir|
      previous_cache = ENV["RUFLET_CACHE_DIR"]
      ENV["RUFLET_CACHE_DIR"] = dir
      target = File.join(dir, "templates", "ruflet_flutter_template")
      FileUtils.mkdir_p(File.join(target, "lib"))
      File.write(File.join(target, "pubspec.yaml"), "name: ruflet_client\n")
      File.write(File.join(target, "lib", "main.dart"), "void main() {}\n")
      File.write(File.join(dir, "templates", "ruflet_flutter_template.revision"), "abc123\n")

      Ruflet::CLI.stub(:remote_template_revision, "abc123") do
        Ruflet::CLI.stub(:run_template_command, ->(*) { flunk "current template should not be downloaded" }) do
          assert_equal target, Ruflet::CLI.send(:ensure_cached_ruflet_client_template!)
        end
      end
    ensure
      ENV["RUFLET_CACHE_DIR"] = previous_cache
    end
  end

  def test_cached_template_is_replaced_when_github_revision_changes
    Dir.mktmpdir do |dir|
      previous_cache = ENV["RUFLET_CACHE_DIR"]
      ENV["RUFLET_CACHE_DIR"] = dir
      target = File.join(dir, "templates", "ruflet_flutter_template")
      FileUtils.mkdir_p(File.join(target, "lib"))
      File.write(File.join(target, "pubspec.yaml"), "name: ruflet_client\n")
      File.write(File.join(target, "lib", "main.dart"), "void main() {}\n")
      File.write(File.join(target, "stale.txt"), "old\n")
      File.write(File.join(dir, "templates", "ruflet_flutter_template.revision"), "old123\n")

      command_runner = lambda do |cmd, verbose: false|
        if cmd[0, 2] == ["git", "clone"]
          source = File.join(cmd.last, "templates", "ruflet_flutter_template")
          FileUtils.mkdir_p(File.join(source, "lib"))
          File.write(File.join(source, "pubspec.yaml"), "name: ruflet_client\n")
          File.write(File.join(source, "lib", "main.dart"), "void main() {}\n")
        end
        true
      end

      Ruflet::CLI.stub(:remote_template_revision, "new456") do
        Ruflet::CLI.stub(:run_template_command, command_runner) do
          Ruflet::CLI.stub(:git_revision, nil) do
            assert_equal target, Ruflet::CLI.send(:ensure_cached_ruflet_client_template!)
          end
        end
      end

      refute File.exist?(File.join(target, "stale.txt"))
      assert File.file?(File.join(target, "lib", "main.dart"))
      assert_equal "new456", File.read(File.join(dir, "templates", "ruflet_flutter_template.revision")).strip
    ensure
      ENV["RUFLET_CACHE_DIR"] = previous_cache
    end
  end

  def test_cached_template_remains_available_when_github_is_offline
    Dir.mktmpdir do |dir|
      previous_cache = ENV["RUFLET_CACHE_DIR"]
      ENV["RUFLET_CACHE_DIR"] = dir
      target = File.join(dir, "templates", "ruflet_flutter_template")
      FileUtils.mkdir_p(File.join(target, "lib"))
      File.write(File.join(target, "pubspec.yaml"), "name: ruflet_client\n")
      File.write(File.join(target, "lib", "main.dart"), "void main() {}\n")

      Ruflet::CLI.stub(:remote_template_revision, nil) do
        Ruflet::CLI.stub(:run_template_command, ->(*) { flunk "offline cache should not be replaced" }) do
          assert_equal target, Ruflet::CLI.send(:ensure_cached_ruflet_client_template!)
        end
      end
    ensure
      ENV["RUFLET_CACHE_DIR"] = previous_cache
    end
  end

  def test_copy_ruflet_client_template_uses_cached_template_when_repo_template_missing
    Dir.mktmpdir do |dir|
      target_root = File.join(dir, "demo")
      cached_template = File.join(dir, "cached_template")
      FileUtils.mkdir_p(File.join(cached_template, "lib"))
      FileUtils.mkdir_p(File.join(cached_template, "assets"))
      File.write(File.join(cached_template, "assets", "main.rb"), "puts 'hi'\n")
      File.write(File.join(cached_template, "lib", "main.dart"), "void main() {}\n")
      File.write(File.join(cached_template, "lib", "main.self.dart"), "void main() {}\n")
      File.write(File.join(cached_template, "lib", "main.server.dart"), "void main() {}\n")
      FileUtils.mkdir_p(target_root)

      cli_singleton = Ruflet::CLI.singleton_class
      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      cli_singleton.send(:define_method, :resolve_ruflet_client_template_root) { cached_template }
      cli_singleton.send(:private, :resolve_ruflet_client_template_root)

      Ruflet::CLI.send(:copy_ruflet_client_template, target_root)

      client_dir = File.join(target_root, "build", "client")
      assert File.directory?(client_dir)
      assert File.file?(File.join(client_dir, "assets", "main.rb"))
      assert File.file?(File.join(client_dir, "lib", "main.server.dart"))
    ensure
      cli_singleton.send(:define_method, :resolve_ruflet_client_template_root, original_method)
      cli_singleton.send(:private, :resolve_ruflet_client_template_root)
    end
  end

  def test_gemspec_keeps_runtime_bootstrap_out_of_gem
    gem_root = File.expand_path("..", __dir__)
    spec = Dir.chdir(gem_root) { Gem::Specification.load("ruflet.gemspec") }

    refute_includes spec.files, "assets/bootstrap/ruby_runtime.tar.gz"
  end

  def test_copy_ruflet_client_template_ignores_missing_template
    Dir.mktmpdir do |dir|
      target_root = File.join(dir, "demo")
      FileUtils.mkdir_p(target_root)

      cli_singleton = Ruflet::CLI.singleton_class
      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      original_cache_method = Ruflet::CLI.method(:ensure_cached_ruflet_client_template!)
      cli_singleton.send(:define_method, :resolve_ruflet_client_template_root) { nil }
      cli_singleton.send(:define_method, :ensure_cached_ruflet_client_template!) { nil }
      cli_singleton.send(:private, :resolve_ruflet_client_template_root)
      cli_singleton.send(:private, :ensure_cached_ruflet_client_template!)

      Ruflet::CLI.send(:copy_ruflet_client_template, target_root)

      refute File.directory?(File.join(target_root, "build", "client"))
    ensure
      cli_singleton.send(:define_method, :resolve_ruflet_client_template_root, original_method)
      cli_singleton.send(:define_method, :ensure_cached_ruflet_client_template!, original_cache_method)
      cli_singleton.send(:private, :resolve_ruflet_client_template_root)
      cli_singleton.send(:private, :ensure_cached_ruflet_client_template!)
    end
  end

  def test_command_new_requires_an_app_name
    [[], [""], ["  "]].each do |argv|
      _out, err = capture_io { assert_equal 1, Ruflet::CLI.command_new(argv.dup), argv.inspect }
      assert_includes err, "Usage: ruflet new <appname>"
    end
  end

  def test_command_new_refuses_an_existing_directory
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir_p("taken")
        _out, err = capture_io { assert_equal 1, Ruflet::CLI.command_new(["taken"]) }
        assert_includes err, "Directory already exists:"
        assert_empty Dir.children(File.join(dir, "taken"))
      end
    end
  end

  # `new` takes no options, so the CLI stops for a dashed word before the
  # scaffold runs (#78): help for -h/--help, a usage error for anything else.
  # Nothing named after the flag is created.
  def test_dashed_words_after_new_are_help_or_usage_errors_not_app_names
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        new_help = Ruflet::CLI::Commands.lookup("new").help_text
        Ruflet::CLI.stub(:download_ruflet_assets, ->(*) { flunk("no template fetch for help or a usage error") }) do
          %w[-h --help].each do |flag|
            out, err = capture_io { assert_equal 0, Ruflet::CLI.run(["new", flag]), flag }
            assert_equal new_help, out, flag
            assert_empty err, flag
          end
          %w[--force -x].each do |flag|
            out, err = capture_io { assert_equal 64, Ruflet::CLI.run(["new", flag]), flag }
            assert_empty out, flag
            assert_equal "ruflet new: invalid option: #{flag}\n\n#{new_help}", err, flag
          end
        end
        assert_empty Dir.children(dir)
      end
    end
  end

  def test_create_and_the_new_aliases_scaffold_through_the_dispatcher
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Ruflet::CLI.stub(:download_ruflet_assets, ->(*) {}) do
          %w[create new bootstrap init].each do |command|
            capture_io { assert_equal 0, Ruflet::CLI.run([command, "#{command}_app"]) }
            assert File.file?(File.join(dir, "#{command}_app", "main.rb")), command
          end
        end
      end
    end
  end
end

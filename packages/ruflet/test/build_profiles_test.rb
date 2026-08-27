# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class RufletCliBuildProfilesTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  def test_lite_and_full_are_mutually_exclusive
    err = capture_stderr do
      assert_equal 1, DummyBuilder.new.command_build(["apk", "--lite", "--full"])
    end

    assert_includes err, "--lite and --full are mutually exclusive"
  end

  def test_explicit_profiles_make_native_builds_self_contained
    %w[lite full].each do |profile|
      builder = command_builder
      calls = builder.instance_variable_get(:@test_calls)

      assert_equal 0, builder.command_build(["apk", "--#{profile}"])
      assert_equal profile.to_sym, calls.fetch(:prepared_profile)
      assert calls.fetch(:self_contained)
      assert_includes calls.fetch(:flutter), "RUFLET_RUNTIME_PROFILE=#{profile}"
      assert_includes calls.fetch(:flutter), "RUFLET_EMBEDDED_PROJECT=ruflet"
    end
  end

  def test_self_defaults_to_lite_and_full_overrides_that_default
    lite_builder = command_builder
    lite_calls = lite_builder.instance_variable_get(:@test_calls)

    assert_equal 0, lite_builder.command_build(["apk", "--self"])
    assert_equal :lite, lite_calls.fetch(:prepared_profile)
    assert lite_calls.fetch(:self_contained)

    full_builder = command_builder
    full_calls = full_builder.instance_variable_get(:@test_calls)

    assert_equal 0, full_builder.command_build(["apk", "--self", "--full"])
    assert_equal :full, full_calls.fetch(:prepared_profile)
    assert full_calls.fetch(:self_contained)
    assert_includes full_calls.fetch(:flutter), "RUFLET_RUNTIME_PROFILE=full"
  end

  def test_profile_flags_reject_web
    %w[lite full].each do |profile|
      err = capture_stderr do
        assert_equal 1, DummyBuilder.new.command_build(["web", "--#{profile}"])
      end
      assert_includes err, "--#{profile} is not supported for web"
    end
  end

  def test_full_profile_packages_locked_gems_and_reuses_build_cache
    builder = DummyBuilder.new
    builder.instance_variable_set(:@ruflet_runtime_profile, :full)
    builder.instance_variable_set(:@ruflet_build_platform, "macos")

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(client_dir)
      File.write(File.join(dir, "main.rb"), "puts :ok\n")
      File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\ngem \"demo\"\n")
      File.write(File.join(dir, "Gemfile.lock"), "GEM\n  specs:\n    demo (1.0.0)\n")

      installs = 0
      builder.define_singleton_method(:run_external_command) do |env, *_command, **_options|
        installs += 1
        gem_lib = File.join(env.fetch("BUNDLE_PATH"), "ruby", "3.4.0", "gems", "demo-1.0.0", "lib")
        gem_cache = File.join(env.fetch("BUNDLE_PATH"), "ruby", "3.4.0", "cache")
        FileUtils.mkdir_p(gem_lib)
        FileUtils.mkdir_p(gem_cache)
        File.write(File.join(gem_lib, "demo.rb"), "DEMO = true\n")
        File.write(File.join(gem_cache, "demo-1.0.0.gem"), "installation archive\n")
        true
      end
      builder.define_singleton_method(:vendor_full_runtime_path_gems) { |_env, **_options| true }

      2.times do
        assert Dir.chdir(dir) {
          builder.send(:sync_self_contained_project_assets, client_dir)
        }
      end

      project = File.join(client_dir, "assets", File.basename(dir))
      manifest = JSON.parse(File.read(File.join(project, ".ruflet-runtime.json")))
      assert_equal "full", manifest.fetch("profile")
      assert_equal "cruby", manifest.fetch("engine")
      assert_equal "vendor/bundle", manifest.fetch("bundle_path")
      assert manifest.fetch("warm_launch")
      assert File.file?(File.join(project, "vendor", "bundle", "ruby", "3.4.0", "gems", "demo-1.0.0", "lib", "demo.rb"))
      refute_path_exists File.join(project, "vendor", "bundle", "ruby", "3.4.0", "cache")
      assert_equal 1, installs
    end
  end

  def test_full_profile_path_gems_copy_only_gemspec_files
    builder = DummyBuilder.new
    builder.instance_variable_set(:@ruflet_full_runtime_manifest, { "ruby_abi" => "4.0.0" })

    Dir.mktmpdir do |dir|
      source = File.join(dir, "demo")
      metadata_source = File.join(dir, "bundler")
      bundle_path = File.join(dir, "vendor", "bundle")
      FileUtils.mkdir_p(File.join(source, "lib"))
      FileUtils.mkdir_p(File.join(source, "test"))
      FileUtils.mkdir_p(File.join(source, "build", "ios", "Debug-iphonesimulator"))
      File.write(File.join(source, "lib", "demo.rb"), "DEMO = true\n")
      File.write(File.join(source, "README.md"), "Demo\n")
      File.write(File.join(source, "test", "demo_test.rb"), "raise \"not packaged\"\n")
      File.binwrite(
        File.join(source, "build", "ios", "Debug-iphonesimulator", "libruflet_vm.a"),
        "simulator archive"
      )
      FileUtils.mkdir_p(File.join(metadata_source, "lib"))
      File.write(File.join(metadata_source, "lib", "bundler.rb"), "module Bundler; end\n")

      specs = [{
        "full_name" => "demo-1.0.0",
        "full_gem_path" => source,
        "extension_dir" => "",
        "source_type" => "Bundler::Source::Path",
        "files" => ["README.md", "lib/demo.rb"],
        "gemspec" => "Gem::Specification.new { |spec| spec.name = \"demo\" }\n"
      }, {
        "full_name" => "bundler-4.0.11",
        "full_gem_path" => metadata_source,
        "extension_dir" => "",
        "source_type" => "Bundler::Source::Metadata",
        "files" => ["lib/bundler.rb"],
        "gemspec" => "Gem::Specification.new { |spec| spec.name = \"bundler\" }\n"
      }]
      status = Object.new
      status.define_singleton_method(:success?) { true }

      Open3.stub(:capture3, [JSON.generate(specs), "", status]) do
        assert builder.send(
          :vendor_full_runtime_path_gems,
          {},
          bundle_path: bundle_path,
          project_root: dir
        )
      end

      gem_root = File.join(bundle_path, "ruby", "4.0.0", "gems", "demo-1.0.0")
      assert_path_exists File.join(gem_root, "lib", "demo.rb")
      assert_path_exists File.join(gem_root, "README.md")
      refute_path_exists File.join(gem_root, "test", "demo_test.rb")
      refute_path_exists File.join(
        gem_root, "build", "ios", "Debug-iphonesimulator", "libruflet_vm.a"
      )
      refute_path_exists File.join(bundle_path, "ruby", "4.0.0", "gems", "bundler-4.0.11")
      assert_path_exists File.join(
        bundle_path, "ruby", "4.0.0", "specifications", "demo-1.0.0.gemspec"
      )
    end
  end

  def test_full_profile_requires_a_matching_cruby_runtime_distribution
    builder = DummyBuilder.new
    err = capture_stderr do
      refute builder.send(:configure_full_runtime_distribution, {}, "android")
    end

    assert_includes err, "--full needs a CRuby runtime distribution for android"
    assert_includes err, "will not be mislabeled as CRuby"
  end

  def test_full_profile_accepts_a_matching_runtime_package
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "pubspec.yaml"), "name: ruby_runtime\n")
      File.write(
        File.join(dir, Ruflet::CLI::BuildCommand::FULL_RUNTIME_MANIFEST),
        JSON.generate(
          "engine" => "cruby",
          "ruby_version" => "3.4.0",
          "platforms" => %w[android ios macos windows linux]
        )
      )
      previous = ENV["RUFLET_FULL_RUNTIME_PATH"]
      ENV["RUFLET_FULL_RUNTIME_PATH"] = dir

      assert builder.send(:configure_full_runtime_distribution, {}, "apk")
      builder.instance_variable_set(:@ruflet_runtime_profile, :full)
      assert_equal({ "path" => File.expand_path(dir) }, builder.send(:ruby_runtime_dependency))
    ensure
      ENV["RUFLET_FULL_RUNTIME_PATH"] = previous
    end
  end

  def test_device_only_full_ios_runtime_skips_the_simulator_build
    builder = command_builder
    calls = builder.instance_variable_get(:@test_calls)
    flutter_calls = []
    builder.define_singleton_method(:configure_full_runtime_distribution) do |_config, _platform, **_options|
      @ruflet_full_runtime_manifest = { "device_only" => true }
      true
    end
    builder.define_singleton_method(:system) do |_env, *command, **_options|
      flutter_calls << command
      calls[:flutter] = command
      true
    end

    assert_equal 0, builder.command_build(["ios", "--self", "--full"])
    assert_equal 1, flutter_calls.length
    assert_includes flutter_calls.first, "--codesign"
    refute_includes flutter_calls.first, "--simulator"
  end

  def test_lite_profile_precompiles_project_ruby_and_records_cache_key
    builder = DummyBuilder.new
    builder.instance_variable_set(:@ruflet_runtime_profile, :lite)
    builder.instance_variable_set(:@ruflet_build_platform, "android")
    builder.define_singleton_method(:embedded_mrbc_path) { "/test/mrbc" }
    builder.define_singleton_method(:run_external_command) do |_env, *_command, **_options|
      output = _command[_command.index("-o") + 1]
      File.binwrite(output, "RITE0400")
      true
    end

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(dir, "lib"))
      File.write(File.join(dir, "main.rb"), "require_relative \"lib/app\"\n")
      File.write(File.join(dir, "lib", "app.rb"), "APP = true\n")

      assert Dir.chdir(dir) {
        builder.send(:sync_self_contained_project_assets, client_dir)
      }

      project = File.join(client_dir, "assets", File.basename(dir))
      refute File.exist?(File.join(project, "main.rb"))
      refute File.exist?(File.join(project, "lib", "app.rb"))
      assert File.file?(File.join(project, "main.mrb"))
      assert File.file?(File.join(project, "lib", "app.mrb"))
      manifest = JSON.parse(File.read(File.join(project, ".ruflet-runtime.json")))
      assert_equal "main.mrb", manifest.fetch("entrypoint")
      assert_equal 64, manifest.fetch("cache_key").length
      declared_assets = Dir.chdir(dir) do
        builder.send(:self_contained_project_asset_dirs, client_dir)
      end
      assert_includes(
        declared_assets,
        "assets/#{File.basename(dir)}/.ruflet-runtime.json"
      )
    end
  end

  def test_switching_from_full_to_lite_prunes_stale_gem_asset_directories
    builder = DummyBuilder.new
    builder.instance_variable_set(:@ruflet_runtime_profile, :lite)

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      project_name = File.basename(dir)
      project_assets = File.join(client_dir, "assets", project_name)
      FileUtils.mkdir_p(project_assets)
      File.write(File.join(project_assets, "main.mrb"), "RITE0400")
      File.write(File.join(project_assets, ".ruflet-runtime.json"), "{}\n")
      File.write(File.join(client_dir, "pubspec.yaml"), <<~YAML)
        name: demo
        dependencies: {}
        flutter:
          assets:
            - assets/icon.png
            - assets/#{project_name}/
            - assets/#{project_name}/vendor/bundle/ruby/4.0.0/gems/demo/lib/
      YAML

      Dir.chdir(dir) do
        builder.send(:sync_client_pubspec_for_runtime_mode, client_dir, self_contained: true)
      end

      assets = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")))
        .fetch("flutter").fetch("assets")
      assert_includes assets, "assets/icon.png"
      assert_includes assets, "assets/#{project_name}/"
      assert_includes assets, "assets/#{project_name}/.ruflet-runtime.json"
      refute assets.any? { |asset| asset.include?("vendor/bundle") }
    end
  end

  def test_android_runtime_metadata_selects_profile_and_project
    builder = DummyBuilder.new
    builder.instance_variable_set(:@ruflet_runtime_profile, :full)

    Dir.mktmpdir do |dir|
      manifest = File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml")
      FileUtils.mkdir_p(File.dirname(manifest))
      File.write(manifest, <<~XML)
        <manifest xmlns:android="http://schemas.android.com/apk/res/android">
          <application android:label="Demo">
          </application>
        </manifest>
      XML

      Dir.chdir(dir) do
        builder.send(
          :configure_android_runtime, dir,
          platform: "apk", self_contained: true)
      end

      content = File.read(manifest)
      assert_includes content, 'android:name="ruflet.runtime.autostart" android:value="true"'
      assert_includes content, 'android:name="ruflet.runtime.profile" android:value="full"'
      assert_includes content, %(android:name="ruflet.runtime.project" android:value="#{File.basename(dir)}")
    end
  end

  def test_android_build_clears_stale_incremental_flutter_assets
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      stale_paths = %w[
        build/app/intermediates/flutter/release/flutter_assets/assets/demo/vendor/bundle/demo.rb
        build/app/intermediates/assets/release/mergeReleaseAssets/flutter_assets/assets/demo/main.rb
        build/app/intermediates/compressed_assets/release/compressReleaseAssets/out/assets/flutter_assets/assets/demo/main.rb.jar
        build/app/intermediates/incremental/mergeReleaseAssets/merger.xml
      ]
      stale_paths.each do |relative_path|
        path = File.join(dir, relative_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "stale\n")
      end

      builder.send(:clear_stale_platform_outputs, dir, "apk")

      stale_paths.each do |relative_path|
        refute_path_exists File.join(dir, relative_path)
      end
    end
  end

  def test_ios_build_clears_stale_embedded_project_assets
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      project_name = File.basename(dir)
      stale_paths = [
        "build/ios/iphoneos/Runner.app/Frameworks/App.framework/flutter_assets/assets/#{project_name}/vendor/bundle/cache/demo.gem",
        "build/ios/Release-iphoneos/App.framework/flutter_assets/assets/#{project_name}/build/ios/libruflet_vm.a"
      ]
      stale_paths.each do |relative_path|
        path = File.join(dir, relative_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "stale\n")
      end

      Dir.chdir(dir) do
        builder.send(:clear_stale_platform_outputs, dir, "ios")
      end

      stale_paths.each do |relative_path|
        refute_path_exists File.join(dir, relative_path)
      end
    end
  end

  private

  def command_builder
    builder = DummyBuilder.new
    calls = {}
    builder.instance_variable_set(:@test_calls, calls)
    client_dir = File.join(Dir.tmpdir, "ruflet-profile-client")
    FileUtils.mkdir_p(File.join(client_dir, "lib"))
    File.write(File.join(client_dir, "lib", "main.self.dart"), "void main() {}\n")
    builder.define_singleton_method(:detect_flutter_client_dir) { client_dir }
    builder.define_singleton_method(:load_ruflet_config) { {} }
    builder.define_singleton_method(:ensure_flutter!) do |_name, **_options|
      { flutter: "flutter", dart: "dart", env: {} }
    end
    builder.define_singleton_method(:prepare_flutter_client) do |_dir, self_contained:, **_options|
      calls[:prepared_profile] = instance_variable_get(:@ruflet_runtime_profile)
      calls[:self_contained] = self_contained
      true
    end
    builder.define_singleton_method(:configure_full_runtime_distribution) do |_config, _platform, **_options|
      true
    end
    builder.define_singleton_method(:system) do |_env, *command, **_options|
      calls[:flutter] = command
      true
    end
    builder
  end

  def capture_stderr
    previous = $stderr
    output = StringIO.new
    $stderr = output
    yield
    output.string
  ensure
    $stderr = previous
  end
end

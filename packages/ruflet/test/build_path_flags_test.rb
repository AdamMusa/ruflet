# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"

# CLI-05: `ruflet build` runs Flutter inside the client dir (build/client), so
# a relative path given to a path-valued Flutter flag was looked up (or
# written) there instead of in the project. Such a path is now resolved
# against the project root when the path Flutter would use is broken; a
# relative path that works today reaches Flutter exactly as written.
class RufletBuildPathFlagsTest < Minitest::Test
  class Builder
    include Ruflet::CLI::BuildCommand
  end

  OUTPUT_FLAGS = {
    "--split-debug-info" => "symbols",
    "--code-size-directory" => "sizes",
    "--performance-measurement-file" => "perf.json"
  }.freeze
  WEB_OUTPUT_FLAGS = { "--output" => "dist", "--output-dir" => "dist" }.freeze
  INPUT_FLAGS = {
    "--dart-define-from-file" => "config/defines.json",
    "--export-options-plist" => "ios/ExportOptions.plist"
  }.freeze

  def setup
    @sandbox = File.realpath(Dir.mktmpdir("ruflet-path-flags"))
    @root = File.join(@sandbox, "my_app")
    @client = File.join(@root, "build", "client")
    FileUtils.mkdir_p(@client)
  end

  def teardown
    FileUtils.rm_rf(@sandbox)
  end

  def resolve(args, platform: "apk", client_dir: @client, root: @root)
    Builder.new.send(:resolve_flutter_path_args, args, root, client_dir: client_dir, platform: platform)
  end

  def touch(*relative, base: @root)
    path = File.join(base, *relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "{}\n")
    path
  end

  # --- broken today, resolved against the project ---------------------------

  def test_every_output_flag_is_resolved_against_the_project_in_both_spellings
    OUTPUT_FLAGS.each do |flag, value|
      expected = File.join(@root, value)
      assert_equal ["#{flag}=#{expected}"], resolve(["#{flag}=#{value}"]), "#{flag}=#{value}"
      assert_equal [flag, expected], resolve([flag, value]), "#{flag} #{value}"
    end
  end

  def test_the_web_output_directory_is_resolved_in_every_spelling
    WEB_OUTPUT_FLAGS.each do |flag, value|
      expected = File.join(@root, value)
      assert_equal ["#{flag}=#{expected}"], resolve(["#{flag}=#{value}"], platform: "web"), "#{flag}=#{value}"
      assert_equal [flag, expected], resolve([flag, value], platform: "web"), "#{flag} #{value}"
    end
    assert_equal ["-o", "#{@root}/dist"], resolve(%w[-o dist], platform: "web")
    assert_equal ["-o#{@root}/dist"], resolve(%w[-odist], platform: "web")
    # package:args reads `-o=dist` as -o with the value "=dist".
    assert_equal ["-o#{@root}/=dist"], resolve(%w[-o=dist], platform: "web")
  end

  def test_an_input_missing_from_the_client_dir_but_in_the_project_is_resolved_in_both_spellings
    INPUT_FLAGS.each do |flag, value|
      expected = touch(value)
      assert_equal ["#{flag}=#{expected}"], resolve(["#{flag}=#{value}"]), "#{flag}=#{value}"
      assert_equal [flag, expected], resolve([flag, value]), "#{flag} #{value}"
    end
  end

  def test_relative_spellings_are_normalized_against_the_root
    shared = touch("shared", "defines.json", base: @sandbox)
    assert_equal ["--split-debug-info=#{@root}/symbols"], resolve(%w[--split-debug-info=./symbols])
    assert_equal ["--dart-define-from-file=#{shared}"], resolve(%w[--dart-define-from-file=../shared/defines.json])
    assert_equal ["--output", "#{@root}/out/web"], resolve(%w[--output out/web/], platform: "web")
  end

  # A sibling of an exported or replaced directory is in neither.
  def test_outputs_beside_the_export_directories_are_resolved
    assert_equal ["-o", "#{@root}/build/web_out"], resolve(%w[-o build/web_out], platform: "web")
    assert_equal ["--split-debug-info=#{@root}/build/android_symbols"],
                 resolve(%w[--split-debug-info=build/android_symbols])
  end

  def test_repeated_flags_are_all_resolved
    touch("a.json")
    touch("b.env")
    assert_equal(
      ["--dart-define-from-file=#{@root}/a.json", "--dart-define-from-file", "#{@root}/b.env"],
      resolve(%w[--dart-define-from-file=a.json --dart-define-from-file b.env])
    )
  end

  # --- working today, left exactly as written -------------------------------

  def test_absolute_paths_are_untouched
    (OUTPUT_FLAGS.keys + INPUT_FLAGS.keys + WEB_OUTPUT_FLAGS.keys).each do |flag|
      assert_equal ["#{flag}=/elsewhere/x"], resolve(["#{flag}=/elsewhere/x"], platform: "web"), flag
      assert_equal [flag, "/elsewhere/x"], resolve([flag, "/elsewhere/x"], platform: "web"), flag
    end
    assert_equal ["-o", "/elsewhere/dist"], resolve(%w[-o /elsewhere/dist], platform: "web")
    assert_equal ["-o/elsewhere/dist"], resolve(%w[-o/elsewhere/dist], platform: "web")
  end

  # The workarounds people use today: a path written against build/client.
  def test_paths_that_already_leave_the_client_dir_are_left_as_written
    touch("config", "defines.json")
    touch("ExportOptions.plist")
    [
      %w[--dart-define-from-file=../../config/defines.json],
      %w[--dart-define-from-file ../../config/defines.json],
      %w[--export-options-plist ../../ExportOptions.plist],
      %w[--split-debug-info=../../symbols],
      %w[--split-debug-info ../symbols],
      %w[--split-debug-info=../client_symbols],  # beside build/client, not in it
      %w[--code-size-directory=../../sizes --performance-measurement-file ../../perf.json],
      # build/<project name>/symbols today; the same words from the project
      # root would name ./symbols.
      ["--split-debug-info=../#{File.basename(@root)}/symbols"]
    ].each { |args| assert_equal args, resolve(args, platform: "ios"), args.inspect }
    [%w[-o ../web_dist], %w[-o../../dist], %w[--output=../../dist], %w[--output-dir ../web_dist]].each do |args|
      assert_equal args, resolve(args, platform: "web"), args.inspect
    end
  end

  def test_an_input_the_client_dir_has_is_left_as_written
    touch("defines.json", base: @client)
    touch("defines.json")
    assert_equal %w[--dart-define-from-file=defines.json], resolve(%w[--dart-define-from-file=defines.json])
    assert_equal %w[--export-options-plist defines.json], resolve(%w[--export-options-plist defines.json], platform: "ios")
  end

  # Flutter needs a file: a directory at that path in the client dir is as
  # broken as nothing there.
  def test_a_directory_in_the_client_dir_does_not_count_as_the_input
    FileUtils.mkdir_p(File.join(@client, "config", "defines.json"))
    expected = touch("config", "defines.json")
    assert_equal ["--dart-define-from-file=#{expected}"], resolve(%w[--dart-define-from-file=config/defines.json])
  end

  def test_an_input_found_nowhere_is_left_for_flutter_to_report
    assert_equal %w[--dart-define-from-file=missing.json], resolve(%w[--dart-define-from-file=missing.json])
    FileUtils.mkdir_p(File.join(@root, "config"))
    assert_equal %w[--export-options-plist config], resolve(%w[--export-options-plist config], platform: "ios"),
                 "a directory is not the file Flutter needs"
  end

  # build/client/build/<platform output> is copied into ./build after the
  # build, so an output written there reaches the project today.
  def test_outputs_the_build_exports_are_left_as_written
    { "web" => [%w[-o build/web], %w[--output=./build/web/], %w[--output build/web/assets]],
      "apk" => [%w[--split-debug-info=build/app/outputs/symbols]],
      "appbundle" => [%w[--split-debug-info build/app/outputs]],
      "ios" => [%w[--split-debug-info=build/ios/symbols]],
      "ipa" => [%w[--split-debug-info=build/ios/symbols], %w[--code-size-directory build/ios/sizes]],
      "macos" => [%w[--code-size-directory=build/macos/sizes]],
      "linux" => [%w[--split-debug-info=build/linux/symbols]],
      "windows" => [%w[--split-debug-info=build/windows/symbols]] }.each do |platform, cases|
      cases.each { |args| assert_equal args, resolve(args, platform: platform), "#{platform} #{args.inspect}" }
    end
  end

  # Moving these to the project would put them where the export deletes them
  # (./build/<platform>) or back inside build/client, so they stay as today.
  def test_outputs_whose_project_path_the_build_would_replace_are_left_as_written
    [
      ["apk", %w[--split-debug-info=build/android/symbols]],
      ["ios", %w[--split-debug-info=build/ios]],
      ["web", %w[-o build/client/web_out]],
      ["apk", %w[--split-debug-info=build/client]]
    ].each { |platform, args| assert_equal args, resolve(args, platform: platform), "#{platform} #{args.inspect}" }
  end

  # Rewriting these would move an output out of the project, or onto the
  # project root or ./build, which hold build/client, so they stay as today.
  def test_outputs_whose_project_path_leaves_the_project_or_holds_the_client_dir_are_left_as_written
    [
      ["apk", %w[--split-debug-info=../client/symbols]],
      ["apk", %w[--split-debug-info .]],
      ["web", %w[-o ../client]],
      ["web", %w[-o .]],
      ["web", %w[-o./]],
      ["web", %w[--output build]],
      ["web", %w[--output-dir=build/]]
    ].each { |platform, args| assert_equal args, resolve(args, platform: platform), "#{platform} #{args.inspect}" }
  end

  # An ipa is exported as ios, whatever name the caller passes.
  def test_an_ipa_is_resolved_like_ios
    assert_equal ["--split-debug-info=#{@root}/symbols"], resolve(%w[--split-debug-info=symbols], platform: "ipa")
    [%w[--split-debug-info=symbols], %w[--split-debug-info=build/ios/symbols], %w[-o dist]].each do |args|
      assert_equal resolve(args, platform: "ios"), resolve(args, platform: "ipa"), args.inspect
    end
  end

  # A client dir the developer owns is never deleted by Ruflet, so outputs
  # written into it work today. Inputs it lacks are still found in the project.
  def test_outputs_in_a_client_dir_ruflet_does_not_manage_are_left_as_written
    defines = touch("config", "defines.json")
    [File.join(@root, "ruflet_client"), File.join(@sandbox, "elsewhere", "client")].each do |client|
      FileUtils.mkdir_p(client)
      assert_equal %w[--split-debug-info=symbols], resolve(%w[--split-debug-info=symbols], client_dir: client)
      assert_equal %w[-o dist], resolve(%w[-o dist], platform: "web", client_dir: client)
      assert_equal ["--dart-define-from-file=#{defines}"],
                   resolve(%w[--dart-define-from-file=config/defines.json], client_dir: client)
    end
  end

  def test_output_dir_flags_are_left_alone_for_targets_flutter_gives_none
    %w[apk appbundle ios ipa macos windows linux].each do |platform|
      [%w[-o dist], %w[-odist], %w[--output dist], %w[--output-dir=dist]].each do |args|
        assert_equal args, resolve(args, platform: platform), "#{platform} #{args.inspect}"
      end
    end
  end

  def test_values_ruflet_cannot_resolve_are_left_to_flutter
    [
      %w[--split-debug-info],             # no value: Flutter reports it
      %w[--output=],                      # empty value
      %w[--output --release],             # the next argument is a flag
      %w[--split-debug-info=~/symbols],   # no shell expanded the ~
      %w[--split-debug-info=~no_such_user_ruflet/symbols],
      %w[--dart-define-from-file=~no_such_user_ruflet/defines.json],
      %w[-o]
    ].each do |args|
      assert_equal args, resolve(args, platform: "web"), args.inspect
    end
  end

  def test_nothing_after_a_bare_double_dash_is_rewritten
    args = %w[--release -- --split-debug-info=symbols -o dist]
    assert_equal args, resolve(args, platform: "web")
    assert_equal ["--split-debug-info=#{@root}/symbols", "--", "--split-debug-info", "symbols"],
                 resolve(%w[--split-debug-info=symbols -- --split-debug-info symbols])
  end

  def test_other_arguments_reach_flutter_unchanged
    args = %w[
      --release --obfuscate --split-per-abi --target-platform android-arm64 --build-name 1.2.3
      --dart-define=OUTPUT=dist --dart-define FILE=symbols --flavor prod --no-codesign
      --web-renderer html --base-href /app/ -v --optimization-level 4
    ]
    assert_equal args, resolve(args, platform: "web")
    assert_equal args, resolve(args, platform: "apk")
  end

  def test_the_arguments_are_not_modified_in_place
    args = %w[--split-debug-info symbols]
    resolve(args)
    assert_equal %w[--split-debug-info symbols], args
  end

  def test_the_project_root_and_client_dir_default_to_the_working_directory
    Dir.chdir(@root) do
      builder = Builder.new
      assert_equal ["--split-debug-info=#{@root}/symbols"],
                   builder.send(:resolve_flutter_path_args, %w[--split-debug-info=symbols])
      # RUFLET_CLIENT_DIR=build/client is the managed client, written relative.
      assert_equal ["--split-debug-info=#{@root}/symbols"],
                   builder.send(:resolve_flutter_path_args, %w[--split-debug-info=symbols], client_dir: "build/client")
    end
  end
end

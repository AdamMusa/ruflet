# frozen_string_literal: true

require_relative "test_helper"

# CLI-05: `ruflet build` runs Flutter inside build/client, so a relative path
# given to a path-valued Flutter flag was looked up (or written) there instead
# of in the project. These flags are now resolved against the project root;
# everything else reaches Flutter unchanged.
class RufletBuildPathFlagsTest < Minitest::Test
  class Builder
    include Ruflet::CLI::BuildCommand
  end

  ROOT = "/work/my_app"

  def resolve(args, root = ROOT)
    Builder.new.send(:resolve_flutter_path_args, args, root)
  end

  # Each listed flag, in its `--flag=value` and `--flag value` spellings.
  PATH_FLAGS = {
    "--dart-define-from-file" => "config/defines.json",
    "--split-debug-info" => "symbols",
    "--export-options-plist" => "ios/ExportOptions.plist",
    "--code-size-directory" => "build/sizes",
    "--performance-measurement-file" => "perf.json",
    "--output" => "dist",
    "--output-dir" => "dist"
  }.freeze

  def test_every_path_flag_is_resolved_against_the_project_in_both_spellings
    PATH_FLAGS.each do |flag, value|
      expected = File.join(ROOT, value)

      assert_equal ["#{flag}=#{expected}"], resolve(["#{flag}=#{value}"]), "#{flag}=#{value}"
      assert_equal [flag, expected], resolve([flag, value]), "#{flag} #{value}"
    end
  end

  def test_the_output_abbreviation_is_resolved_too
    assert_equal ["-o", "#{ROOT}/dist"], resolve(%w[-o dist])
    assert_equal ["-o#{ROOT}/dist"], resolve(%w[-odist])
  end

  def test_absolute_paths_are_untouched
    PATH_FLAGS.each_key do |flag|
      assert_equal ["#{flag}=/elsewhere/x"], resolve(["#{flag}=/elsewhere/x"]), flag
      assert_equal [flag, "/elsewhere/x"], resolve([flag, "/elsewhere/x"]), flag
    end
    assert_equal ["-o", "/elsewhere/dist"], resolve(%w[-o /elsewhere/dist])
    assert_equal ["-o/elsewhere/dist"], resolve(%w[-o/elsewhere/dist])
  end

  def test_relative_spellings_are_normalized_against_the_root
    assert_equal ["--split-debug-info=#{ROOT}/symbols"], resolve(%w[--split-debug-info=./symbols])
    assert_equal ["--dart-define-from-file=/work/shared/defines.json"], resolve(%w[--dart-define-from-file=../shared/defines.json])
    assert_equal ["--output", "#{ROOT}/out/web"], resolve(%w[--output out/web/])
  end

  def test_values_ruflet_cannot_resolve_are_left_to_flutter
    [
      %w[--split-debug-info],             # no value: Flutter reports it
      %w[--output=],                      # empty value
      %w[--output --release],             # the next argument is a flag
      %w[--split-debug-info=~/symbols],   # no shell expanded the ~
      %w[-o]
    ].each do |args|
      assert_equal args, resolve(args), args.inspect
    end
  end

  def test_repeated_flags_are_all_resolved
    assert_equal(
      ["--dart-define-from-file=#{ROOT}/a.json", "--dart-define-from-file", "#{ROOT}/b.env"],
      resolve(%w[--dart-define-from-file=a.json --dart-define-from-file b.env])
    )
  end

  def test_other_arguments_reach_flutter_unchanged
    args = %w[
      --release --obfuscate --split-per-abi --target-platform android-arm64 --build-name 1.2.3
      --dart-define=OUTPUT=dist --dart-define FILE=symbols --flavor prod --no-codesign
      --web-renderer html --base-href /app/ -v
    ]
    assert_equal args, resolve(args)
  end

  def test_the_arguments_are_not_modified_in_place
    args = %w[--split-debug-info symbols]
    resolve(args)
    assert_equal %w[--split-debug-info symbols], args
  end

  def test_the_project_root_defaults_to_the_working_directory
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        root = Dir.pwd
        assert_equal ["--split-debug-info=#{root}/symbols"], Builder.new.send(:resolve_flutter_path_args, %w[--split-debug-info=symbols])
      end
    end
  end
end

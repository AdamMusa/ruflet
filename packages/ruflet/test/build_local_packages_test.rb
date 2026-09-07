# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class RufletCliBuildLocalPackagesTest < Minitest::Test
  class Builder
    include Ruflet::CLI::BuildCommand
  end

  def with_client
    Dir.mktmpdir("local packages ") do |dir|
      core = File.join(dir, "ruflet_packages/ruflet")
      vendor = File.join(core, "vendor/math")
      FileUtils.mkdir_p(vendor)
      FileUtils.mkdir_p(File.join(dir, ".dart_tool"))
      File.write(File.join(core, "pubspec.yaml"), "name: ruflet\ndependencies:\n  math:\n    path: vendor/math\n")
      File.write(File.join(vendor, "pubspec.yaml"), "name: math\n")
      packages = [
        { "name" => "ruflet", "rootUri" => "../ruflet_packages/ruflet" },
        { "name" => "math", "rootUri" => "../ruflet_packages/ruflet/vendor/math" }
      ]
      yield Builder.new, dir, packages
    end
  end

  def verify(builder, dir, packages)
    File.write(File.join(dir, ".dart_tool/package_config.json"), JSON.generate("packages" => packages))
    result = nil
    capture_io { result = builder.send(:validate_local_ruflet_packages, dir) }
    result
  end

  def test_accepts_bundled_engine_and_transitive_vendor_forks
    with_client { |builder, dir, packages| assert verify(builder, dir, packages) }
  end

  def test_rejects_a_vendor_override_outside_the_bundle
    with_client do |builder, dir, packages|
      FileUtils.mkdir_p(File.join(dir, "hosted_math"))
      packages.last["rootUri"] = "../hosted_math"
      refute verify(builder, dir, packages)
    end
  end

  def test_rejects_legacy_flet_even_if_core_is_local
    with_client do |builder, dir, packages|
      packages << { "name" => "flet", "rootUri" => "../legacy" }
      refute verify(builder, dir, packages)
    end
  end

  def test_rejects_missing_selected_extension
    with_client do |builder, dir, packages|
      builder.instance_variable_set(:@ruflet_selected_flutter_extension_packages, ["ruflet_charts"])
      refute verify(builder, dir, packages)
    end
  end

  def test_legacy_configuration_aliases_still_select_our_package
    builder = Builder.new
    assert_equal "charts", builder.send(:normalize_extension_key, "flet_charts")
    assert_equal "charts", builder.send(:normalize_extension_key, "ruflet_charts")
  end

  def test_scaffolding_and_building_share_the_same_extension_catalog
    assert_equal Ruflet::CLI::NewCommand::CLIENT_EXTENSION_MAP, Ruflet::CLI::BuildCommand::CLIENT_EXTENSION_MAP
  end
end

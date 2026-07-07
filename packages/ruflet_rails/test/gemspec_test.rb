# frozen_string_literal: true

require_relative "test_helper"

class RufletRailsGemspecTest < Minitest::Test
  def test_gemspec_uses_rails_release_version_and_current_ruflet_packages
    gem_root = File.expand_path("..", __dir__)
    spec = Dir.chdir(gem_root) { Gem::Specification.load("ruflet_rails.gemspec") }
    own_version = File.read(File.expand_path("../lib/ruflet/version.rb", __dir__)).match(/VERSION = "([^"]+)"/)[1]

    # The gemspec version tracks ruflet_rails' own version.rb, not a literal.
    assert_equal own_version, spec.version.to_s

    # Each ruflet_* dependency must be a concrete >= floor that includes the
    # protocol-engine release (0.0.17) the adapter relies on.
    %w[ruflet ruflet_core ruflet_server].each do |name|
      dependency = spec.dependencies.find { |item| item.name == name }
      refute_nil dependency, "Expected #{name} dependency"

      requirement = dependency.requirement.to_s
      assert_match(/\A>= \d+\.\d+\.\d+\z/, requirement, "#{name} should pin a concrete >= floor")
      assert_operator Gem::Version.new(requirement.delete_prefix(">= ")),
                      :>=, Gem::Version.new("0.0.17"),
                      "#{name} floor must include the protocol-engine release"
    end
  end
end

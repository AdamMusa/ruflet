# frozen_string_literal: true

require_relative "test_helper"

class RufletCliTemplatesTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../../..", __dir__)

  def test_main_template_boots_app
    assert_includes Ruflet::CLI::MAIN_TEMPLATE, 'Ruflet.run do |page|'
    assert_includes Ruflet::CLI::MAIN_TEMPLATE, 'require "ruflet"'
  end

  def test_gemfile_template_includes_runtime_dependencies
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet_core"'
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet_server"'
    refute_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet",'
  end

  def test_template_is_owned_by_external_repository
    assert_equal "https://github.com/AdamMusa/ruflet-template.git", Ruflet::CLI::NewCommand::TEMPLATE_REPO_URL
    refute_path_exists repo_file("templates", "ruflet_flutter_template")
  end

  def test_template_root_accepts_the_external_repository_directory
    Dir.mktmpdir do |root|
      template = File.join(root, "templates", "ruflet_flutter_template")
      FileUtils.mkdir_p(File.join(template, "lib"))
      File.write(File.join(template, "pubspec.yaml"), "name: ruflet_client\n")
      File.write(File.join(template, "lib", "main.dart"), "void main() {}\n")

      previous = ENV["RUFLET_TEMPLATE_ROOT"]
      ENV["RUFLET_TEMPLATE_ROOT"] = root
      assert_equal template, Ruflet::CLI.send(:resolve_ruflet_client_template_root)
    ensure
      ENV["RUFLET_TEMPLATE_ROOT"] = previous
    end
  end

  private

  def repo_file(directory, path)
    File.join(REPOSITORY_ROOT, directory, path)
  end
end

# frozen_string_literal: true

require_relative "test_helper"

class RufletCliNewCommandTest < Minitest::Test
  def test_command_new_creates_project_scaffold
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        out = StringIO.new
        original_stdout = $stdout
        $stdout = out

        cli_singleton = Ruflet::CLI.singleton_class
        had_method = cli_singleton.private_method_defined?(:copy_ruflet_client_template) || cli_singleton.method_defined?(:copy_ruflet_client_template)
        original_method = Ruflet::CLI.method(:copy_ruflet_client_template) if had_method

        cli_singleton.send(:define_method, :copy_ruflet_client_template) { |_root| nil }
        cli_singleton.send(:private, :copy_ruflet_client_template)

        result = Ruflet::CLI.command_new(["demo_app"])

        assert_equal 0, result
        assert File.exist?(File.join(dir, "demo_app", "main.rb"))
        assert File.exist?(File.join(dir, "demo_app", "Gemfile"))
        assert File.exist?(File.join(dir, "demo_app", "README.md"))
      ensure
        $stdout = original_stdout

        if had_method
          cli_singleton.send(:define_method, :copy_ruflet_client_template, original_method)
          cli_singleton.send(:private, :copy_ruflet_client_template)
        else
          cli_singleton.send(:remove_method, :copy_ruflet_client_template)
        end
      end
    end
  end
end

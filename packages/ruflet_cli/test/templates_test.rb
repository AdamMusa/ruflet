# frozen_string_literal: true

require_relative "test_helper"

class RufletCliTemplatesTest < Minitest::Test
  def test_main_template_boots_app
    assert_includes Ruflet::CLI::MAIN_TEMPLATE, 'MainApp.new.run'
    assert_includes Ruflet::CLI::MAIN_TEMPLATE, 'require "ruflet"'
  end

  def test_gemfile_template_includes_runtime_dependencies
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet"'
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet_server"'
  end
end

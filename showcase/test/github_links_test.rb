# frozen_string_literal: true

require "minitest/autorun"

require_relative "../helpers"

class GithubLinksTest < Minitest::Test
  include Showcase::Helpers

  FakeButton = Struct.new(:content, :on_click, keyword_init: true)
  FakeImage = Struct.new(:src, :width, :height, keyword_init: true)

  class FakePage
    attr_reader :launches

    def initialize
      @launches = []
    end

    def launch_url(url, **options)
      @launches << [url, options]
    end
  end

  def test_github_url_uses_studio_repo_and_source_path
    assert_equal(
      "https://github.com/AdamMusa/ruflet/blob/main/ruflet_studio/sections_media/share.rb",
      github_url_for("sections_media/share.rb")
    )
  end

  def test_open_github_launches_external_application
    page = FakePage.new

    open_github(page, "sections_media/share.rb")

    url, options = page.launches.fetch(0)
    assert_equal "https://github.com/AdamMusa/ruflet/blob/main/ruflet_studio/sections_media/share.rb", url
    assert_equal "external_application", options.fetch(:mode)
    assert options.key?(:on_result)
  end

  def test_every_detail_view_has_source_path
    app_source = File.read(File.expand_path("../app.rb", __dir__))
    detail_views = app_source.scan(/detail_view\(/).length
    source_paths = app_source.scan(/source_path:\s*"[^"]+"/).length

    assert_operator detail_views, :>, 0
    assert_equal detail_views, source_paths
  end

  private

  def image(**props)
    FakeImage.new(**props)
  end

  def text_button(**props)
    FakeButton.new(**props)
  end
end

# frozen_string_literal: true

require_relative "test_helper"

class RufletManifestCompilerTest < Minitest::Test
  class DemoApp < Ruflet::App
    def view(page)
      page.title = "Manifest Demo"
      page.add(page.text(value: "Hello"))
    end
  end

  def test_compile_app_returns_manifest_shape
    manifest = Ruflet::ManifestCompiler.compile_app(DemoApp.new, route: "/demo")

    assert_equal "ruflet_manifest/v1", manifest["schema"]
    assert_equal "/demo", manifest["route"]
    assert manifest["generated_at"].is_a?(String)
    assert manifest["messages"].is_a?(Array)
    refute_empty manifest["messages"]
  end

  def test_write_and_read_round_trip
    manifest = { "schema" => "ruflet_manifest/v1", "messages" => [] }

    Dir.mktmpdir do |dir|
      path = File.join(dir, "manifest.json")
      Ruflet::ManifestCompiler.write_file(path, manifest)
      loaded = Ruflet::ManifestCompiler.read_file(path)
      assert_equal manifest, loaded
    end
  end
end

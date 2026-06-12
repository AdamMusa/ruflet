# frozen_string_literal: true

require_relative "test_helper"

# The mobile/desktop WebSocket endpoint (/ws) must be declared by the developer
# the same way web mounts are — view:, app_file: or a block — so the screens the
# app shows live in dev code. A bare endpoint still falls back to the framework's
# auto-discovery view router for the zero-config case.
class RufletEndpointDeclarationTest < Minitest::Test
  def rack_app?(obj)
    obj.respond_to?(:call)
  end

  def test_endpoint_with_a_view_class_is_a_rack_endpoint
    assert rack_app?(Ruflet::Rails.endpoint(view: "ProductComponent"))
  end

  def test_endpoint_with_an_app_file_is_a_rack_endpoint
    Dir.mktmpdir do |dir|
      file = File.join(dir, "main.rb")
      File.write(file, "Ruflet.run { |page| page.add(Ruflet::UI::ControlFactory.build(:text, value: \"hi\")) }\n")
      assert rack_app?(Ruflet::Rails.endpoint(app_file: file))
    end
  end

  def test_endpoint_with_a_block_is_a_rack_endpoint
    assert rack_app?(Ruflet::Rails.endpoint { |page| page.add(Ruflet::UI::ControlFactory.build(:text, value: "hi")) })
  end

  def test_bare_endpoint_falls_back_to_the_view_router
    # No declared entry — still usable (the framework's convenience fallback).
    assert rack_app?(Ruflet::Rails.endpoint)
  end

  def test_endpoint_rejects_more_than_one_source
    assert_raises(ArgumentError) do
      Ruflet::Rails.endpoint(view: "ProductComponent", app_file: "x.rb")
    end
  end

  def test_app_shorthand_delegates_to_endpoint_app_file
    Dir.mktmpdir do |dir|
      file = File.join(dir, "main.rb")
      File.write(file, "Ruflet.run { |page| page.add(Ruflet::UI::ControlFactory.build(:text, value: \"hi\")) }\n")
      assert rack_app?(Ruflet::Rails.app(file))
    end
  end

  # The declared entry drives what renders — a view: endpoint renders that
  # component, never the auto-discovery route index.
  def test_view_endpoint_entrypoint_renders_the_declared_component
    rendered = []
    fake = Class.new do
      define_singleton_method(:render) { |page| page.instance_variable_set(:@rendered, true) }
    end
    Object.const_set(:DeclaredHomeComponent, fake)

    sent = []
    page = Ruflet::Page.new(session_id: "e", client_details: { "route" => "/" },
                            sender: ->(a, p) { sent << [a, p] })
    # web_app_entrypoint(view:) is what endpoint(view:) builds its entry from.
    Ruflet::Rails.web_app_entrypoint(view: "DeclaredHomeComponent").call(page)

    assert_equal true, page.instance_variable_get(:@rendered)
  ensure
    Object.send(:remove_const, :DeclaredHomeComponent) if Object.const_defined?(:DeclaredHomeComponent)
  end
end

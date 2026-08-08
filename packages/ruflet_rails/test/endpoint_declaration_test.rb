# frozen_string_literal: true

require_relative "test_helper"

# The mobile/desktop WebSocket endpoint (/ws) must be declared by the developer
# as an app file or a block. There is no auto-discovery fallback: a bare endpoint
# raises.
class RufletEndpointDeclarationTest < Minitest::Test
  def rack_app?(obj)
    obj.respond_to?(:call)
  end

  def test_endpoint_with_an_app_file_is_a_rack_endpoint
    Dir.mktmpdir do |dir|
      file = File.join(dir, "main.rb")
      File.write(file, "Ruflet.run { |page| page.add(Ruflet::UI::ControlFactory.build(:text, value: \"hi\")) }\n")
      assert rack_app?(Ruflet::Rails.native(file))
    end
  end

  def test_endpoint_with_a_block_is_a_rack_endpoint
    assert rack_app?(Ruflet::Rails.native { |page| page.add(Ruflet::UI::ControlFactory.build(:text, value: "hi")) })
  end

  def test_bare_endpoint_raises
    # No declared entry and no auto-discovery fallback — the developer must
    # declare app_file: or a block.
    assert_raises(ArgumentError) { Ruflet::Rails.native }
  end

  def test_endpoint_rejects_more_than_one_source
    assert_raises(ArgumentError) do
      Ruflet::Rails.native("x.rb") { |page| page }
    end
  end

  def test_native_accepts_an_app_file
    Dir.mktmpdir do |dir|
      file = File.join(dir, "main.rb")
      File.write(file, "Ruflet.run { |page| page.add(Ruflet::UI::ControlFactory.build(:text, value: \"hi\")) }\n")
      assert rack_app?(Ruflet::Rails.native(file))
    end
  end

end

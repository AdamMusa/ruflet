# frozen_string_literal: true

require_relative "test_helper"

class RufletIconLookupTest < Minitest::Test
  def test_material_icon_lookup_uses_local_json
    assert_equal 65604, Ruflet::MaterialIconLookup.codepoint_for("add")
    assert_equal 65604, Ruflet::MaterialIconLookup.codepoint_for(:add)
  end

  def test_cupertino_icon_lookup_uses_local_json
    refute_nil Ruflet::CupertinoIconLookup.codepoint_for("add")
    refute_nil Ruflet::CupertinoIconLookup.codepoint_for(:search)
  end

  def test_icons_groups_expose_material_and_cupertino
    assert_equal Ruflet::MaterialIcons::ADD, Ruflet::Icons.material[:add]
    assert_equal Ruflet::CupertinoIcons::ADD, Ruflet::Icons.cupertino[:add]
  end
end

# frozen_string_literal: true

require_relative "test_helper"

# A Ruflet::Control built without its class (Ruflet::Control.new(type: ...))
# takes its wire type from ControlRegistry::TYPE_MAP. These entries still held
# the names older Flet clients used ("c", "r", "windowDragArea",
# "dropdownoption"), so such a control sent a different wire type from the
# class-built one. The engine renders no "windowDragArea" (it shows "Unknown
# control"); DataTable and Dropdown read their rows, cells, columns and
# options by slot without checking the type, so the other five still
# rendered and only their `_c` changes.
class UntypedControlWireTypeTest < Minitest::Test
  {
    "datacell" => "DataCell",
    "datacolumn" => "DataColumn",
    "datarow" => "DataRow",
    "windowdragarea" => "WindowDragArea",
    "option" => "Option",
    "dropdownoption" => "DropdownOption"
  }.each do |type, wire|
    define_method("test_untyped_#{type}_sends_#{wire}") do
      assert_equal wire, Ruflet::Control.new(type: type).to_patch["_c"]
      assert_equal wire, Ruflet::UI::ControlFactory.build(type, **required_props(type)).to_patch["_c"]
    end
  end

  private

  def required_props(type)
    case type
    when "datacell" then { content: Ruflet.text("1") }
    when "datacolumn" then { label: Ruflet.text("Name") }
    when "windowdragarea" then { content: Ruflet.text("Drag") }
    else {}
    end
  end
end

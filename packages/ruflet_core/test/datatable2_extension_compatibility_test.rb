# frozen_string_literal: true

require_relative "test_helper"

class DataTable2ExtensionCompatibilityTest < Minitest::Test
  def test_datatable2_family_uses_current_flet_wire_types
    column = Ruflet.data_column2(Ruflet.text("Name"), fixed_width: 160, size: :medium)
    row = Ruflet.data_row2([Ruflet.data_cell(Ruflet.text("Ruby"))], specific_row_height: 48, on_tap: ->(_event) {})
    table = Ruflet.data_table2(
      [column],
      rows: [row],
      fixed_left_columns: 1,
      visible_horizontal_scroll_bar: true
    )

    patch = table.to_patch
    assert_equal "DataTable2", patch["_c"]
    assert_equal "DataColumn2", patch["columns"].first["_c"]
    assert_equal "DataRow2", patch["rows"].first["_c"]
    assert_equal "medium", patch["columns"].first["size"]
    assert row.has_handler?(:tap)
  end
end

# frozen_string_literal: true

require_relative "test_helper"

class RufletDataTableCompatibilityTest < Minitest::Test
  def test_data_table_helpers_serialize_current_flet_props
    table = Ruflet.data_table(
      [
        Ruflet.data_column("Name", heading_row_alignment: "center", tooltip: "Full name", on_sort: ->(_event) {}),
        Ruflet.data_column(Ruflet.text("Age"), numeric: true)
      ],
      rows: [
        Ruflet.data_row(
          [
            Ruflet.data_cell("Alice", placeholder: false, show_edit_icon: true, on_tap: ->(_event) {}),
            Ruflet.data_cell(Ruflet.text("42"))
          ],
          color: { selected: "#ABCDEF" },
          selected: true,
          on_long_press: ->(_event) {},
          on_select_change: ->(_event) {}
        )
      ],
      bgcolor: "#111111",
      border: { top: { width: 1 } },
      border_radius: 8,
      checkbox_horizontal_margin: 12,
      clip_behavior: "antiAlias",
      column_spacing: 32,
      data_row_color: { hovered: "#222222" },
      data_row_max_height: 64,
      data_row_min_height: 48,
      data_text_style: { size: 14 },
      divider_thickness: 1,
      gradient: { colors: ["#333333", "#444444"] },
      heading_row_color: { selected: "#555555" },
      heading_row_height: 56,
      heading_text_style: { weight: "bold" },
      horizontal_lines: { color: "#666666", width: 1 },
      horizontal_margin: 24,
      show_bottom_border: true,
      show_checkbox_column: true,
      sort_ascending: false,
      sort_column_index: 1,
      vertical_lines: { color: "#777777", width: 1 },
      on_select_all: ->(_event) {}
    )

    patch = table.to_patch

    assert_equal "DataTable", patch["_c"]
    assert_equal "#111111", patch["bgcolor"]
    assert_equal({ "top" => { "width" => 1 } }, patch["border"])
    assert_equal 8, patch["border_radius"]
    assert_equal 12, patch["checkbox_horizontal_margin"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal 32, patch["column_spacing"]
    assert_equal({ "hovered" => "#222222" }, patch["data_row_color"])
    assert_equal 64, patch["data_row_max_height"]
    assert_equal 48, patch["data_row_min_height"]
    assert_equal({ "size" => 14 }, patch["data_text_style"])
    assert_equal 1, patch["divider_thickness"]
    assert_equal({ "colors" => ["#333333", "#444444"] }, patch["gradient"])
    assert_equal({ "selected" => "#555555" }, patch["heading_row_color"])
    assert_equal 56, patch["heading_row_height"]
    assert_equal({ "weight" => "bold" }, patch["heading_text_style"])
    assert_equal({ "color" => "#666666", "width" => 1 }, patch["horizontal_lines"])
    assert_equal 24, patch["horizontal_margin"]
    assert_equal true, patch["show_bottom_border"]
    assert_equal true, patch["show_checkbox_column"]
    assert_equal false, patch["sort_ascending"]
    assert_equal 1, patch["sort_column_index"]
    assert_equal({ "color" => "#777777", "width" => 1 }, patch["vertical_lines"])
    assert_equal true, patch["on_select_all"]

    first_column, second_column = patch["columns"]
    assert_equal "DataColumn", first_column["_c"]
    assert_equal "Name", first_column["label"]
    assert_equal "center", first_column["heading_row_alignment"]
    assert_equal "Full name", first_column["tooltip"]
    assert_equal true, first_column["on_sort"]
    assert_equal "Text", second_column["label"]["_c"]
    assert_equal true, second_column["numeric"]

    row = patch["rows"].first
    assert_equal "DataRow", row["_c"]
    assert_equal({ "selected" => "#ABCDEF" }, row["color"])
    assert_equal true, row["selected"]
    assert_equal true, row["on_long_press"]
    assert_equal true, row["on_select_change"]

    first_cell, second_cell = row["cells"]
    assert_equal "DataCell", first_cell["_c"]
    assert_equal "Alice", first_cell["content"]
    assert_equal false, first_cell["placeholder"]
    assert_equal true, first_cell["show_edit_icon"]
    assert_equal true, first_cell["on_tap"]
    assert_equal "Text", second_cell["content"]["_c"]
  end

  def test_compact_aliases_use_same_controls
    assert_equal "DataTable", Ruflet.datatable([Ruflet.datacolumn("Name")]).to_patch["_c"]
    assert_equal "DataColumn", Ruflet.datacolumn("Name").to_patch["_c"]
    assert_equal "DataRow", Ruflet.datarow([Ruflet.datacell("Alice")]).to_patch["_c"]
    assert_equal "DataCell", Ruflet.datacell("Alice").to_patch["_c"]
  end

  def test_data_table_requires_visible_columns_like_flet
    error = assert_raises(ArgumentError) { Ruflet.data_table([]) }

    assert_match(/columns/, error.message)
  end

  def test_data_table_requires_row_cell_count_to_match_visible_columns_like_flet
    columns = [Ruflet.data_column("Name"), Ruflet.data_column("Age")]

    error = assert_raises(ArgumentError) do
      Ruflet.data_table(columns, rows: [Ruflet.data_row([Ruflet.data_cell("Alice")])])
    end

    assert_match(/cells/, error.message)
  end

  def test_data_column_and_cell_require_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.data_column }
    assert_raises(ArgumentError) { Ruflet.data_column(Ruflet.text("Hidden", visible: false)) }
    assert_raises(ArgumentError) { Ruflet.data_cell }
    assert_raises(ArgumentError) { Ruflet.data_cell(Ruflet.text("Hidden", visible: false)) }
  end

  def test_data_table_rejects_negative_numeric_values_like_flet
    columns = [Ruflet.data_column("Name")]

    %i[
      checkbox_horizontal_margin
      column_spacing
      data_row_max_height
      data_row_min_height
      divider_thickness
      heading_row_height
      horizontal_margin
    ].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.data_table(columns, prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_data_row_select_change_updates_selected_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    row = Ruflet.data_row(
      [Ruflet.data_cell("Alice")],
      selected: false,
      on_select_change: ->(event) { observed << [event.value, event.control.props["selected"]] }
    )
    table = Ruflet.data_table([Ruflet.data_column("Name")], rows: [row])
    page.add(table)

    page.dispatch_event(target: row.wire_id, name: "select_change", data: { "value" => true })

    assert_equal true, row.props["selected"]
    assert_equal [[true, true]], observed
  end
end

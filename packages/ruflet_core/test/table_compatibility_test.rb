# frozen_string_literal: true

require_relative "test_helper"

class RufletTableCompatibilityTest < Minitest::Test
  def test_table_serializes_rows_cells_and_props
    control = Ruflet.table(
      [
        Ruflet.table_row([Ruflet.text("Item"), Ruflet.text("Qty")], bgcolor: "#EEEEEE"),
        Ruflet.table_row([Ruflet.text("Apple"), Ruflet.text("3")])
      ],
      column_widths: { 0 => { type: "flex", value: 2 }, 1 => { type: "fixed", value: 80 } },
      default_column_width: { type: "intrinsic" },
      border_color: "outlineVariant",
      border_width: 1.5,
      border_radius: 8,
      inner_borders: false,
      default_vertical_alignment: "middle",
      cell_padding: 8,
      width: 320
    )

    patch = control.to_patch

    assert_equal "Table", patch["_c"]
    assert_equal({ "0" => { "type" => "flex", "value" => 2 }, "1" => { "type" => "fixed", "value" => 80 } },
                 patch["column_widths"])
    assert_equal({ "type" => "intrinsic" }, patch["default_column_width"])
    assert_equal "outlinevariant", patch["border_color"]
    assert_equal 1.5, patch["border_width"]
    assert_equal 8, patch["border_radius"]
    assert_equal false, patch["inner_borders"]
    assert_equal "middle", patch["default_vertical_alignment"]
    assert_equal 8, patch["cell_padding"]
    assert_equal 320, patch["width"]
    refute patch.key?("controls")

    header, body = patch["rows"]
    assert_equal %w[TableRow TableRow], [header["_c"], body["_c"]]
    assert_equal "#eeeeee", header["bgcolor"]
    assert_equal %w[Item Qty], header["controls"].map { |cell| cell["value"] }
    assert_equal %w[Apple 3], body["controls"].map { |cell| cell["value"] }
  end

  def test_block_children_and_aliases
    control = Ruflet.table do
      table_row do
        text("A")
        text("B")
      end
      tablerow { text("C") }
    end

    patch = control.to_patch
    assert_equal %w[TableRow TableRow], patch["controls"].map { |row| row["_c"] }
    assert_equal %w[A B], patch["controls"].first["controls"].map { |cell| cell["value"] }
    assert_equal %w[C], patch["controls"].last["controls"].map { |cell| cell["value"] }
    refute patch.key?("rows")
  end

  def test_generic_and_dsl_helpers
    assert_equal "Table", Ruflet.control(:table).to_patch["_c"]
    assert_equal "TableRow", Ruflet.control(:table_row).to_patch["_c"]
    assert_equal "TableRow", Ruflet.tablerow(controls: [Ruflet.text("x")]).to_patch["_c"]
    assert_equal "tablerow", Ruflet.table_row.type
    assert_respond_to Ruflet::DSL, :table
    assert_respond_to Ruflet::DSL, :table_row
    assert_respond_to Ruflet::DSL, :tablerow
  end

  def test_renderer_defaults_are_not_sent
    patch = Ruflet.table([]).to_patch

    assert_equal [], patch["rows"]
    %w[column_widths default_column_width border_color border_width inner_borders
       default_vertical_alignment cell_padding].each { |key| refute patch.key?(key), key }
  end

  def test_layout_events_are_registered
    control = Ruflet.table([], on_size_change: ->(_e) {})

    assert control.has_handler?(:size_change)
  end

  def test_unknown_keywords_raise
    assert_raises(ArgumentError) { Ruflet.table([], columns: []) }
    assert_raises(ArgumentError) { Ruflet.table_row([], height: 40) }
    assert_raises(ArgumentError) { Ruflet.table_row([], on_click: ->(_e) {}) }
  end
end

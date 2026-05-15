# frozen_string_literal: true

require_relative "test_helper"

class RufletProgressCompatibilityTest < Minitest::Test
  def test_progress_bar_serializes_current_flet_props
    progress = Ruflet.progress_bar(
      value: 0.8,
      bar_height: 6,
      bgcolor: "#ABCDEF",
      border_radius: { all: 4 },
      color: "#123456",
      semantics_label: "Loading",
      semantics_value: 0.8,
      stop_indicator_color: "#222222",
      stop_indicator_radius: 3,
      track_gap: 2,
      year_2023: false
    )

    patch = progress.to_patch

    assert_equal "ProgressBar", patch["_c"]
    assert_equal 0.8, patch["value"]
    assert_equal 6, patch["bar_height"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal({ "all" => 4 }, patch["border_radius"])
    assert_equal "#123456", patch["color"]
    assert_equal "Loading", patch["semantics_label"]
    assert_equal 0.8, patch["semantics_value"]
    assert_equal "#222222", patch["stop_indicator_color"]
    assert_equal 3, patch["stop_indicator_radius"]
    assert_equal 2, patch["track_gap"]
    assert_equal false, patch["year_2023"]
  end

  def test_progress_ring_serializes_current_flet_props_and_aliases
    progress = Ruflet.progress_ring(
      value: 0.4,
      bgcolor: "#ABCDEF",
      color: "#123456",
      padding: 8,
      semantics_label: "Loading",
      semantics_value: 0.4,
      size_constraints: { min_width: 36 },
      stroke_align: -1,
      stroke_cap: "round",
      stroke_width: 4,
      track_gap: 2,
      year_2023: false
    )

    patch = progress.to_patch

    assert_equal "ProgressRing", patch["_c"]
    assert_equal "ProgressRing", Ruflet.progressring.to_patch["_c"]
    assert_equal "ProgressBar", Ruflet.progressbar.to_patch["_c"]
    assert_equal 0.4, patch["value"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "#123456", patch["color"]
    assert_equal 8, patch["padding"]
    assert_equal "Loading", patch["semantics_label"]
    assert_equal 0.4, patch["semantics_value"]
    assert_equal({ "min_width" => 36 }, patch["size_constraints"])
    assert_equal(-1, patch["stroke_align"])
    assert_equal "round", patch["stroke_cap"]
    assert_equal 4, patch["stroke_width"]
    assert_equal 2, patch["track_gap"]
    assert_equal false, patch["year_2023"]
  end

  def test_progress_controls_omit_nil_value_for_indeterminate_state
    refute Ruflet.progress_bar.to_patch.key?("value")
    refute Ruflet.progress_ring.to_patch.key?("value")
  end

  def test_progress_bar_rejects_negative_numeric_values_like_flet
    %i[bar_height semantics_value stop_indicator_radius track_gap].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.progress_bar(prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_progress_ring_rejects_negative_numeric_values_like_flet
    %i[semantics_value stroke_width track_gap].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.progress_ring(prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end
end

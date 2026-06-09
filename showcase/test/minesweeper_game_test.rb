# frozen_string_literal: true

require "minitest/autorun"

class MinesweeperGameTest < Minitest::Test
  def setup
    @source = File.read(File.expand_path("../sections_minesweeper.rb", __dir__))
  end

  def test_minesweeper_matches_flet_interaction_surface
    assert_includes @source, "on_right_pan_start"
    assert_includes @source, "on_long_press_start"
    assert_includes @source, "on_click: ->"
  end

  def test_minesweeper_tracks_end_states_and_reset
    assert_includes @source, "game_over"
    assert_includes @source, "won"
    assert_includes @source, "exploded"
    assert_includes @source, "reset_game"
  end

  def test_minesweeper_checks_for_win_after_reveal
    assert_match(/all\?\s*\{\s*\|s\|\s*s\[:revealed\]\s*\|\|\s*s\[:mine\]\s*\}/, @source)
  end
end

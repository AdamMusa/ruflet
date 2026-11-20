# frozen_string_literal: true

require_relative "test_helper"

# Datetimes are stored as UTC wall-clock text and read back as UTC. A Time
# with another offset was stored with its local wall clock, and a string's
# offset was ignored, so both came back hours off.
class TimeZoneTest < RufletRecordTestCase
  def test_a_time_with_an_offset_is_stored_as_the_same_instant
    user = User.create!(name: "Ada")
    written = Time.new(2026, 1, 1, 10, 0, 0, "+02:00")

    user.update!(created_at: written)

    assert_equal written, user.created_at
    assert_equal 7200, user.created_at.utc_offset, "an assigned Time is kept as given"
    assert_equal Time.utc(2026, 1, 1, 8, 0, 0), User.find(user.id).created_at
  end

  def test_a_string_offset_is_applied
    user = User.new(name: "Ada")

    user.created_at = "2026-01-01T10:00:00+02:00"
    assert_equal Time.utc(2026, 1, 1, 8, 0, 0), user.created_at

    user.created_at = "2026-01-01 10:00:00-05:30"
    assert_equal Time.utc(2026, 1, 1, 15, 30, 0), user.created_at

    user.created_at = "2026-01-01T10:00:00.250Z"
    assert_equal Time.utc(2026, 1, 1, 10, 0, 0), user.created_at

    user.created_at = "2026-01-01T10:00:00.250+02:00"
    assert_equal Time.utc(2026, 1, 1, 8, 0, 0), user.created_at, "fractional seconds before an offset"

    user.created_at = "2026-01-01 10:00:00 +0200"
    assert_equal Time.utc(2026, 1, 1, 8, 0, 0), user.created_at, "Time#to_s format"

    user.created_at = "2026-01-01 10:00:00"
    assert_equal Time.utc(2026, 1, 1, 10, 0, 0), user.created_at, "no offset means UTC, as stored"
  end

  def test_where_finds_a_record_by_a_time_in_another_offset
    user = User.create!(name: "Ada", created_at: Time.utc(2026, 5, 1, 12, 0, 0))

    assert_equal [user.id], User.where(created_at: Time.new(2026, 5, 1, 14, 0, 0, "+02:00")).ids
  end
end

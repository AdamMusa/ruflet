# frozen_string_literal: true

require "minitest/autorun"

class ServiceUsageTest < Minitest::Test
  def test_audio_recorder_sample_exercises_recording_lifecycle
    source = read_studio_file("sections_media/audio_recorder.rb")

    assert_includes source, "page.get_application_documents_directory"
    assert_includes source, "recording_path = File.join"
    assert_includes source, "FileUtils.touch"
    assert_includes source, "recorder.has_permission"
    assert_includes source, "recorder.start_recording"
    assert_includes source, "recorder.stop_recording"
    assert_includes source, "recorder.cancel_recording"
  end

  def test_audio_sample_reports_release_completion
    source = read_studio_file("sections_media/audio.rb")

    assert_includes source, 'Audio #{label} complete'
    assert_includes source, "audio.release"
  end

  def test_geolocator_sample_requests_permission_and_position
    source = read_studio_file("sections_media/geolocator.rb")

    assert_includes source, "geo.request_permission"
    assert_includes source, "geo.get_current_position"
    assert_includes source, "geo.open_location_settings"
  end

  def test_permission_handler_sample_requests_real_permissions
    source = read_studio_file("sections_media/permission_handler.rb")

    assert_includes source, "permission_handler_platform?(page)"
    assert_includes source, "permissions.request(\"microphone\""
    assert_includes source, "permissions.request(\"camera\""
    assert_includes source, "permissions.get_status(\"microphone\""
  end

  def test_map_sample_has_visible_size_and_live_map_layers
    source = read_studio_file("sections_media/map.rb")

    assert_includes source, "tile_layer("
    refute_includes source, 'alignment: "bottom_right"'
    assert_includes source, "height: 520"
    assert_includes source, "map_control.center_on"
  end

  private

  def read_studio_file(relative_path)
    File.read(File.expand_path("../#{relative_path}", __dir__))
  end
end

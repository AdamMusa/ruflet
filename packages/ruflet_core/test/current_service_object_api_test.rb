# frozen_string_literal: true

require_relative "test_helper"

class CurrentServiceObjectApiTest < Minitest::Test
  EXPECTED_METHODS = {
    battery: %i[get_battery_level get_battery_state is_in_battery_save_mode],
    connectivity: %i[get_connectivity],
    file_picker: %i[upload get_directory_path save_file pick_files],
    flashlight: %i[on off is_available],
    haptic_feedback: %i[heavy_impact light_impact medium_impact vibrate selection_click],
    screen_brightness: %i[get_system_screen_brightness can_change_system_screen_brightness set_system_screen_brightness get_application_screen_brightness set_application_screen_brightness reset_application_screen_brightness is_animate set_animate is_auto_reset set_auto_reset],
    share: %i[share_text share_uri share_files],
    shared_preferences: %i[set get contains_key remove get_keys clear],
    storage_paths: %i[get_application_cache_directory get_application_documents_directory get_application_support_directory get_downloads_directory get_external_cache_directories get_external_storage_directories get_library_directory get_external_storage_directory get_temporary_directory get_console_log_filename],
    url_launcher: %i[launch_url can_launch_url close_in_app_web_view open_window supports_launch_mode supports_close_for_launch_mode],
    wakelock: %i[enable disable is_enabled]
  }.freeze

  def test_current_flet_service_methods_are_available_on_service_objects
    EXPECTED_METHODS.each do |service_name, method_names|
      service = Ruflet::UI::ControlFactory.build(service_name.to_s)
      method_names.each { |method_name| assert_respond_to service, method_name }
    end
  end

  def test_service_methods_use_current_flet_wire_arguments
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    picker = page.service(:file_picker)
    picker.pick_files(file_type: :image, allow_multiple: true, with_data: true)
    assert_equal "pick_files", sent.last[1]["name"]
    assert_equal "image", sent.last[1].dig("args", "file_type")
    assert_equal true, sent.last[1].dig("args", "with_data")

    share = page.service(:share)
    share.share_files([{ name: "tiny.bin", data: [1, 2, 3] }], title: "Bytes")
    assert_equal "share_files", sent.last[1]["name"]
    assert_equal "\x01\x02\x03".b, sent.last[1].dig("args", "files", 0, "data")

    launcher = page.service(:url_launcher)
    launcher.launch_url("https://flet.dev", mode: :external_application)
    assert_equal "external_application", sent.last[1].dig("args", "mode")
  end
end

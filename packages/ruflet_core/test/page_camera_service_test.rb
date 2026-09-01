# frozen_string_literal: true

require_relative "test_helper"

class PageCameraServiceTest < Minitest::Test
  def test_camera_returns_mountable_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    camera = page.camera(preview_enabled: true, on_error: ->(_event) {})

    assert_equal "camera", camera.type
    assert_equal "Camera", camera.to_patch["_c"]
    assert_equal true, camera.props["preview_enabled"]
    assert_equal true, camera.props["on_error"]
    assert camera.has_handler?(:error)
    assert_same camera, page.service(:camera)
  end

  def test_camera_helper_keeps_visual_service_out_of_services_list
    sent = []
    page = build_page(sent)

    camera = page.camera(preview_enabled: true)
    page.add(Ruflet.container(content: camera))

    payload = sent.last[1]
    services_patch = payload["patch"].find { |op| op[2] == "_services" }
    assert_equal [], services_patch[3]["_services"]
  end

  def test_camera_exposes_the_complete_current_flet_method_surface
    sent = []
    page = build_page(sent)
    camera = page.camera
    page.add(camera)

    camera.initialize_camera(
      { name: "Back", lens_direction: :back, sensor_orientation: 90 },
      :high,
      fps: 30,
      image_format_group: :jpeg
    )
    initialize_payload = sent.last[1]
    assert_equal "initialize", initialize_payload["name"]
    assert_equal "back", initialize_payload.dig("args", "description", "lens_direction")
    assert_equal "high", initialize_payload.dig("args", "resolution_preset")
    assert_equal "jpeg", initialize_payload.dig("args", "image_format_group")

    camera.lock_capture_orientation(:portrait_up)
    assert_equal "lock_capture_orientation", sent.last[1]["name"]
    assert_equal({ "orientation" => "portrait_up" }, sent.last[1]["args"])

    camera.set_zoom_level(2.5)
    assert_equal "set_zoom_level", sent.last[1]["name"]
    assert_equal({ "zoom" => 2.5 }, sent.last[1]["args"])

    camera.take_picture
    assert_equal "take_picture", sent.last[1]["name"]
  end

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end
end

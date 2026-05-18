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

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end
end

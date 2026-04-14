# frozen_string_literal: true

require_relative "test_helper"

class PageUpdateSerializationTest < Minitest::Test
  def test_initial_view_and_controls_serialize_as_flet_wire_types
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.add(Ruflet.container(content: Ruflet.text(value: "x")))

    payload = sent.last[1]
    views_patch = payload["patch"].find { |op| op[2] == "views" }
    refute_nil views_patch

    view = views_patch[3].first
    assert_equal "View", view["_c"]
    assert_equal "Container", view["controls"].first["_c"]
    assert_equal "Text", view["controls"].first["content"]["_c"]
  end

  def test_snake_case_dsl_helper_serializes_to_flet_wire_type
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    page.add(Ruflet::Control.new(type: :auto_complete, suggestions: []))

    payload = sent.last[1]
    views_patch = payload["patch"].find { |op| op[2] == "views" }
    refute_nil views_patch

    control = views_patch[3].first["controls"].first
    assert_equal "AutoComplete", control["_c"]
  end

  def test_service_registry_has_uid_internal_for_client_binding_refresh
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.add(Ruflet.text(value: "x"))

    page_patch = sent.last[1]["patch"]
    services_patch = page_patch.find { |op| op[2] == "_services" }
    refute_nil services_patch

    services_value = services_patch[3]
    refute_nil services_value["_internals"]
    refute_nil services_value["_internals"]["uid"]
  end

  def test_update_serializes_embedded_controls
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    grid = Ruflet.grid_view
    page.add(grid)
    tile = Ruflet.container(content: Ruflet.text(value: "A"))

    page.update(grid, controls: [tile])

    payload = sent.last[1]
    controls_patch = payload["patch"].find { |op| op[2] == "controls" }
    refute_nil controls_patch

    controls_value = controls_patch[3]
    assert_instance_of Array, controls_value
    assert_instance_of Hash, controls_value.first
    assert_equal "Container", controls_value.first["_c"]
    refute_nil controls_value.first["_i"]
  end

  def test_update_accepts_children_alias_and_patches_controls
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    grid = Ruflet.grid_view
    page.add(grid)
    tile = Ruflet.container(content: Ruflet.text(value: "B"))

    page.update(grid, children: [tile])

    payload = sent.last[1]
    controls_patch = payload["patch"].find { |op| op[2] == "controls" }
    refute_nil controls_patch
    refute payload["patch"].any? { |op| op[2] == "children" }

    controls_value = controls_patch[3]
    assert_instance_of Array, controls_value
    assert_instance_of Hash, controls_value.first
    assert_equal "Container", controls_value.first["_c"]
  end

  def test_update_controls_survive_index_refresh_after_service_add
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    clicked = []
    grid = Ruflet.grid_view
    page.add(grid)

    tile = Ruflet.container(on_click: ->(_e) { clicked << :ok })
    page.update(grid, controls: [tile])
    refute_nil tile.wire_id

    page.add_service(Ruflet.clipboard)
    page.dispatch_event(target: tile.wire_id, name: "click", data: nil)

    assert_equal [:ok], clicked
  end

  def test_page_add_serializes_floating_action_button_icon_for_dev_mode
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    count = 0
    count_text = Ruflet.text(count.to_s, style: { size: 40 })

    page.add(
      Ruflet.container(
        expand: true,
        alignment: Ruflet::MainAxisAlignment::CENTER,
        content: Ruflet.column(
          alignment: Ruflet::MainAxisAlignment::CENTER,
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          children: [
            Ruflet.text("A self-contained ruflet app up and running!"),
            count_text
          ]
        )
      ),
      appbar: Ruflet.app_bar(title: Ruflet.text("Ruflet demo", style: { size: 18 })),
      floating_action_button: Ruflet.fab(
        icon: Ruflet::MaterialIcons::ADD,
        on_click: ->(_e) do
          count += 1
          page.update(count_text, value: count.to_s)
        end
      )
    )

    payload = sent.last[1]
    views_patch = payload["patch"].find { |op| op[2] == "views" }
    refute_nil views_patch

    view = views_patch[3].first
    fab = view["floating_action_button"]

    refute_nil fab
    assert_equal "FloatingActionButton", fab["_c"]
    assert_equal Ruflet::MaterialIcons::ADD.value, fab["icon"]
    assert_equal true, fab["on_click"]
  end

end

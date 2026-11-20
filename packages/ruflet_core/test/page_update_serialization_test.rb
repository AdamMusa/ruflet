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

  def test_service_registry_is_not_replaced_after_initial_mount
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.add(Ruflet.text(value: "x"))
    page.title = "Updated title"
    page.update

    page_patch = sent.last[1]["patch"]
    refute page_patch.any? { |op| op[2] == "_services" }
  end

  def test_reconnect_republishes_page_shell_and_internal_roots
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.add(Ruflet.text(value: "Still here"))
    page.show_dialog(Ruflet.alert_dialog(title: Ruflet.text("Still open")))

    sent.clear
    page.prepare_for_reconnect!
    page.update

    assert_equal 1, sent.length
    payload = sent.first[1]
    assert_equal 1, payload["id"]
    assert payload["patch"].any? { |op| op[2] == "views" }
    assert payload["patch"].any? { |op| op[2] == "_overlay" }
    assert payload["patch"].any? { |op| op[2] == "_dialogs" }
    assert payload["patch"].any? { |op| op[2] == "_services" }
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

  def test_camera_service_helper_returns_mountable_camera_control
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    camera = page.service(:camera, preview_enabled: true)
    assert_same camera, page.service(:camera)
    page.add(Ruflet.container(content: camera))

    payload = sent.last[1]
    services_patch = payload["patch"].find { |op| op[2] == "_services" }
    assert_equal [], services_patch[3]["_services"]

    views_patch = payload["patch"].find { |op| op[2] == "views" }
    camera_patch = views_patch[3].first["controls"].first["content"]
    assert_equal "Camera", camera_patch["_c"]
    assert_equal true, camera_patch["preview_enabled"]
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

    page.appbar = Ruflet.app_bar(title: Ruflet.text("Ruflet demo", style: { size: 18 }))
    page.floating_action_button = Ruflet.fab(
      icon: Ruflet::MaterialIcons::ADD,
      on_click: ->(_e) do
        count += 1
        page.update(count_text, value: count.to_s)
      end
    )
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
      )
    )

    payload = sent.last[1]
    views_patch = payload["patch"].find { |op| op[2] == "views" }
    refute_nil views_patch

    view = views_patch[3].first
    fab = view["floating_action_button"]

    refute_nil fab
    assert_equal "FloatingActionButton", fab["_c"]
    assert_equal 65604, fab["icon"]
    assert_equal true, fab["on_click"]
  end

  def test_bare_update_patches_only_the_nested_control_whose_children_changed
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    list = Ruflet.column(children: [Ruflet.text("First")])
    page.add(Ruflet.container(content: list))

    sent.clear
    list.children.replace([Ruflet.text("Second"), Ruflet.text("Third")])
    page.update

    assert_equal 1, sent.length
    payload = sent.first[1]
    assert_equal list.wire_id, payload["id"]
    refute payload["patch"].any? { |op| op[2] == "views" }
    controls_patch = payload["patch"].find { |op| op[2] == "controls" }
    assert_equal %w[Second Third], controls_patch[3].map { |control| control["value"] }
  end

  def test_bare_update_patches_a_mutated_leaf_without_replacing_ancestors
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    label = Ruflet.text("Before")
    page.add(Ruflet.container(content: Ruflet.column(children: [label])))

    sent.clear
    label.props["value"] = "After"
    page.update

    assert_equal 1, sent.length
    payload = sent.first[1]
    assert_equal label.wire_id, payload["id"]
    assert_equal [[0], [0, 0, "value", "After"]], payload["patch"]
  end

  def test_client_value_is_not_echoed_by_a_later_bare_update
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    label = Ruflet.text("Waiting")
    field = Ruflet.text_field(
      on_change: ->(event) do
        label.props["value"] = event.value
        page.update
      end
    )
    page.add(Ruflet.column(children: [field, label]))

    sent.clear
    page.dispatch_event(target: field.wire_id, name: "change", data: "Typed")

    assert_equal 1, sent.length
    payload = sent.first[1]
    assert_equal label.wire_id, payload["id"]
    assert_equal [[0], [0, 0, "value", "Typed"]], payload["patch"]
  end

  def test_targeted_update_accepts_the_controls_own_children_array
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    list = Ruflet.column(children: [Ruflet.text("First")])
    page.add(list)
    second = Ruflet.text("Second")
    list.children << second

    page.update(list, controls: list.children)

    assert_equal 2, list.children.length
    assert_same second, list.children.last
    controls_patch = sent.last[1]["patch"].find { |op| op[2] == "controls" }
    assert_equal %w[First Second], controls_patch[3].map { |control| control["value"] }
  end

  # Issue #105: page.update(col, controls: [...]) left a second copy of the
  # list in col.props, and to_patch sent it again once children was emptied.
  def test_children_emptied_after_targeted_update_stay_empty_in_a_full_patch
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    todo = Ruflet.column(controls: [])
    page.add(todo)

    page.update(todo, controls: [Ruflet.text("milk"), Ruflet.text("eggs")])
    todo.children.clear
    sent.clear
    page.update
    assert_equal [[[0], [0, 0, "controls", []]]], sent.map { |_, payload| payload["patch"] }

    sent.clear
    page.title = "Done"
    page.update
    views_patch = sent.last[1]["patch"].find { |op| op[2] == "views" }
    column = views_patch[3].first["controls"].first
    assert_equal todo.wire_id, column["_i"]
    assert_empty Array(column["controls"])
    assert_empty Array(todo.to_patch["controls"])
    refute todo.props.key?("controls")
  end

  def test_children_emptied_after_children_alias_update_stay_empty_in_the_parent_patch
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    todo = Ruflet.column(controls: [])
    outer = Ruflet.column(controls: [todo])
    page.add(outer)

    page.update(todo, children: [Ruflet.text("milk"), Ruflet.text("eggs")])
    todo.children.replace([])
    page.update
    outer.children << Ruflet.text("All done")
    sent.clear
    page.update

    assert_equal 1, sent.length
    assert_equal outer.wire_id, sent.first[1]["id"]
    controls_patch = sent.first[1]["patch"].find { |op| op[2] == "controls" }
    assert_equal ["Column", "Text"], controls_patch[3].map { |control| control["_c"] }
    assert_empty Array(controls_patch[3].first["controls"])
  end

  def test_control_removed_after_targeted_update_is_no_longer_patched
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    list = Ruflet.column(controls: [])
    page.add(list)
    removed = Ruflet.text("gone")
    page.update(list, controls: [removed])
    list.children.clear
    page.update

    sent.clear
    removed.props["value"] = "still gone"
    page.update

    assert_empty sent
  end

  def test_bare_update_after_targeted_update_with_own_children_sends_the_list_once
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    list = Ruflet.column(children: [Ruflet.text("First")])
    page.add(list)
    page.update(list, controls: list.children)

    sent.clear
    list.children << Ruflet.text("Second")
    page.update

    assert_equal 1, sent.length
    controls_ops = sent.first[1]["patch"].select { |op| op[2] == "controls" }
    assert_equal 1, controls_ops.length
    assert_equal %w[First Second], controls_ops.first[3].map { |control| control["value"] }
  end

  def test_targeted_update_with_a_list_holding_no_controls_still_serializes_it
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    empty = Ruflet.column(controls: [])
    raw = Ruflet.column(controls: [])
    page.add(Ruflet.column(controls: [empty, raw]))
    raw_child = { "_c" => "Text", "value" => "raw" }

    page.update(empty, controls: [])
    page.update(raw, controls: [raw_child])

    assert_equal [], empty.to_patch["controls"]
    assert_equal [raw_child], raw.to_patch["controls"]
  end

  def test_children_emptied_after_targeted_update_with_a_mixed_list_stay_empty_in_a_full_patch
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    todo = Ruflet.column(controls: [])
    page.add(todo)

    page.update(todo, controls: [Ruflet.text("milk"), { "_c" => "Text", "value" => "raw" }])
    todo.children.clear
    page.update
    sent.clear
    page.title = "Done"
    page.update

    views_patch = sent.last[1]["patch"].find { |op| op[2] == "views" }
    column = views_patch[3].first["controls"].first
    assert_equal todo.wire_id, column["_i"]
    assert_empty Array(column["controls"])
    refute todo.props.key?("controls")
  end

  # Behavior change of the #105 fix: page.update(col, controls: list) copies
  # the Controls into col.children, as column(controls: list) always has, so a
  # later change to the app's own `list` is not sent; a change to col.children
  # is. Before the fix that change reached the client from a props copy only,
  # and the next full patch, built from children, dropped it again.
  def test_targeted_update_keeps_its_own_copy_of_the_passed_list
    %i[controls children].each do |keyword|
      sent = []
      page = Ruflet::Page.new(
        session_id: "s1",
        client_details: { "route" => "/" },
        sender: ->(action, payload) { sent << [action, payload] }
      )
      list = Ruflet.column(controls: [])
      page.add(list)
      items = [Ruflet.text("first")]
      page.update(list, keyword => items)

      items << Ruflet.text("second")
      sent.clear
      page.update
      assert_empty sent, "#{keyword}: appending to the passed Array"
      items.clear
      page.update
      assert_empty sent, "#{keyword}: clearing the passed Array"
      assert_equal %w[first], list.children.map { |control| control.props["value"] }
      refute list.props.key?("controls")

      page.title = "Full"
      page.update
      views_patch = sent.last[1]["patch"].find { |op| op[2] == "views" }
      column = views_patch[3].first["controls"].first
      assert_equal %w[first], column["controls"].map { |control| control["value"] }

      list.children << Ruflet.text("second")
      sent.clear
      page.update
      assert_equal [list.wire_id], sent.map { |_, payload| payload["id"] }
      controls_op = sent.first[1]["patch"].find { |op| op[2] == "controls" }
      assert_equal %w[first second], controls_op[3].map { |control| control["value"] }
    end
  end

  # A list with no Control in it stays in props as the app's own Array, so a
  # later change to it is still sent, as before the fix.
  def test_targeted_update_with_an_empty_list_still_tracks_the_passed_array
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    list = Ruflet.column(controls: [])
    page.add(list)
    items = []
    page.update(list, controls: items)

    items << Ruflet.text("e1")
    sent.clear
    page.update

    assert_equal [list.wire_id], sent.map { |_, payload| payload["id"] }
    controls_op = sent.first[1]["patch"].find { |op| op[2] == "controls" }
    assert_equal %w[e1], controls_op[3].map { |control| control["value"] }
  end

end

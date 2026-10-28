# frozen_string_literal: true

require_relative "test_helper"

# A control passed as a property (content:, title:, actions: [...], a nested
# hash, children:/controls:) belongs to the control that receives it. Inside a
# builder block the helper that created it has already attached it to the
# enclosing builder, so the builder must take it back instead of also keeping
# it as a sibling of the control that consumed it.
class RufletDslBlockPropChildrenTest < Minitest::Test
  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  # -- Ruflet.column { ... } (WidgetBuilder blocks) ---------------------------

  def test_builder_block_does_not_duplicate_content_prop
    column = Ruflet.column { container(content: text("x")) }

    assert_equal ["Container"], wire_types(column.children)
    assert_equal "x", column.children.first.to_patch["content"]["value"]
  end

  def test_builder_block_does_not_duplicate_title_and_subtitle_props
    column = Ruflet.column { list_tile(title: text("T"), subtitle: text("S")) }

    assert_equal ["ListTile"], wire_types(column.children)
    patch = column.children.first.to_patch
    assert_equal "T", patch["title"]["value"]
    assert_equal "S", patch["subtitle"]["value"]
  end

  def test_builder_block_does_not_duplicate_actions_array
    column = Ruflet.column do
      app_bar(title: text("Title"), actions: [icon_button("add"), text_button("Save")])
    end

    assert_equal ["AppBar"], wire_types(column.children)
    assert_equal %w[IconButton TextButton], column.children.first.to_patch["actions"].map { |action| action["_c"] }
  end

  def test_builder_block_does_not_duplicate_controls_in_a_deeply_nested_hash
    deep = nil
    column = Ruflet.column do
      deep = text("deep")
      container(content: text("x"), data: { rows: [{ cells: [{ value: deep }] }] })
    end

    assert_equal ["Container"], wire_types(column.children)
    refute(column.children.any? { |child| child.equal?(deep) })
  end

  def test_builder_block_does_not_duplicate_children_and_controls_props
    column = Ruflet.column do
      row(controls: [text("a"), text("b")])
      stack(children: [text("c")])
    end

    assert_equal %w[Row Stack], wire_types(column.children)
    assert_equal %w[a b], column.children.first.children.map { |child| child.props["value"] }
    assert_equal ["c"], column.children.last.children.map { |child| child.props["value"] }
  end

  def test_builder_block_takes_back_props_at_every_nesting_level
    column = Ruflet.column { container(content: row(controls: [text("a")])) }

    assert_equal ["Container"], wire_types(column.children)
    row = column.children.first.props["content"]
    assert_equal "Row", row.to_patch["_c"]
    assert_equal ["a"], row.children.map { |child| child.props["value"] }
  end

  def test_builder_block_keeps_real_children_in_order
    column = Ruflet.column do
      text("one")
      container(content: text("two"))
      list_tile(title: text("three"))
      text("four")
    end

    assert_equal %w[Text Container ListTile Text], wire_types(column.children)
    assert_equal "one", column.children[0].props["value"]
    assert_equal "four", column.children[3].props["value"]
  end

  def test_builder_block_keeps_a_prop_control_that_is_also_returned_as_a_child_once
    shared = nil
    column = Ruflet.column do
      shared = text("shared")
      container(content: shared)
      shared
    end

    assert_equal %w[Container Text], wire_types(column.children)
    assert_equal 1, column.children.count { |child| child.equal?(shared) }
  end

  def test_builder_keeps_a_prop_control_that_is_also_an_explicit_controls_child_once
    shared = Ruflet.text("shared")
    column = Ruflet.column(controls: [shared]) { container(content: shared) }

    assert_equal %w[Container Text], wire_types(column.children)
    assert_equal 1, column.children.count { |child| child.equal?(shared) }
  end

  def test_center_block_uses_the_consuming_control_as_content
    center = Ruflet.center { container(content: text("x")) }

    assert_equal "Container", center.to_patch["content"]["_c"]
  end

  def test_page_mount_does_not_add_prop_controls_as_root_controls
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
    page.mount do
      container(content: text("x"))
      list_tile(title: text("T"))
    end

    assert_equal %w[Container ListTile], wire_types(page.controls)
  end

  # -- Ruflet::DSL app (stack-based blocks and top-level roots) --------------

  def test_app_block_does_not_duplicate_prop_controls
    app = Ruflet::DSL.app
    column = app.column do
      list_tile(title: text("T"), subtitle: text("S"))
      container(content: row(controls: [text("a")]))
    end

    assert_equal %w[ListTile Container], wire_types(column.children)
    assert_equal ["Column"], wire_types(app.instance_variable_get(:@roots))
  end

  def test_app_top_level_does_not_add_prop_controls_as_roots
    app = Ruflet::DSL.app
    app.container(content: app.text("x"))
    app.app_bar(title: app.text("T"), actions: [app.icon_button("add")])

    assert_equal %w[Container AppBar], wire_types(app.instance_variable_get(:@roots))
  end

  def test_app_page_props_do_not_become_root_controls
    app = Ruflet::DSL.app
    app.page(title: "Home", appbar: app.app_bar(title: app.text("Hi")), floating_action_button: app.floating_action_button(icon: "add"))
    app.text("body")

    assert_equal ["Text"], wire_types(app.instance_variable_get(:@roots))
    assert_equal "AppBar", app.page_props["appbar"].to_patch["_c"]
    assert_equal "FloatingActionButton", app.page_props["floating_action_button"].to_patch["_c"]
  end

  def test_app_block_keeps_real_children_in_order
    app = Ruflet::DSL.app
    column = app.column do
      text("one")
      container(content: text("two"))
      text("three")
    end

    assert_equal %w[Text Container Text], wire_types(column.children)
    assert_equal %w[one three], [column.children.first, column.children.last].map { |child| child.props["value"] }
  end

  def test_app_keeps_a_prop_control_that_is_also_an_explicit_controls_child_once
    app = Ruflet::DSL.app
    shared = app.text("shared")
    column = app.column(controls: [shared]) { container(content: shared) }

    assert_equal %w[Container Text], wire_types(column.children)
    assert_equal 1, column.children.count { |child| child.equal?(shared) }
    assert_equal ["Column"], wire_types(app.instance_variable_get(:@roots))
  end

  # -- Bare top-level DSL (Kernel forwarders -> Ruflet::DSL pending app) ------

  def test_kernel_dsl_does_not_duplicate_prop_controls
    list = column { list_tile(title: text("T"), subtitle: text("S")) }
    boxed = column { container(content: text("x")) }
    container(content: text("top"))

    assert_equal ["ListTile"], wire_types(list.children)
    assert_equal ["Container"], wire_types(boxed.children)
    assert_equal %w[Column Column Container], wire_types(Ruflet::DSL._pending_app.instance_variable_get(:@roots))
  end

  private

  def wire_types(controls)
    controls.map { |control| control.to_patch["_c"] }
  end
end

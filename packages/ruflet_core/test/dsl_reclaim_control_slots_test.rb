# frozen_string_literal: true

require "json"
require_relative "test_helper"

# A DSL block takes a control back from its implicit children only when the
# control it is passed to lays it out: a prop whose value is a control
# (content:, title:, leading:, appbar:, ...) or a list of controls (actions:,
# controls:/children:, tabs:, markers:, ...). data: is the application's own
# payload and a Hash prop is a value object, so a control referenced from
# either stays where its block put it, as it did in v0.0.23. Once a block
# returns, what it laid out is final: a later prop use of one of its controls
# (typically after the parent is mounted) never takes it out of its parent,
# and a mounted control is never taken out of the app's roots.
class RufletDslReclaimControlSlotsTest < Minitest::Test
  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  # -- data: is never a child slot --------------------------------------------

  def test_builder_block_keeps_a_control_referenced_from_data
    label = nil
    column = Ruflet.column do
      label = text("0")
      button(content: text("+"), data: { target: label })
    end

    assert_equal %w[Text Button], wire_types(column.children)
    assert_same label, column.children.first
    assert_equal "+", column.children.last.to_patch["content"]["value"]
  end

  def test_kernel_dsl_keeps_a_control_referenced_from_data
    label = nil
    list = column do
      label = text("0")
      button(content: text("+"), data: { target: label })
    end

    assert_equal %w[Text Button], wire_types(list.children)
    assert_same label, list.children.first
  end

  def test_app_block_and_app_roots_keep_a_control_referenced_from_data
    app = Ruflet::DSL.app
    top = app.text("top")
    label = nil
    column = app.column do
      label = text("0")
      button(content: text("+"), data: { target: label, top: top })
    end

    assert_equal %w[Text Button], wire_types(column.children)
    assert_same label, column.children.first
    assert_equal %w[Text Column], wire_types(app.instance_variable_get(:@roots))
  end

  def test_page_mount_keeps_a_control_referenced_from_data
    page = new_page
    page.mount do
      label = text("0")
      button(content: text("+"), data: { target: label })
    end

    assert_equal %w[Text Button], wire_types(page.controls)
  end

  def test_data_holding_a_control_or_a_list_of_controls_is_not_a_child_slot
    one = nil
    many = nil
    column = Ruflet.column do
      one = text("one")
      many = [text("a"), text("b")]
      container(content: text("c"), data: one)
      container(content: text("d"), data: many)
    end

    assert_equal %w[Text Text Text Container Container], wire_types(column.children)
    assert_same one, column.children[0]
    assert_equal many, column.children[1, 2]
  end

  def test_a_control_referenced_from_data_is_mounted_once_where_its_block_put_it
    page = new_page
    page.add(Ruflet.column do
      label = text("0")
      button(content: text("+"), data: { target: label })
    end)

    wire = JSON.generate(page.register_page_patch)
    assert_equal 1, wire.scan('"value":"+"').length
    column = page.controls.first
    assert_equal %w[Text Button], wire_types(column.children)
  end

  # -- only controls and lists of controls are child slots --------------------

  def test_reclaim_takes_back_controls_and_lists_of_controls_only
    list = []
    content, action, referenced, nested = %w[content action referenced nested].map do |value|
      Ruflet::UI::PropControls.attach(list, Ruflet.text(value))
    end

    Ruflet::UI::PropControls.reclaim(
      content: content,
      actions: [action],
      data: { target: referenced },
      style: { label: nested },
      title: "plain"
    )

    assert_equal [referenced, nested], list
  end

  # -- a block's children are final once the block returns -------------------

  def test_reusing_a_mounted_kernel_block_child_as_a_prop_does_not_change_its_parent
    page = new_page
    saved = nil
    col = column do
      saved = text("shared")
      text("other")
    end
    page.add(col)

    page.add(container(content: saved))

    assert_equal %w[shared other], col.children.map { |child| child.props["value"] }
    assert_equal %w[shared other], col.to_patch["controls"].map { |child| child["value"] }
  end

  def test_reusing_a_kernel_block_child_after_the_block_returned_keeps_it_in_its_parent
    saved = nil
    col = column do
      saved = text("shared")
      text("other")
    end

    box = container(content: saved)

    assert_equal %w[shared other], col.children.map { |child| child.props["value"] }
    assert_same saved, box.props["content"]
  end

  def test_app_and_builder_blocks_agree_once_an_inner_block_returned
    builder_t = nil
    builder = Ruflet.column do
      row { builder_t = text("x") }
      container(content: builder_t)
    end
    app_t = nil
    app = Ruflet::DSL.app
    app_column = app.column do
      row { app_t = text("x") }
      container(content: app_t)
    end

    assert_equal %w[Row Container], wire_types(builder.children)
    assert_equal ["Text"], wire_types(builder.children.first.children)
    assert_equal %w[Row Container], wire_types(app_column.children)
    assert_equal ["Text"], wire_types(app_column.children.first.children)
  end

  def test_reusing_a_mounted_block_child_as_a_prop_does_not_change_its_parent
    page = new_page
    saved = nil
    col = Ruflet.column do
      saved = text("shared")
      text("other")
    end
    page.add(col)

    page.add(Ruflet.container(content: saved))

    assert_equal %w[shared other], col.children.map { |child| child.props["value"] }
    assert_equal %w[shared other], col.to_patch["controls"].map { |child| child["value"] }
  end

  def test_a_mounted_app_root_stays_an_app_root
    app = Ruflet::DSL.app
    root = app.text("root")
    new_page.add(root)

    app.container(content: root)

    assert_includes app.instance_variable_get(:@roots), root
  end

  private

  def new_page
    Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
  end

  def wire_types(controls)
    controls.map { |control| control.to_patch["_c"] }
  end
end

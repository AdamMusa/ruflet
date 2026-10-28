# frozen_string_literal: true

require_relative "test_helper"

# `Ruflet.*` helpers called inside a builder block append to that block's
# builder, exactly like the bare helpers. Outside any block they still return
# a standalone control and touch nothing else.
class RufletDslPrefixedBlockChildrenTest < Minitest::Test
  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  def test_multiple_prefixed_children_are_kept_in_order
    column = Ruflet.column do
      Ruflet.text("a")
      Ruflet.text("b")
      Ruflet.text("c")
    end

    assert_equal %w[a b c], values(column.children)
  end

  def test_prefixed_and_bare_helpers_mix_in_order_without_duplicating_props
    column = Ruflet.column do
      Ruflet.text("a")
      text("b")
      Ruflet.container(content: Ruflet.text("c"))
      list_tile(title: Ruflet.text("d"))
      Ruflet.list_tile(title: text("e"), subtitle: Ruflet.text("f"))
    end

    assert_equal %w[Text Text Container ListTile ListTile], wire_types(column.children)
    assert_equal %w[a b], values(column.children.first(2))
    assert_equal "c", column.children[2].props["content"].props["value"]
  end

  def test_nested_prefixed_blocks_append_to_their_own_builder
    column = Ruflet.column do
      Ruflet.text("top")
      Ruflet.row do
        Ruflet.text("r1")
        Ruflet.container(content: Ruflet.column { Ruflet.text("deep1"); Ruflet.text("deep2") })
        Ruflet.text("r2")
      end
      Ruflet.text("bottom")
    end

    assert_equal %w[Text Row Text], wire_types(column.children)
    assert_equal %w[top bottom], values([column.children.first, column.children.last])
    row = column.children[1]
    assert_equal %w[Text Container Text], wire_types(row.children)
    assert_equal %w[deep1 deep2], values(row.children[1].props["content"].children)
  end

  def test_prefixed_helper_outside_any_block_has_no_side_effects
    column = Ruflet.column { Ruflet.text("a") }
    solo = Ruflet.text("solo")
    other = Ruflet.text("other")

    assert_nil Ruflet::UI::BuildScope.current
    assert_equal "Text", solo.to_patch["_c"]
    assert_equal ["a"], values(column.children)
    refute_same solo, other
    assert_empty Ruflet::DSL._pending_app.instance_variable_get(:@roots)
    assert_equal ["x"], values(Ruflet.column { Ruflet.text("x") }.children)
  end

  def test_a_raising_block_still_pops_the_scope
    assert_raises(RuntimeError) do
      Ruflet.column do
        Ruflet.text("a")
        raise "boom"
      end
    end

    assert_nil Ruflet::UI::BuildScope.current
    assert_equal "after", Ruflet.text("after").props["value"]
    assert_equal ["b"], values(Ruflet.column { Ruflet.text("b") }.children)
  end

  def test_a_rescued_inner_raise_restores_the_outer_block
    column = Ruflet.column do
      Ruflet.text("before")
      begin
        Ruflet.row do
          Ruflet.text("lost")
          raise "inner"
        end
      rescue RuntimeError
        nil
      end
      Ruflet.text("after")
    end

    assert_equal %w[before after], values(column.children)
    assert_nil Ruflet::UI::BuildScope.current
  end

  def test_other_threads_do_not_see_an_active_block
    seen = :unset
    column = Ruflet.column do
      Ruflet.text("a")
      seen = Thread.new { [Ruflet::UI::BuildScope.current, Ruflet.text("elsewhere")] }.value
    end

    assert_nil seen.first
    assert_equal ["a"], values(column.children)
  end

  def test_page_mount_collects_prefixed_children
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
    page.mount do
      Ruflet.text("a")
      Ruflet.container(content: Ruflet.text("b"))
    end

    assert_equal %w[Text Container], wire_types(page.controls)
  end

  def test_center_block_with_prefixed_children_uses_the_first_child
    center = Ruflet.center { Ruflet.container(content: Ruflet.text("x")) }

    assert_equal "Container", center.to_patch["content"]["_c"]
  end

  def test_app_blocks_collect_prefixed_children
    app = Ruflet::DSL.app
    column = app.column do
      Ruflet.text("a")
      text("b")
      Ruflet.container(content: Ruflet.text("c"))
    end

    assert_equal %w[Text Text Container], wire_types(column.children)
    assert_equal ["Column"], wire_types(app.instance_variable_get(:@roots))
  end

  def test_app_with_block_collects_prefixed_roots
    app = Ruflet::DSL.app do
      Ruflet.text("one")
      Ruflet.container(content: Ruflet.text("two"))
    end

    assert_equal %w[Text Container], wire_types(app.instance_variable_get(:@roots))
    assert_nil Ruflet::UI::BuildScope.current
  end

  def test_app_raising_block_pops_scope_and_parent
    app = Ruflet::DSL.app
    assert_raises(RuntimeError) { app.column { raise "boom" } }
    app.text("root")

    assert_nil Ruflet::UI::BuildScope.current
    assert_equal %w[Column Text], wire_types(app.instance_variable_get(:@roots))
    assert_empty app.instance_variable_get(:@roots).first.children
  end

  def test_kernel_dsl_collects_prefixed_children
    list = column do
      Ruflet.text("a")
      Ruflet.text("b")
    end

    assert_equal %w[a b], values(list.children)
    assert_equal ["Column"], wire_types(Ruflet::DSL._pending_app.instance_variable_get(:@roots))
  end

  private

  def wire_types(controls)
    controls.map { |control| control.to_patch["_c"] }
  end

  def values(controls)
    controls.map { |control| control.props["value"] }
  end
end

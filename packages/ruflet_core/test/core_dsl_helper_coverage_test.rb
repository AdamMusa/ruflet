# frozen_string_literal: true

require_relative "test_helper"

class CoreDslHelperCoverageTest < Minitest::Test
  def test_exported_core_controls_have_direct_ruby_helpers
    controls = [
      Ruflet.base_page(title: "Shell"),
      Ruflet.dialogs([Ruflet.alert_dialog(title: Ruflet.text("Hello"))]),
      Ruflet.pagelet(Ruflet.text("Body")),
      Ruflet.ruflet_app(url: "in-process://self"),
      Ruflet.service_registry([]),
      Ruflet.window(width: 900),
      Ruflet.option("ruby", text: "Ruby")
    ]

    assert_equal %w[BasePage Dialogs Pagelet RufletApp ServiceRegistry Window Option],
                 controls.map { |control| control.to_patch["_c"] }
    assert_equal "ruby", controls.last.to_patch["key"]
    assert_respond_to Ruflet::DSL, :view
  end
end

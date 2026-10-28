# frozen_string_literal: true

require_relative "test_helper"

class RufletAboutDialogCompatibilityTest < Minitest::Test
  def test_about_dialog_serializes_its_wire_contract
    dialog = Ruflet.about_dialog(
      application_name: "Rides",
      application_version: "1.4.0",
      application_icon: Ruflet.icon(Ruflet::MaterialIcons::DIRECTIONS_CAR),
      application_legalese: "© 2026 Rides Inc.",
      controls: [Ruflet.text("Made with Ruflet")],
      view: "licenses",
      modal: true,
      barrier_color: "#88112233",
      data: "about",
      key: "about",
      on_dismiss: ->(_event) {}
    )

    patch = dialog.to_patch

    assert_equal "AboutDialog", patch["_c"]
    assert_equal "Rides", patch["application_name"]
    assert_equal "1.4.0", patch["application_version"]
    assert_equal "Icon", patch["application_icon"]["_c"]
    assert_equal "© 2026 Rides Inc.", patch["application_legalese"]
    assert_equal ["Made with Ruflet"], patch["controls"].map { |child| child["value"] }
    assert_equal "licenses", patch["view"]
    assert_equal true, patch["modal"]
    assert_equal "#88112233", patch["barrier_color"]
    assert_equal "about", patch["data"]
    assert_equal true, patch["on_dismiss"]
    assert dialog.has_handler?(:dismiss)
  end

  def test_defaults_are_left_to_the_renderer
    patch = Ruflet.aboutdialog(application_name: "Rides").to_patch

    assert_equal "AboutDialog", patch["_c"]
    %w[view open modal application_version].each do |key|
      refute patch.key?(key), "#{key} is defaulted by the renderer"
    end
  end

  def test_dialogs_take_no_layout_keywords
    %i[width height expand margin left tooltip].each do |keyword|
      assert_raises(ArgumentError) { Ruflet.about_dialog(keyword => 1) }
    end
    assert_raises(ArgumentError) { Ruflet.about_dialog(application_title: "Rides") }
  end

  def test_show_dialog_opens_it_and_dismiss_untracks_it
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    dismissed = []
    dialog = Ruflet.about_dialog(
      application_name: "Rides",
      on_dismiss: ->(event) { dismissed << event.name }
    )

    page.add(Ruflet.text("Root"))
    page.show_dialog(dialog)
    assert_equal true, dialog.props["open"]

    page.dispatch_event(target: dialog.wire_id, name: "dismiss", data: nil)

    assert_equal ["dismiss"], dismissed
    assert_equal [], sent.last[1]["patch"][1][3]
  end

  def test_close_dialog_patches_open_false
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    dialog = Ruflet.about_dialog(application_name: "Rides")
    page.add(Ruflet.text("Root"))
    page.show_dialog(dialog)

    assert_same dialog, page.close_dialog(dialog)
    assert_equal false, dialog.props["open"]
    assert_equal dialog.wire_id, sent.last[1]["id"]
    assert_equal "open", sent.last[1]["patch"][1][2]
    assert_equal false, sent.last[1]["patch"][1][3]
  end
end

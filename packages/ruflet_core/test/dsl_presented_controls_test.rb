# frozen_string_literal: true

require "json"
require_relative "test_helper"

# Overlays (dialogs, sheets, snack bars, banners, pickers) and services are
# presented by the page or run as services; they are never laid out as
# children. DSL blocks therefore do not capture them implicitly, for bare and
# Ruflet.* helpers alike. Explicit children and a block's return value still
# place one in a layout.
class RufletDslPresentedControlsTest < Minitest::Test
  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  def test_presented_types_are_overlays_plus_engine_services
    types = Ruflet::Page::PRESENTED_TYPES

    %w[AboutDialog AlertDialog Banner BottomSheet DatePicker DateRangePicker SnackBar TimePicker].each do |wire|
      assert types.key?(wire), "#{wire} should be presented"
    end
    Ruflet::UI::ServiceTypes::ENGINE_SERVICE_TYPES.each_key do |wire|
      assert types.key?(wire), "engine service #{wire} should be presented"
    end
    %w[Audio AudioRecorder Flashlight InterstitialAd PermissionHandler SecureStorage Window].each do |wire|
      assert types.key?(wire), "#{wire} is an engine service"
    end
    %w[Picker TimerPicker ActionSheet Camera Column Container Text ListTile Button].each do |wire|
      refute types.key?(wire), "#{wire} renders inline"
    end
  end

  def test_ruby_service_registry_matches_the_engine_services_except_visual_camera
    Ruflet::UI::Services::RufletServices::CLASS_MAP.each do |name, klass|
      expected = !Ruflet::Page::VISUAL_SERVICE_TYPES.include?(name.delete("_"))
      assert_equal expected, Ruflet::UI::ServiceTypes.service_wire_type?(klass::WIRE),
                   "#{name} (#{klass::WIRE}) should #{expected ? '' : 'not '}be an engine service"
    end
    assert Ruflet::UI::ServiceTypes.service_name?("audio")
    assert Ruflet::UI::ServiceTypes.service_name?("interstitialad")
    refute Ruflet::UI::ServiceTypes.service_name?("camera")
    refute Ruflet::UI::ServiceTypes.service_name?("column")
  end

  def test_engine_service_types_are_current_with_the_engine
    engine = ENV["RUFLET_ENGINE_ROOT"]
    skip "set RUFLET_ENGINE_ROOT to a ruflet-engine checkout" unless engine && File.directory?(engine)

    tool = File.expand_path("../../../tools/sync_engine_service_types.rb", __dir__)
    output = IO.popen([RbConfig.ruby, tool, "--engine", engine, "--check"], err: [:child, :out], &:read)
    assert $?.success?, output
  end

  def test_inline_picker_timer_picker_and_action_sheet_stay_children
    column = Ruflet.column do
      picker([text("one"), text("two")])
      Ruflet.timer_picker
      action_sheet(title: text("Choose"))
      cupertino_picker([text("a")])
      Ruflet.cupertino_timer_picker
      Ruflet.cupertino_action_sheet(title: Ruflet.text("Pick"))
    end
    app = Ruflet::DSL.app
    app_column = app.column do
      picker([text("one")])
      timer_picker
      action_sheet(title: text("Choose"))
    end

    assert_equal %w[Picker TimerPicker ActionSheet Picker TimerPicker ActionSheet], wire_types(column.children)
    assert_equal %w[Picker TimerPicker ActionSheet], wire_types(app_column.children)
  end

  def test_extension_and_core_engine_services_are_not_captured
    column = Ruflet.column do
      control(:audio, src: "track.mp3")
      Ruflet.interstitial_ad(unit_id: "ad")
      window
      Ruflet.widget(:flashlight)
      text("kept")
    end
    app = Ruflet::DSL.app
    app_column = app.column do
      control(:audio, src: "track.mp3")
      interstitial_ad(unit_id: "ad")
      text("kept")
    end

    assert_equal ["Text"], wire_types(column.children)
    assert_equal ["Text"], wire_types(app_column.children)
  end

  # Engine services built through control()/widget() or a widget-style helper
  # (interstitial_ad) are not laid out; where the block has somewhere to put
  # services (a DSL app, Page#mount) they are registered there instead of
  # being lost.
  def test_app_blocks_register_engine_services_built_as_controls
    app = Ruflet::DSL.app do
      page do
        audio(src: "a.mp3")
        interstitial_ad(unit_id: "ad")
        control(:audio_recorder)
        column do
          widget(:flashlight)
          text("in column")
        end
        text("body")
      end
    end

    assert_equal %w[Column Text], wire_types(app.instance_variable_get(:@roots))
    assert_equal %w[Audio InterstitialAd AudioRecorder Flashlight], wire_types(app.instance_variable_get(:@services))
    assert_equal ["Text"], wire_types(app.instance_variable_get(:@roots).first.children)
  end

  def test_page_mount_registers_engine_services_on_the_page
    page = new_page
    page.mount do
      audio(src: "a.mp3")
      control(:audio_recorder)
      Ruflet.interstitial_ad(unit_id: "ad")
      column { widget(:flashlight) }
      text("body")
    end

    assert_equal %w[Column Text], wire_types(page.controls)
    assert_equal %w[Audio AudioRecorder InterstitialAd Flashlight], wire_types(page.services)
  end

  def test_standalone_builder_blocks_leave_services_to_the_caller
    audio = nil
    column = Ruflet.column do
      audio = control(:audio, src: "track.mp3")
      text("kept")
    end

    assert_equal ["Text"], wire_types(column.children)
    assert_equal "Audio", audio.wire_type
  end

  def test_page_service_accepts_engine_services_without_a_hand_list
    page = new_page

    assert_equal "Audio", page.service(:audio, src: "track.mp3").wire_type
    assert_equal "InterstitialAd", page.service(:interstitial_ad, unit_id: "ad").wire_type
    assert_raises(ArgumentError) { page.service(:column) }
  end

  def test_camera_is_a_visual_service_and_stays_a_child
    column = Ruflet.column do
      camera(preview_enabled: true)
      Ruflet.text("caption")
    end

    assert_equal %w[Camera Text], wire_types(column.children)
  end

  def test_qa_repro_dialog_opened_from_a_block_is_mounted_once
    page = new_page
    dlg = nil
    column = Ruflet.column do
      dlg = Ruflet.alert_dialog(title: Ruflet.text("Delete?"))
      Ruflet.button("Open", on_click: ->(event) { event.page.open(dlg) })
    end
    page.add(column)

    page.dispatch_event(target: column.children.first.wire_id, name: "click", data: nil)

    assert_equal ["Button"], wire_types(column.children)
    assert_includes page.instance_variable_get(:@dialogs), dlg
    assert_equal 1, JSON.generate(page.register_page_patch).scan('"_c":"AlertDialog"').length
  end

  def test_bare_and_prefixed_overlay_helpers_are_not_captured
    column = Ruflet.column do
      alert_dialog(title: text("bare"))
      Ruflet.alert_dialog(title: Ruflet.text("prefixed"))
      cupertino_alert_dialog(title: text("alias"))
      snack_bar(content: text("saved"))
      Ruflet.banner(content: Ruflet.text("note"), actions: [Ruflet.text_button("OK")])
      bottom_sheet(content: text("sheet"))
      date_picker
      Ruflet.time_picker
      text("kept")
    end

    assert_equal ["Text"], wire_types(column.children)
    assert_equal "kept", column.children.first.props["value"]
  end

  def test_overlays_are_not_captured_by_app_blocks_or_app_roots
    app = Ruflet::DSL.app
    dlg = app.alert_dialog(title: app.text("top"))
    column = app.column do
      alert_dialog(title: text("in block"))
      Ruflet.snack_bar(content: Ruflet.text("saved"))
      text("kept")
    end
    app.text("body")

    assert_equal ["Text"], wire_types(column.children)
    assert_equal %w[Column Text], wire_types(app.instance_variable_get(:@roots))
    refute_includes app.instance_variable_get(:@roots), dlg
  end

  def test_kernel_top_level_dialog_is_not_a_body_control
    dlg = alert_dialog(title: text("top"))
    column { text("body") }

    roots = Ruflet::DSL._pending_app.instance_variable_get(:@roots)
    assert_equal ["Column"], wire_types(roots)
    refute_includes roots, dlg
  end

  def test_services_are_not_captured
    column = Ruflet.column do
      widget(:clipboard)
      Ruflet.control(:battery)
      text("kept")
    end
    app = Ruflet::DSL.app
    app_column = app.column do
      control(:clipboard)
      text("kept")
    end

    assert_equal ["Text"], wire_types(column.children)
    assert_equal ["Text"], wire_types(app_column.children)
  end

  def test_page_mount_does_not_mount_overlays_as_body_controls
    page = new_page
    page.mount do
      alert_dialog(title: text("later"))
      text("body")
    end

    assert_equal ["Text"], wire_types(page.controls)
  end

  def test_explicit_children_and_block_return_value_still_place_overlays
    dlg = Ruflet.alert_dialog(title: Ruflet.text("explicit"))
    explicit = Ruflet.column(controls: [dlg]) { text("a") }
    returned = Ruflet.column do
      text("a")
      Ruflet.alert_dialog(title: Ruflet.text("returned"))
    end
    app = Ruflet::DSL.app
    app_explicit = app.column(controls: [app.snack_bar(content: app.text("s"))]) { text("a") }

    assert_equal %w[Text AlertDialog], wire_types(explicit.children)
    assert_same dlg, explicit.children.last
    assert_equal %w[Text AlertDialog], wire_types(returned.children)
    assert_equal %w[Text SnackBar], wire_types(app_explicit.children)
  end

  # A date picker built with inline: true renders in place (cupertino_date_picker
  # defaults to it), so it is laid out like any other control. Without it the
  # DatePicker is the dialog the page presents.
  def test_presented_control_excludes_inline_date_pickers
    assert Ruflet::Page.presented_control?(Ruflet.date_picker)
    assert Ruflet::Page.presented_control?(Ruflet.date_picker(inline: false))
    assert Ruflet::Page.presented_control?(Ruflet.cupertino_date_picker(inline: false))
    refute Ruflet::Page.presented_control?(Ruflet.date_picker(inline: true))
    refute Ruflet::Page.presented_control?(Ruflet.cupertino_date_picker)
    assert Ruflet::Page.presented_control?(Ruflet.alert_dialog(title: Ruflet.text("still presented")))
  end

  def test_inline_date_pickers_stay_children
    column = Ruflet.column do
      cupertino_date_picker(value: "2026-11-02T09:30:00")
      Ruflet.cupertino_date_picker
      date_picker(inline: true)
      Ruflet.date_picker(inline: true)
      text("kept")
      nil
    end
    app = Ruflet::DSL.app
    app_column = app.column do
      cupertino_date_picker
      date_picker(inline: true)
      text("kept")
      nil
    end

    assert_equal %w[DatePicker DatePicker DatePicker DatePicker Text], wire_types(column.children)
    assert_equal [true, true, true, true], column.children.first(4).map { |child| child.to_patch["inline"] }
    assert_equal %w[DatePicker DatePicker Text], wire_types(app_column.children)
  end

  def test_dialog_date_pickers_are_still_not_captured
    column = Ruflet.column do
      date_picker
      Ruflet.date_picker(open: true)
      date_picker(inline: false)
      cupertino_date_picker(inline: false)
      text("kept")
      nil
    end

    assert_equal ["Text"], wire_types(column.children)
  end

  def test_inline_date_pickers_are_app_roots_and_page_body_controls
    picker = cupertino_date_picker(value: "2026-11-02T09:30:00")
    dialog = date_picker(open: true)
    roots = Ruflet::DSL._pending_app.instance_variable_get(:@roots)
    page = new_page
    page.mount do
      date_picker(inline: true)
      date_picker
      text("body")
      nil
    end

    assert_equal ["DatePicker"], wire_types(roots)
    assert_same picker, roots.first
    refute_includes roots, dialog
    assert_equal %w[DatePicker Text], wire_types(page.controls)
  end

  def test_inline_date_picker_in_a_block_is_sent_once_in_its_layout
    page = new_page
    column = Ruflet.column do
      Ruflet.text("When?")
      Ruflet.cupertino_date_picker(value: "2026-11-02T09:30:00")
      nil
    end
    page.add(column)

    patch = JSON.generate(page.register_page_patch)
    assert_equal %w[Text DatePicker], wire_types(column.children)
    assert_equal 1, patch.scan('"_c":"DatePicker"').length
    assert_empty page.instance_variable_get(:@dialogs)
  end

  def test_overlay_props_are_still_reclaimed
    column = Ruflet.column do
      Ruflet.alert_dialog(title: Ruflet.text("T"), actions: [Ruflet.text_button("OK")])
      text("kept")
    end

    assert_equal ["Text"], wire_types(column.children)
  end

  private

  def new_page
    Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
  end

  def wire_types(controls)
    controls.map { |control| control.to_patch["_c"] }
  end
end

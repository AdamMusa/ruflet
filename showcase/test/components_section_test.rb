# frozen_string_literal: true

require "minitest/autorun"

class ComponentsSectionTest < Minitest::Test
  def test_gallery_links_to_components_section
    gallery = File.read(File.expand_path("../views/gallery_view.rb", __dir__))
    app = File.read(File.expand_path("../app.rb", __dir__))
    controls = File.read(File.expand_path("../sections_controls.rb", __dir__))

    assert_includes gallery, "\"Components\""
    assert_includes gallery, "\"/components\""
    assert_includes app, "when \"/components\""
    assert_includes app, "route.start_with?(\"/components/\")"
    assert_includes app, "back_route: \"/components\""
    assert_includes controls, "sections_controls/components"
  end

  def test_components_section_lists_supported_widgets_and_routes_to_details
    source = File.read(File.expand_path("../sections_controls/components.rb", __dir__))

    %w[
      Hello
      Button
      Dialog
      DatePicker
      DateRangePicker
      TimePicker
      DataTable
      Dropdown
      Checkbox
      Radio
      Tabs
      ProgressBar
      ProgressRing
      GridView
      InteractiveViewer
      Container
      Row
      Column
      TextField
      Icon
    ].each do |label|
      assert_includes source, label
    end

    assert_includes source, "SUPPORTED_COMPONENTS.map"
    assert_includes source, 'page.go("/components/#{slug}"'
    assert_includes source, "def build_component_detail"
  end

  def test_component_details_use_real_widget_demos
    source = File.read(File.expand_path("../sections_controls/components.rb", __dir__))

    assert_includes source, "alert_dialog("
    assert_includes source, "page.show_dialog(dialog)"
    assert_includes source, "page.update(dialog, open: false)"
    assert_includes source, "date_picker("
    assert_includes source, "date_range_picker("
    assert_includes source, "time_picker("
    assert_includes source, "result = text("
    assert_includes source, 'event.control.props["value"]'
    assert_includes source, 'event.control.props["start_value"]'
    assert_includes source, 'event.control.props["end_value"]'
    assert_includes source, "page.update(result"
    assert_includes source, "data_table("
    assert_includes source, "dropdown("
    assert_includes source, "checkbox("
    assert_includes source, "radio_group("
    assert_includes source, "tabs("
    assert_includes source, "progress_bar("
    assert_includes source, "progress_ring("
    assert_includes source, "height: 140"
    refute_includes source, "progress_bar(value:"
    refute_includes source, "progress_ring(value:"
    assert_includes source, "grid_view("
    assert_includes source, "interactive_viewer("
    assert_includes source, "filled_button("
  end
end

# frozen_string_literal: true

require_relative "test_helper"

class RufletPlatformControlContractTest < Minitest::Test
  CORE_CONTROL_WIRES = %w[
    ActionSheet ActionSheetAction AlertDialog AnimatedSwitcher AppBar AutoComplete AutofillGroup
    Banner BottomAppBar BottomSheet Button Canvas Card Checkbox Chip CircleAvatar Column Container
    ContextMenu ContextMenuAction DataTable DatePicker DateRangePicker Dismissible Divider DragTarget
    Draggable Dropdown ExpansionPanelList ExpansionTile FilledButton FilledIconButton
    FilledTonalButton FilledTonalIconButton FloatingActionButton GestureDetector GridView Hero Icon
    IconButton Image InteractiveViewer KeyboardListener ListTile ListView Markdown MenuBar
    MenuItemButton MergeSemantics NavigationBar NavigationBarDestination NavigationDrawer
    NavigationRail OutlinedButton OutlinedIconButton Page Pagelet PageView Picker Placeholder
    PopupMenuButton ProgressBar ProgressRing Radio RadioGroup RangeSlider ReorderableDragHandle
    ReorderableListView ResponsiveRow RotatedBox Row SafeArea Screenshot SearchBar SegmentedButton
    SelectionArea Semantics ShaderMask Shimmer Slider SnackBar Stack SubmenuButton Switch Tab TabBar
    TabBarView Tabs Text TextButton TextField TimePicker TimerPicker TransparentPointer
    VerticalDivider View WindowDragArea
  ].freeze

  CORE_SERVICE_WIRES = %w[
    Accelerometer Barometer Battery BrowserContextMenu Clipboard Connectivity FilePicker Gyroscope
    HapticFeedback Magnetometer ScreenBrightness SemanticsService ShakeDetector Share SharedPreferences
    StoragePaths UrlLauncher UserAccelerometer Wakelock Window
  ].freeze

  def test_every_flet_core_control_and_service_has_a_ruby_schema
    wires = Ruflet::UI::ControlFactory::CLASS_MAP.values.uniq.filter_map do |klass|
      klass.const_get(:WIRE) if klass.const_defined?(:WIRE)
    end

    assert_empty CORE_CONTROL_WIRES - wires
    assert_empty CORE_SERVICE_WIRES - wires
  end

  def test_canonical_methods_emit_only_canonical_wire_types
    controls = [
      Ruflet.button("Continue", opacity_on_click: 0.3),
      Ruflet.text_field("Name", placeholder_text: "Full name"),
      Ruflet.date_picker(date_order: :dmy),
      Ruflet.picker([Ruflet.text("One")], selected_index: 0),
      Ruflet.timer_picker(mode: :hm),
      Ruflet.action_sheet(title: Ruflet.text("Choose")),
      Ruflet.action_sheet_action("Save", default: true),
      Ruflet.context_menu_action("Copy", trailing_icon: "copy")
    ]

    assert_equal %w[
      Button TextField DatePicker Picker TimerPicker ActionSheet ActionSheetAction ContextMenuAction
    ], controls.map { |control| control.to_patch["_c"] }
  end

  def test_legacy_design_names_are_protocol_aliases_not_renderer_choices
    controls = [
      Ruflet.cupertino_button("Continue"),
      Ruflet.cupertino_filled_button("Save"),
      Ruflet.cupertino_tinted_button("Later"),
      Ruflet.cupertino_text_field("Name"),
      Ruflet.cupertino_switch(value: true),
      Ruflet.cupertino_date_picker(value: "2026-09-01"),
      Ruflet.dropdown_m2([])
    ]

    assert_equal %w[
      Button FilledButton FilledTonalButton TextField Switch DatePicker Dropdown
    ], controls.map { |control| control.to_patch["_c"] }
  end

  def test_canonical_schema_accepts_properties_from_both_renderers
    button = Ruflet.button("Continue", elevation: 2, opacity_on_click: 0.25)
    field = Ruflet.text_field(
      "Name",
      focused_border_width: 2,
      placeholder_text: "Full name",
      clear_button_visibility_mode: :editing
    )

    assert_equal 2, button.props["elevation"]
    assert_equal 0.25, button.props["opacity_on_click"]
    assert_equal 2, field.props["focused_border_width"]
    assert_equal "Full name", field.props["placeholder_text"]
    assert_equal "editing", field.props["clear_button_visibility_mode"]
  end
end

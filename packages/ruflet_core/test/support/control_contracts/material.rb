# frozen_string_literal: true

require_relative "../control_contract"

# Contract specs for the Material controls (lib/ruflet_ui/ruflet/ui/controls/materials).
# See test/support/control_contract.rb for the options and what they assert.
#
# The props: and events: of the open-schema controls (video, web_view, map
# and its layers, the ads, charts, color pickers, data_table2, lottie, rive,
# code_editor) are the names the engine's renderer for each reads, from the
# ruflet_* packages of AdamMusa/ruflet-engine (codex/engine-initialization,
# f44e7df). map_layer has none: the engine has no MapLayer renderer.

module ControlContract
  define(
    "material",
    {
      "about_dialog" => { wire: "AboutDialog", aliases: %w[aboutdialog] },
      "audio" => { wire: "Audio" },
      "auto_complete" => { wire: "AutoComplete", aliases: %w[autocomplete] },
      "auto_complete_suggestion" => { wire: "AutoCompleteSuggestion", aliases: %w[autocompletesuggestion], base: { key: "k" } },
      "badge" => { wire: "Badge" },
      "banner" => { wire: "Banner", base: { content: TEXT } },
      "banner_ad" => {
        wire: "BannerAd",
        aliases: %w[bannerad],
        props: %w[request unit_id],
        events: %w[on_click on_close on_error on_impression on_load on_open on_paid on_will_dismiss]
      },
      "bar_chart" => {
        wire: "BarChart",
        aliases: %w[barchart],
        props: %w[animation baseline_y bgcolor border bottom_axis group_alignment groups horizontal_grid_lines
                  interactive left_axis max_y min_y right_axis spacing tooltip top_axis vertical_grid_lines],
        events: %w[on_event]
      },
      "bar_chart_group" => {
        wire: "BarChartGroup",
        aliases: %w[barchartgroup],
        props: %w[group_vertically rods spacing x]
      },
      "bar_chart_rod" => {
        wire: "BarChartRod",
        aliases: %w[barchartrod],
        props: %w[background_gradient bg_from_y bg_to_y bgcolor border_radius border_side color from_y
                  gradient selected show_tooltip stack_items to_y width]
      },
      "bar_chart_rod_stack_item" => {
        wire: "BarChartRodStackItem",
        aliases: %w[barchartrodstackitem],
        props: %w[border_side color from_y to_y]
      },
      "block_picker" => {
        wire: "BlockPicker",
        aliases: %w[blockpicker],
        props: %w[available_colors color],
        events: %w[on_color_change]
      },
      "bottom_app_bar" => { wire: "BottomAppBar", aliases: %w[bottomappbar] },
      "candlestick_chart" => {
        wire: "CandlestickChart",
        aliases: %w[candlestickchart],
        props: %w[animation baseline_x baseline_y bgcolor border bottom_axis horizontal_grid_lines interactive
                  left_axis long_press_duration max_x max_y min_x min_y right_axis rotation_quarter_turns
                  show_tooltips_for_selected_spots_only spots tooltip top_axis touch_spot_threshold
                  vertical_grid_lines],
        events: %w[on_event]
      },
      "candlestick_chart_spot" => {
        wire: "CandlestickChartSpot",
        aliases: %w[candlestickchartspot],
        props: %w[close high low open selected show_tooltip x]
      },
      "card" => { wire: "Card" },
      "carousel_view" => { wire: "CarouselView", aliases: %w[carouselview] },
      "chart_axis" => {
        wire: "ChartAxis",
        aliases: %w[chartaxis],
        props: %w[label_size label_spacing labels show_labels show_max show_min title title_size]
      },
      "chart_axis_label" => {
        wire: "ChartAxisLabel",
        aliases: %w[chartaxislabel],
        props: %w[label value]
      },
      "chip" => { wire: "Chip" },
      "circle_avatar" => { wire: "CircleAvatar", aliases: %w[circleavatar] },
      "circle_layer" => {
        wire: "CircleLayer",
        aliases: %w[circlelayer],
        props: %w[circles]
      },
      "circle_marker" => {
        wire: "CircleMarker",
        aliases: %w[circlemarker],
        props: %w[border_color border_stroke_width color coordinates radius use_radius_in_meter]
      },
      "code_editor" => {
        wire: "CodeEditor",
        aliases: %w[codeeditor],
        props: %w[autocomplete autocomplete_words autofocus code_theme gutter_style language padding read_only
                  selection text_style value],
        events: %w[on_change on_selection_change]
      },
      "color_picker" => {
        wire: "ColorPicker",
        aliases: %w[colorpicker],
        props: %w[color color_history color_picker_width display_thumb_color enable_alpha hex_input_bar
                  hsv_color label_text_style label_types palette_type picker_area_border_radius
                  picker_area_height_percent],
        events: %w[on_color_change on_history_change on_hsv_color_change]
      },
      "container" => { wire: "Container" },
      "data_cell" => { wire: "DataCell", aliases: %w[datacell], base: { content: TEXT } },
      "data_column" => { wire: "DataColumn", aliases: %w[datacolumn], base: { label: TEXT } },
      "data_column2" => {
        wire: "DataColumn2",
        aliases: %w[datacolumn2],
        props: %w[fixed_width heading_row_alignment label numeric size tooltip],
        events: %w[on_sort]
      },
      "data_row" => { wire: "DataRow", aliases: %w[datarow] },
      "data_row2" => {
        wire: "DataRow2",
        aliases: %w[datarow2],
        props: %w[cells color decoration selected specific_row_height],
        events: %w[on_double_tap on_long_press on_secondary_tap on_secondary_tap_down on_select_change on_tap]
      },
      "data_table" => { wire: "DataTable", aliases: %w[datatable] },
      "data_table2" => {
        wire: "DataTable2",
        aliases: %w[datatable2],
        props: %w[bgcolor border border_radius bottom_margin checkbox_alignment checkbox_horizontal_margin
                  clip_behavior column_spacing columns data_row_checkbox_theme data_row_color data_row_height
                  data_text_style divider_thickness empty fixed_columns_color fixed_corner_color
                  fixed_left_columns fixed_top_rows gradient heading_checkbox_theme heading_row_color
                  heading_row_decoration heading_row_height heading_text_style horizontal_lines
                  horizontal_margin lm_ratio min_width rows show_bottom_border show_checkbox_column
                  show_heading_checkbox sm_ratio sort_arrow_animation_duration sort_arrow_icon
                  sort_arrow_icon_color sort_ascending sort_column_index vertical_lines
                  visible_horizontal_scroll_bar visible_vertical_scroll_bar],
        events: %w[on_select_all]
      },
      "date_range_picker" => { wire: "DateRangePicker", aliases: %w[daterangepicker] },
      "divider" => { wire: "Divider" },
      "dropdown_option" => { wire: "DropdownOption", aliases: %w[dropdownoption] },
      "expansion_panel" => { wire: "ExpansionPanel", aliases: %w[expansionpanel] },
      "expansion_panel_list" => { wire: "ExpansionPanelList", aliases: %w[expansionpanellist] },
      "expansion_tile" => { wire: "ExpansionTile", aliases: %w[expansiontile], base: { title: TEXT } },
      "filled_icon_button" => { wire: "FilledIconButton", aliases: %w[fillediconbutton] },
      "filled_tonal_icon_button" => { wire: "FilledTonalIconButton", aliases: %w[filledtonaliconbutton] },
      "floating_action_button" => { wire: "FloatingActionButton", aliases: %w[floatingactionbutton] },
      "hue_ring_picker" => {
        wire: "HueRingPicker",
        aliases: %w[hueringpicker],
        props: %w[color color_picker_height enable_alpha hue_ring_stroke_width picker_area_border_radius
                  portrait_only],
        events: %w[on_color_change]
      },
      "icon_button" => { wire: "IconButton", aliases: %w[iconbutton] },
      "image_source_attribution" => {
        wire: "ImageSourceAttribution",
        aliases: %w[imagesourceattribution],
        props: %w[height image tooltip],
        events: %w[on_click]
      },
      "interstitial_ad" => {
        wire: "InterstitialAd",
        aliases: %w[interstitialad],
        props: %w[request unit_id],
        events: %w[on_click on_close on_error on_impression on_load on_open]
      },
      "line_chart" => {
        wire: "LineChart",
        aliases: %w[linechart],
        props: %w[animation baseline_x baseline_y bgcolor border bottom_axis data_series horizontal_grid_lines
                  interactive left_axis max_x max_y min_x min_y point_line_end point_line_start right_axis
                  tooltip top_axis vertical_grid_lines],
        events: %w[on_event]
      },
      "line_chart_data" => {
        wire: "LineChartData",
        aliases: %w[linechartdata],
        props: %w[above_line above_line_bgcolor above_line_cutoff_y above_line_gradient below_line
                  below_line_bgcolor below_line_cutoff_y below_line_gradient color curve_smoothness curved
                  dash_pattern gradient point points prevent_curve_over_shooting
                  prevent_curve_over_shooting_threshold rounded_stroke_cap rounded_stroke_join
                  selected_below_line selected_point shadow step_direction stroke_width]
      },
      "line_chart_data_point" => {
        wire: "LineChartDataPoint",
        aliases: %w[linechartdatapoint],
        props: %w[selected show_tooltip x y]
      },
      "lottie" => {
        wire: "Lottie",
        props: %w[alignment animate background_loading enable_layers_opacity enable_merge_paths error_content
                  filter_quality fit headers repeat reverse src],
        events: %w[on_error on_load]
      },
      "map" => {
        wire: "Map",
        samples: { initial_center: Sample.new([41.9, 12.5], { "latitude" => 41.9, "longitude" => 12.5 }) },
        props: %w[animation_curve animation_duration bgcolor initial_camera_fit initial_center
                  initial_rotation initial_zoom interaction_configuration keep_alive layers max_zoom min_zoom],
        events: %w[on_event on_hover on_init on_long_press on_pointer_cancel on_pointer_down on_pointer_up
                   on_position_change on_secondary_tap on_tap]
      },
      "map_layer" => { wire: "MapLayer", aliases: %w[maplayer] },
      "marker" => {
        wire: "Marker",
        props: %w[alignment content coordinates height rotate width]
      },
      "marker_layer" => {
        wire: "MarkerLayer",
        aliases: %w[markerlayer],
        props: %w[alignment markers rotate]
      },
      "material_picker" => {
        wire: "MaterialPicker",
        aliases: %w[materialpicker],
        props: %w[color enable_label portrait_only],
        events: %w[on_color_change on_primary_change]
      },
      "menu_bar" => { wire: "MenuBar", aliases: %w[menubar] },
      "menu_item_button" => { wire: "MenuItemButton", aliases: %w[menuitembutton] },
      "multiple_choice_block_picker" => {
        wire: "MultipleChoiceBlockPicker",
        aliases: %w[multiplechoiceblockpicker],
        props: %w[available_colors colors],
        events: %w[on_colors_change]
      },
      "native_ad" => {
        wire: "NativeAd",
        aliases: %w[nativead],
        props: %w[factory_id request template_style unit_id],
        events: %w[on_click on_close on_error on_impression on_load on_open on_paid on_will_dismiss]
      },
      "navigation_bar_destination" => { wire: "NavigationBarDestination", aliases: %w[navigationbardestination], base: { icon: "add" } },
      "navigation_drawer" => { wire: "NavigationDrawer", aliases: %w[navigationdrawer] },
      "navigation_drawer_destination" => { wire: "NavigationDrawerDestination", aliases: %w[navigationdrawerdestination], base: { icon: "add" } },
      "navigation_rail" => { wire: "NavigationRail", aliases: %w[navigationrail] },
      "navigation_rail_destination" => { wire: "NavigationRailDestination", aliases: %w[navigationraildestination], base: { icon: "add" } },
      "option" => { wire: "Option" },
      "outlined_icon_button" => { wire: "OutlinedIconButton", aliases: %w[outlinediconbutton] },
      "pie_chart" => {
        wire: "PieChart",
        aliases: %w[piechart],
        props: %w[animation center_space_color center_space_radius sections sections_space start_degree_offset],
        events: %w[on_event]
      },
      "pie_chart_section" => {
        wire: "PieChartSection",
        aliases: %w[piechartsection],
        props: %w[badge badge_position border_side color gradient radius title title_position title_style
                  value]
      },
      "polygon_layer" => {
        wire: "PolygonLayer",
        aliases: %w[polygonlayer],
        props: %w[draw_labels_last polygon_culling polygon_labels polygons simplification_tolerance
                  use_alternative_rendering]
      },
      "polygon_marker" => {
        wire: "PolygonMarker",
        aliases: %w[polygonmarker],
        props: %w[border_color border_stroke_width color coordinates disable_holes_border label
                  label_text_style rotate_label stroke_cap stroke_join]
      },
      "polyline_layer" => {
        wire: "PolylineLayer",
        aliases: %w[polylinelayer],
        props: %w[culling_margin min_hittable_radius polylines simplification_tolerance]
      },
      "polyline_marker" => {
        wire: "PolylineMarker",
        aliases: %w[polylinemarker],
        props: %w[border_color border_stroke_width color colors_stop coordinates gradient_colors stroke_cap
                  stroke_join stroke_pattern stroke_width use_stroke_width_in_meter]
      },
      "popup_menu_button" => { wire: "PopupMenuButton", aliases: %w[popupmenubutton] },
      "popup_menu_item" => { wire: "PopupMenuItem", aliases: %w[popupmenuitem] },
      "progress_bar" => { wire: "ProgressBar", aliases: %w[progressbar] },
      "radar_chart" => {
        wire: "RadarChart",
        aliases: %w[radarchart],
        props: %w[animation border center_min_value data_sets grid_border_side interactive long_press_duration
                  radar_bgcolor radar_border_side radar_shape tick_border_side tick_count ticks_text_style
                  title_position_percentage_offset title_text_style titles touch_spot_threshold],
        events: %w[on_event]
      },
      "radar_chart_title" => {
        wire: "RadarChartTitle",
        aliases: %w[radarcharttitle],
        props: %w[angle position_percentage_offset text text_spans]
      },
      "radar_data_set" => {
        wire: "RadarDataSet",
        aliases: %w[radardataset],
        props: %w[border_color border_width entries entry_radius fill_color fill_gradient]
      },
      "radar_data_set_entry" => {
        wire: "RadarDataSetEntry",
        aliases: %w[radardatasetentry],
        props: %w[value]
      },
      "radio_group" => { wire: "RadioGroup", aliases: %w[radiogroup] },
      "range_slider" => { wire: "RangeSlider", aliases: %w[rangeslider] },
      "reorderable_list_view" => { wire: "ReorderableListView", aliases: %w[reorderablelistview] },
      "rich_attribution" => {
        wire: "RichAttribution",
        aliases: %w[richattribution],
        props: %w[alignment attributions permanent_height popup_bgcolor popup_border_radius
                  popup_initial_display_duration show_flutter_map_attribution]
      },
      "rive" => {
        wire: "Rive",
        props: %w[alignment art_board clip_rect fit headers placeholder speed_multiplier src
                  use_art_board_size]
      },
      "scatter_chart" => {
        wire: "ScatterChart",
        aliases: %w[scatterchart],
        props: %w[animation baseline_x baseline_y bgcolor border bottom_axis error_indicator_data
                  horizontal_grid_lines interactive left_axis long_press_duration max_x max_y min_x min_y
                  right_axis rotation_quarter_turns show_tooltips_for_selected_spots_only spots tooltip
                  top_axis vertical_grid_lines],
        events: %w[on_event]
      },
      "scatter_chart_spot" => {
        wire: "ScatterChartSpot",
        aliases: %w[scatterchartspot],
        props: %w[color label_text label_text_style point radius render_priority selected show_tooltip x
                  x_error y y_error]
      },
      "search_bar" => { wire: "SearchBar", aliases: %w[searchbar] },
      "segment" => { wire: "Segment", base: { value: "v" } },
      "selection_area" => { wire: "SelectionArea", aliases: %w[selectionarea], base: { content: TEXT } },
      "simple_attribution" => {
        wire: "SimpleAttribution",
        aliases: %w[simpleattribution],
        props: %w[alignment bgcolor text],
        events: %w[on_click]
      },
      "slide_picker" => {
        wire: "SlidePicker",
        aliases: %w[slidepicker],
        props: %w[color color_model display_thumb_color enable_alpha indicator_alignment_begin
                  indicator_alignment_end indicator_border_radius indicator_size label_text_style label_types
                  show_indicator show_label show_params show_slider_text slider_size slider_text_style],
        events: %w[on_color_change]
      },
      "snack_bar" => { wire: "SnackBar", aliases: %w[snackbar], base: { content: TEXT } },
      "snack_bar_action" => { wire: "SnackBarAction", aliases: %w[snackbaraction], base: { label: "l" } },
      "spinkit" => { wire: "RufletSpinKit", helper_props: { wave: {} } },
      "stepper" => { wire: "Stepper" },
      "stepper_step" => { wire: "Step", aliases: %w[stepperstep], base: { title: TEXT } },
      "submenu_button" => { wire: "SubmenuButton", aliases: %w[submenubutton] },
      "tab" => { wire: "Tab" },
      "tab_bar" => { wire: "TabBar", aliases: %w[tabbar] },
      "tab_bar_view" => { wire: "TabBarView", aliases: %w[tabbarview] },
      "tabs" => { wire: "Tabs" },
      "text_source_attribution" => {
        wire: "TextSourceAttribution",
        aliases: %w[textsourceattribution],
        props: %w[prepend_copyright text text_style],
        events: %w[on_click]
      },
      "tile_layer" => {
        wire: "TileLayer",
        aliases: %w[tilelayer],
        props: %w[additional_options display_mode enable_retina_mode enable_tms error_image_src
                  evict_error_tile_strategy fallback_url keep_buffer max_native_zoom max_zoom min_native_zoom
                  min_zoom pan_buffer subdomains tile_bounds tile_size url_template user_agent_package_name
                  zoom_offset zoom_reverse],
        events: %w[on_image_error]
      },
      "time_picker" => { wire: "TimePicker", aliases: %w[timepicker] },
      "vertical_divider" => { wire: "VerticalDivider", aliases: %w[verticaldivider] },
      "video" => {
        wire: "Video",
        props: %w[alignment autoplay configuration fill_color filter_quality fit fullscreen muted
                  pause_upon_entering_background_mode pitch playback_rate playlist playlist_mode
                  resume_upon_entering_foreground_mode show_controls shuffle_playlist subtitle_configuration
                  subtitle_track title volume wakelock],
        events: %w[on_complete on_enter_fullscreen on_error on_exit_fullscreen on_loaded on_track_change]
      },
      "web_view" => {
        wire: "WebView",
        aliases: %w[webview],
        props: %w[bgcolor method prevent_links url],
        events: %w[on_console_message on_javascript_alert_dialog on_page_ended on_page_started on_progress
                   on_scroll on_url_change on_web_resource_error]
      }
    }
  )
end

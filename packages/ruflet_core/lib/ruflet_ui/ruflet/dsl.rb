# frozen_string_literal: true

require_relative "ui/control_methods"
require_relative "ui/control_factory"

module Ruflet
  module DSL
    DURATION_FACTORS_MS = {
      days: 86_400_000.0,
      hours: 3_600_000.0,
      minutes: 60_000.0,
      seconds: 1_000.0,
      milliseconds: 1.0,
      microseconds: 0.001
    }.freeze

    module_function

    def default_host
      ENV["RUFLET_HOST"].to_s.strip.empty? ? "0.0.0.0" : ENV["RUFLET_HOST"].to_s
    end

    def default_port
      raw = ENV["RUFLET_PORT"].to_s
      value = raw.to_i
      value > 0 ? value : 8550
    end

    def _pending_app
      @_pending_app ||= App.new(host: default_host, port: default_port)
    end

    def _reset_pending_app!
      @_pending_app = App.new(host: default_host, port: default_port)
    end

    def app(host: nil, port: nil, &block)
      host ||= default_host
      port ||= default_port
      return App.new(host: host, port: port).tap { |a| a.instance_eval(&block) } if block

      pending = _pending_app
      pending.set_endpoint!(host: host, port: port)
      _reset_pending_app!
      pending
    end

    def page(**props, &block) = _pending_app.page(**props, &block)
    def control(type, **props, &block) = _pending_app.control(type, **props, &block)
    def widget(type, **props, &block) = _pending_app.widget(type, **props, &block)
    def service(type, **props, &block) = _pending_app.service(type, **props, &block)
    def column(children = nil, **props, &block) = _pending_app.column(children, **props, &block)
    def center(**props, &block) = _pending_app.center(**props, &block)
    def row(children = nil, **props, &block) = _pending_app.row(children, **props, &block)
    def stack(children = nil, **props, &block) = _pending_app.stack(children, **props, &block)
    def grid_view(children = nil, **props, &block) = _pending_app.grid_view(children, **props, &block)
    def gridview(children = nil, **props, &block) = _pending_app.gridview(children, **props, &block)
    def container(**props, &block) = _pending_app.container(**props, &block)
    def animated_switcher(content = nil, **props) = _pending_app.animated_switcher(content, **props)
    def animatedswitcher(content = nil, **props) = _pending_app.animatedswitcher(content, **props)
    def auto_complete(suggestions = nil, **props) = _pending_app.auto_complete(suggestions, **props)
    def autocomplete(suggestions = nil, **props) = _pending_app.autocomplete(suggestions, **props)
    def auto_complete_suggestion(key = nil, **props) = _pending_app.auto_complete_suggestion(key, **props)
    def autocomplete_suggestion(key = nil, **props) = _pending_app.autocomplete_suggestion(key, **props)
    def autocompletesuggestion(key = nil, **props) = _pending_app.autocompletesuggestion(key, **props)
    def context_menu(content = nil, **props) = _pending_app.context_menu(content, **props)
    def contextmenu(content = nil, **props) = _pending_app.contextmenu(content, **props)
    def gesture_detector(**props, &block) = _pending_app.gesture_detector(**props, &block)
    def gesturedetector(**props, &block) = _pending_app.gesturedetector(**props, &block)
    def draggable(content = nil, **props, &block) = _pending_app.draggable(content, **props, &block)
    def dismissible(content = nil, **props) = _pending_app.dismissible(content, **props)
    def drag_target(content = nil, **props, &block) = _pending_app.drag_target(content, **props, &block)
    def dragtarget(content = nil, **props, &block) = _pending_app.dragtarget(content, **props, &block)
    def card(content = nil, **props) = _pending_app.card(content, **props)
    def list_tile(**props) = _pending_app.list_tile(**props)
    def listtile(**props) = _pending_app.listtile(**props)
    def list_view(children = nil, **props) = _pending_app.list_view(children, **props)
    def listview(children = nil, **props) = _pending_app.listview(children, **props)
    def menu_bar(children = nil, **props) = _pending_app.menu_bar(children, **props)
    def menubar(children = nil, **props) = _pending_app.menubar(children, **props)
    def menu_item_button(content = nil, **props) = _pending_app.menu_item_button(content, **props)
    def menuitembutton(content = nil, **props) = _pending_app.menuitembutton(content, **props)
    def merge_semantics(content = nil, **props) = _pending_app.merge_semantics(content, **props)
    def mergesemantics(content = nil, **props) = _pending_app.mergesemantics(content, **props)
    def submenu_button(children = nil, **props) = _pending_app.submenu_button(children, **props)
    def submenubutton(children = nil, **props) = _pending_app.submenubutton(children, **props)
    def divider(**props) = _pending_app.divider(**props)
    def vertical_divider(**props) = _pending_app.vertical_divider(**props)
    def verticaldivider(**props) = _pending_app.verticaldivider(**props)
    def window_drag_area(content = nil, **props) = _pending_app.window_drag_area(content, **props)
    def windowdragarea(content = nil, **props) = _pending_app.windowdragarea(content, **props)
    def date_picker(**props) = _pending_app.date_picker(**props)
    def datepicker(**props) = _pending_app.datepicker(**props)
    def date_range_picker(**props) = _pending_app.date_range_picker(**props)
    def daterangepicker(**props) = _pending_app.daterangepicker(**props)
    def data_table(columns = nil, **props) = _pending_app.data_table(columns, **props)
    def datatable(columns = nil, **props) = _pending_app.datatable(columns, **props)
    def data_column(label = nil, **props) = _pending_app.data_column(label, **props)
    def datacolumn(label = nil, **props) = _pending_app.datacolumn(label, **props)
    def data_row(cells = nil, **props) = _pending_app.data_row(cells, **props)
    def datarow(cells = nil, **props) = _pending_app.datarow(cells, **props)
    def data_cell(content = nil, **props) = _pending_app.data_cell(content, **props)
    def datacell(content = nil, **props) = _pending_app.datacell(content, **props)
    def expansion_tile(children = nil, **props) = _pending_app.expansion_tile(children, **props)
    def expansiontile(children = nil, **props) = _pending_app.expansiontile(children, **props)
    def expansion_panel(**props) = _pending_app.expansion_panel(**props)
    def expansionpanel(**props) = _pending_app.expansionpanel(**props)
    def expansion_panel_list(children = nil, **props) = _pending_app.expansion_panel_list(children, **props)
    def expansionpanellist(children = nil, **props) = _pending_app.expansionpanellist(children, **props)
    def dropdown(options = nil, **props) = _pending_app.dropdown(options, **props)
    def dropdown_option(key = nil, **props) = _pending_app.dropdown_option(key, **props)
    def dropdownoption(key = nil, **props) = _pending_app.dropdownoption(key, **props)
    def dropdown_m2(options = nil, **props) = _pending_app.dropdown_m2(options, **props)
    def dropdownm2(options = nil, **props) = _pending_app.dropdownm2(options, **props)
    def progress_bar(**props) = _pending_app.progress_bar(**props)
    def progressbar(**props) = _pending_app.progressbar(**props)
    def placeholder(content = nil, **props) = _pending_app.placeholder(content, **props)
    def page_view(children = nil, **props) = _pending_app.page_view(children, **props)
    def pageview(children = nil, **props) = _pending_app.pageview(children, **props)
    def progress_ring(**props) = _pending_app.progress_ring(**props)
    def progressring(**props) = _pending_app.progressring(**props)
    def range_slider(**props) = _pending_app.range_slider(**props)
    def rangeslider(**props) = _pending_app.rangeslider(**props)
    def responsive_row(children = nil, **props, &block) = _pending_app.responsive_row(children, **props, &block)
    def responsiverow(children = nil, **props, &block) = _pending_app.responsiverow(children, **props, &block)
    def reorderable_drag_handle(content = nil, **props) = _pending_app.reorderable_drag_handle(content, **props)
    def reorderabledraghandle(content = nil, **props) = _pending_app.reorderabledraghandle(content, **props)
    def reorderable_list_view(children = nil, **props) = _pending_app.reorderable_list_view(children, **props)
    def reorderablelistview(children = nil, **props) = _pending_app.reorderablelistview(children, **props)
    def safe_area(content = nil, **props) = _pending_app.safe_area(content, **props)
    def safearea(content = nil, **props) = _pending_app.safearea(content, **props)
    def segment(value = nil, **props) = _pending_app.segment(value, **props)
    def segmented_button(segments = nil, **props) = _pending_app.segmented_button(segments, **props)
    def segmentedbutton(segments = nil, **props) = _pending_app.segmentedbutton(segments, **props)
    def selection_area(content = nil, **props) = _pending_app.selection_area(content, **props)
    def selectionarea(content = nil, **props) = _pending_app.selectionarea(content, **props)
    def search_bar(children = nil, **props) = _pending_app.search_bar(children, **props)
    def searchbar(children = nil, **props) = _pending_app.searchbar(children, **props)
    def semantics(content = nil, **props) = _pending_app.semantics(content, **props)
    def time_picker(**props) = _pending_app.time_picker(**props)
    def timepicker(**props) = _pending_app.timepicker(**props)
    def badge(label = nil, **props) = _pending_app.badge(label, **props)
    def chip(label = nil, **props) = _pending_app.chip(label, **props)
    def circle_avatar(content = nil, **props) = _pending_app.circle_avatar(content, **props)
    def circleavatar(content = nil, **props) = _pending_app.circleavatar(content, **props)
    def banner(content = nil, **props) = _pending_app.banner(content, **props)
    def bottom_app_bar(content = nil, **props) = _pending_app.bottom_app_bar(content, **props)
    def bottomappbar(content = nil, **props) = _pending_app.bottomappbar(content, **props)
    def text(value = nil, **props) = _pending_app.text(value, **props)
    def button(**props) = _pending_app.button(**props)
    def elevated_button(**props) = _pending_app.elevated_button(**props)
    def text_field(value = nil, **props) = _pending_app.text_field(value, **props)
    def textfield(value = nil, **props) = _pending_app.textfield(value, **props)
    def icon(icon = nil, **props) = _pending_app.icon(icon, **props)
    def image(src = nil, **props) = _pending_app.image(src, **props)
    def icon_button(icon = nil, **props) = _pending_app.icon_button(icon, **props)
    def iconbutton(icon = nil, **props) = _pending_app.iconbutton(icon, **props)
    def popup_menu_button(items = nil, **props) = _pending_app.popup_menu_button(items, **props)
    def popupmenubutton(items = nil, **props) = _pending_app.popupmenubutton(items, **props)
    def popup_menu_item(content = nil, **props) = _pending_app.popup_menu_item(content, **props)
    def popupmenuitem(content = nil, **props) = _pending_app.popupmenuitem(content, **props)
    def app_bar(**props) = _pending_app.app_bar(**props)
    def appbar(**props) = _pending_app.appbar(**props)
    def clipboard(**props) = _pending_app.clipboard(**props)
    def text_button(**props) = _pending_app.text_button(**props)
    def textbutton(**props) = _pending_app.textbutton(**props)
    def filled_button(**props) = _pending_app.filled_button(**props)
    def filledbutton(**props) = _pending_app.filledbutton(**props)
    def outlined_button(content = nil, **props) = _pending_app.outlined_button(content, **props)
    def outlinedbutton(content = nil, **props) = _pending_app.outlinedbutton(content, **props)
    def outlined_icon_button(icon = nil, **props) = _pending_app.outlined_icon_button(icon, **props)
    def outlinediconbutton(icon = nil, **props) = _pending_app.outlinediconbutton(icon, **props)
    def checkbox(**props) = _pending_app.checkbox(**props)
    def switch(**props) = _pending_app.switch(**props)
    def slider(**props) = _pending_app.slider(**props)
    def transparent_pointer(content = nil, **props) = _pending_app.transparent_pointer(content, **props)
    def transparentpointer(content = nil, **props) = _pending_app.transparentpointer(content, **props)
    def radio(**props) = _pending_app.radio(**props)
    def radio_group(content = nil, **props) = _pending_app.radio_group(content, **props)
    def radiogroup(content = nil, **props) = _pending_app.radiogroup(content, **props)
    def alert_dialog(**props) = _pending_app.alert_dialog(**props)
    def alertdialog(**props) = _pending_app.alertdialog(**props)
    def snack_bar(content = nil, **props) = _pending_app.snack_bar(content, **props)
    def snackbar(content = nil, **props) = _pending_app.snackbar(content, **props)
    def bottom_sheet(content = nil, **props) = _pending_app.bottom_sheet(content, **props)
    def bottomsheet(content = nil, **props) = _pending_app.bottomsheet(content, **props)
    def markdown(value = nil, **props) = _pending_app.markdown(value, **props)
    def floating_action_button(**props) = _pending_app.floating_action_button(**props)
    def floatingactionbutton(**props) = _pending_app.floatingactionbutton(**props)
    def tabs(content = nil, **props, &block) = _pending_app.tabs(content, **props, &block)
    def tab(label = nil, **props, &block) = _pending_app.tab(label, **props, &block)
    def tab_bar(tabs = nil, **props, &block) = _pending_app.tab_bar(tabs, **props, &block)
    def tabbar(tabs = nil, **props, &block) = _pending_app.tabbar(tabs, **props, &block)
    def tab_bar_view(children = nil, **props, &block) = _pending_app.tab_bar_view(children, **props, &block)
    def tabbarview(children = nil, **props, &block) = _pending_app.tabbarview(children, **props, &block)
    def navigation_bar(**props, &block) = _pending_app.navigation_bar(**props, &block)
    def navigationbar(**props, &block) = _pending_app.navigationbar(**props, &block)
    def navigation_bar_destination(**props, &block) = _pending_app.navigation_bar_destination(**props, &block)
    def navigationbardestination(**props, &block) = _pending_app.navigationbardestination(**props, &block)
    def navigation_rail(**props, &block) = _pending_app.navigation_rail(**props, &block)
    def navigationrail(**props, &block) = _pending_app.navigationrail(**props, &block)
    def navigation_rail_destination(**props, &block) = _pending_app.navigation_rail_destination(**props, &block)
    def navigationraildestination(**props, &block) = _pending_app.navigationraildestination(**props, &block)
    def navigation_drawer(children = nil, **props) = _pending_app.navigation_drawer(children, **props)
    def navigationdrawer(children = nil, **props) = _pending_app.navigationdrawer(children, **props)
    def navigation_drawer_destination(**props) = _pending_app.navigation_drawer_destination(**props)
    def navigationdrawerdestination(**props) = _pending_app.navigationdrawerdestination(**props)
    def bar_chart(**props) = _pending_app.bar_chart(**props)
    def barchart(**props) = _pending_app.barchart(**props)
    def bar_chart_group(**props) = _pending_app.bar_chart_group(**props)
    def barchartgroup(**props) = _pending_app.barchartgroup(**props)
    def bar_chart_rod(**props) = _pending_app.bar_chart_rod(**props)
    def barchartrod(**props) = _pending_app.barchartrod(**props)
    def bar_chart_rod_stack_item(**props) = _pending_app.bar_chart_rod_stack_item(**props)
    def barchartrodstackitem(**props) = _pending_app.barchartrodstackitem(**props)
    def line_chart(**props) = _pending_app.line_chart(**props)
    def linechart(**props) = _pending_app.linechart(**props)
    def line_chart_data(**props) = _pending_app.line_chart_data(**props)
    def linechartdata(**props) = _pending_app.linechartdata(**props)
    def line_chart_data_point(**props) = _pending_app.line_chart_data_point(**props)
    def linechartdatapoint(**props) = _pending_app.linechartdatapoint(**props)
    def pie_chart(**props) = _pending_app.pie_chart(**props)
    def piechart(**props) = _pending_app.piechart(**props)
    def pie_chart_section(**props) = _pending_app.pie_chart_section(**props)
    def piechartsection(**props) = _pending_app.piechartsection(**props)
    def candlestick_chart(**props) = _pending_app.candlestick_chart(**props)
    def candlestickchart(**props) = _pending_app.candlestickchart(**props)
    def candlestick_chart_spot(**props) = _pending_app.candlestick_chart_spot(**props)
    def candlestickchartspot(**props) = _pending_app.candlestickchartspot(**props)
    def radar_chart(**props) = _pending_app.radar_chart(**props)
    def radarchart(**props) = _pending_app.radarchart(**props)
    def radar_chart_title(**props) = _pending_app.radar_chart_title(**props)
    def radarcharttitle(**props) = _pending_app.radarcharttitle(**props)
    def radar_data_set(**props) = _pending_app.radar_data_set(**props)
    def radardataset(**props) = _pending_app.radardataset(**props)
    def radar_data_set_entry(**props) = _pending_app.radar_data_set_entry(**props)
    def radardatasetentry(**props) = _pending_app.radardatasetentry(**props)
    def scatter_chart(**props) = _pending_app.scatter_chart(**props)
    def scatterchart(**props) = _pending_app.scatterchart(**props)
    def scatter_chart_spot(**props) = _pending_app.scatter_chart_spot(**props)
    def scatterchartspot(**props) = _pending_app.scatterchartspot(**props)
    def chart_axis(**props) = _pending_app.chart_axis(**props)
    def chartaxis(**props) = _pending_app.chartaxis(**props)
    def chart_axis_label(**props) = _pending_app.chart_axis_label(**props)
    def chartaxislabel(**props) = _pending_app.chartaxislabel(**props)
    def web_view(**props) = _pending_app.web_view(**props)
    def webview(**props) = _pending_app.webview(**props)
    def fab(content = nil, **props) = _pending_app.fab(content, **props)
    def cupertino_button(content = nil, **props) = _pending_app.cupertino_button(content, **props)
    def cupertinobutton(content = nil, **props) = _pending_app.cupertinobutton(content, **props)
    def cupertino_filled_button(content = nil, **props) = _pending_app.cupertino_filled_button(content, **props)
    def cupertinofilledbutton(content = nil, **props) = _pending_app.cupertinofilledbutton(content, **props)
    def cupertino_tinted_button(content = nil, **props) = _pending_app.cupertino_tinted_button(content, **props)
    def cupertinotintedbutton(content = nil, **props) = _pending_app.cupertinotintedbutton(content, **props)
    def cupertino_checkbox(**props) = _pending_app.cupertino_checkbox(**props)
    def cupertinocheckbox(**props) = _pending_app.cupertinocheckbox(**props)
    def cupertino_text_field(value = nil, **props) = _pending_app.cupertino_text_field(value, **props)
    def cupertinotextfield(value = nil, **props) = _pending_app.cupertinotextfield(value, **props)
    def cupertino_timer_picker(**props) = _pending_app.cupertino_timer_picker(**props)
    def cupertinotimerpicker(**props) = _pending_app.cupertinotimerpicker(**props)
    def cupertino_switch(**props) = _pending_app.cupertino_switch(**props)
    def cupertinoswitch(**props) = _pending_app.cupertinoswitch(**props)
    def cupertino_slider(**props) = _pending_app.cupertino_slider(**props)
    def cupertinoslider(**props) = _pending_app.cupertinoslider(**props)
    def cupertino_radio(**props) = _pending_app.cupertino_radio(**props)
    def cupertinoradio(**props) = _pending_app.cupertinoradio(**props)
    def cupertino_alert_dialog(**props) = _pending_app.cupertino_alert_dialog(**props)
    def cupertinoalertdialog(**props) = _pending_app.cupertinoalertdialog(**props)
    def cupertino_action_sheet(**props) = _pending_app.cupertino_action_sheet(**props)
    def cupertinoactionsheet(**props) = _pending_app.cupertinoactionsheet(**props)
    def cupertino_action_sheet_action(**props) = _pending_app.cupertino_action_sheet_action(**props)
    def cupertinoactionsheetaction(**props) = _pending_app.cupertinoactionsheetaction(**props)
    def cupertino_activity_indicator(**props) = _pending_app.cupertino_activity_indicator(**props)
    def cupertinoactivityindicator(**props) = _pending_app.cupertinoactivityindicator(**props)
    def cupertino_app_bar(**props) = _pending_app.cupertino_app_bar(**props)
    def cupertinoappbar(**props) = _pending_app.cupertinoappbar(**props)
    def cupertino_bottom_sheet(content = nil, **props) = _pending_app.cupertino_bottom_sheet(content, **props)
    def cupertinobottomsheet(content = nil, **props) = _pending_app.cupertinobottomsheet(content, **props)
    def cupertino_date_picker(**props) = _pending_app.cupertino_date_picker(**props)
    def cupertinodatepicker(**props) = _pending_app.cupertinodatepicker(**props)
    def cupertino_dialog_action(**props) = _pending_app.cupertino_dialog_action(**props)
    def cupertinodialogaction(**props) = _pending_app.cupertinodialogaction(**props)
    def cupertino_context_menu(**props) = _pending_app.cupertino_context_menu(**props)
    def cupertinocontextmenu(**props) = _pending_app.cupertinocontextmenu(**props)
    def cupertino_context_menu_action(**props) = _pending_app.cupertino_context_menu_action(**props)
    def cupertinocontextmenuaction(**props) = _pending_app.cupertinocontextmenuaction(**props)
    def cupertino_list_tile(**props) = _pending_app.cupertino_list_tile(**props)
    def cupertinolisttile(**props) = _pending_app.cupertinolisttile(**props)
    def cupertino_navigation_bar(**props) = _pending_app.cupertino_navigation_bar(**props)
    def cupertinonavigationbar(**props) = _pending_app.cupertinonavigationbar(**props)
    def cupertino_picker(children = nil, **props) = _pending_app.cupertino_picker(children, **props)
    def cupertinopicker(children = nil, **props) = _pending_app.cupertinopicker(children, **props)
    def cupertino_segmented_button(children = nil, **props) = _pending_app.cupertino_segmented_button(children, **props)
    def cupertinosegmentedbutton(children = nil, **props) = _pending_app.cupertinosegmentedbutton(children, **props)
    def cupertino_sliding_segmented_button(children = nil, **props) = _pending_app.cupertino_sliding_segmented_button(children, **props)
    def cupertinoslidingsegmentedbutton(children = nil, **props) = _pending_app.cupertinoslidingsegmentedbutton(children, **props)
    def duration(**parts) = duration_in_milliseconds(parts)

    class App
      include UI::ControlMethods

      attr_reader :page_props, :host, :port

      def initialize(host:, port:)
        @host = host
        @port = port
        @roots = []
        @services = []
        @stack = []
        @page_props = { "route" => "/" }
        @seq = 0
      end

      def set_endpoint!(host:, port:)
        @host = host
        @port = port
      end

      def page(**props, &block)
        @page_props.merge!(normalize_props(props))
        instance_eval(&block) if block
        self
      end

      def widget(type, **props, &block)
        control(type.to_s, **props, &block)
      end

      def control(type, **props, &block)
        mapped_props = props.dup
        prop_children = extract_children_prop(mapped_props)

        id = mapped_props.delete(:id)&.to_s || next_id(type)
        c = Ruflet::UI::ControlFactory.build(type.to_s, id: id, **normalize_props(mapped_props))
        attach(c)

        if block
          @stack.push(c)
          instance_eval(&block)
          @stack.pop
        end

        if prop_children
          Array(prop_children).each { |child| c.children << child if child.is_a?(Ruflet::Control) }
        end

        c
      end

      def service(type, **props, &block)
        mapped_props = props.dup
        id = mapped_props.delete(:id)&.to_s || next_id(type)
        svc = Ruflet::UI::ControlFactory.build(type.to_s, id: id, **normalize_props(mapped_props))
        @services << svc unless @services.include?(svc)
        svc
      end

      def duration(**parts)
        DSL.duration(**parts)
      end

      def run
        app_roots = @roots
        app_services = @services
        page_props = @page_props.dup

        Ruflet::Server.new(host: host, port: port) do |runtime_page|
          runtime_page.set_view_props(page_props)
          runtime_page.add_service(*app_services) if app_services.any?
          runtime_page.add(*app_roots)
        end.start
      end

      private

      def build_widget(type, **props, &block) = control(type.to_s, **props, &block)
      def build_service(type, **props, &block) = service(type.to_s, **props, &block)

      def attach(control)
        if @stack.empty?
          @roots << control
        else
          @stack.last.children << control
        end
      end

      def normalize_props(hash)
        hash.transform_keys(&:to_s).transform_values { |v| v.is_a?(Symbol) ? v.to_s : v }
      end

      def extract_children_prop(props)
        props.delete(:children) ||
          props.delete("children") ||
          props.delete(:controls) ||
          props.delete("controls")
      end

      def next_id(type)
        @seq += 1
        "#{type}_#{@seq}"
      end

      def duration_in_milliseconds(parts)
        DSL.send(:duration_in_milliseconds, parts)
      end

    end

    def duration_in_milliseconds(parts)
      return 0 if parts.nil? || parts.empty?

      DURATION_FACTORS_MS.reduce(0.0) do |sum, (key, factor)|
        sum + read_duration_part(parts, key) * factor
      end.round
    end

    def read_duration_part(parts, key)
      raw = parts[key] || parts[key.to_s]
      return 0.0 if raw.nil?
      return raw.to_f if raw.is_a?(Numeric)
      return raw.to_f if raw.is_a?(String) && raw.match?(/\A-?\d+(\.\d+)?\z/)

      0.0
    end
  end
end

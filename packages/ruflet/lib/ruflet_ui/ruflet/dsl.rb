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
    def column(**props, &block) = _pending_app.column(**props, &block)
    def center(**props, &block) = _pending_app.center(**props, &block)
    def row(**props, &block) = _pending_app.row(**props, &block)
    def stack(**props, &block) = _pending_app.stack(**props, &block)
    def grid_view(**props, &block) = _pending_app.grid_view(**props, &block)
    def gridview(**props, &block) = _pending_app.gridview(**props, &block)
    def container(**props, &block) = _pending_app.container(**props, &block)
    def gesture_detector(**props, &block) = _pending_app.gesture_detector(**props, &block)
    def gesturedetector(**props, &block) = _pending_app.gesturedetector(**props, &block)
    def draggable(**props, &block) = _pending_app.draggable(**props, &block)
    def drag_target(**props, &block) = _pending_app.drag_target(**props, &block)
    def dragtarget(**props, &block) = _pending_app.dragtarget(**props, &block)
    def text(value = nil, **props) = _pending_app.text(value, **props)
    def button(**props) = _pending_app.button(**props)
    def elevated_button(**props) = _pending_app.elevated_button(**props)
    def text_field(**props) = _pending_app.text_field(**props)
    def textfield(**props) = _pending_app.textfield(**props)
    def icon(**props) = _pending_app.icon(**props)
    def image(src = nil, **props) = _pending_app.image(src, **props)
    def icon_button(**props) = _pending_app.icon_button(**props)
    def iconbutton(**props) = _pending_app.iconbutton(**props)
    def app_bar(**props) = _pending_app.app_bar(**props)
    def appbar(**props) = _pending_app.appbar(**props)
    def clipboard(**props) = _pending_app.clipboard(**props)
    def text_button(**props) = _pending_app.text_button(**props)
    def textbutton(**props) = _pending_app.textbutton(**props)
    def filled_button(**props) = _pending_app.filled_button(**props)
    def filledbutton(**props) = _pending_app.filledbutton(**props)
    def checkbox(**props) = _pending_app.checkbox(**props)
    def radio(**props) = _pending_app.radio(**props)
    def radio_group(**props) = _pending_app.radio_group(**props)
    def radiogroup(**props) = _pending_app.radiogroup(**props)
    def alert_dialog(**props) = _pending_app.alert_dialog(**props)
    def alertdialog(**props) = _pending_app.alertdialog(**props)
    def snack_bar(**props) = _pending_app.snack_bar(**props)
    def snackbar(**props) = _pending_app.snackbar(**props)
    def bottom_sheet(**props) = _pending_app.bottom_sheet(**props)
    def bottomsheet(**props) = _pending_app.bottomsheet(**props)
    def markdown(value = nil, **props) = _pending_app.markdown(value, **props)
    def floating_action_button(**props) = _pending_app.floating_action_button(**props)
    def floatingactionbutton(**props) = _pending_app.floatingactionbutton(**props)
    def tabs(**props, &block) = _pending_app.tabs(**props, &block)
    def tab(**props, &block) = _pending_app.tab(**props, &block)
    def tab_bar(**props, &block) = _pending_app.tab_bar(**props, &block)
    def tabbar(**props, &block) = _pending_app.tabbar(**props, &block)
    def tab_bar_view(**props, &block) = _pending_app.tab_bar_view(**props, &block)
    def tabbarview(**props, &block) = _pending_app.tabbarview(**props, &block)
    def navigation_bar(**props, &block) = _pending_app.navigation_bar(**props, &block)
    def navigationbar(**props, &block) = _pending_app.navigationbar(**props, &block)
    def navigation_bar_destination(**props, &block) = _pending_app.navigation_bar_destination(**props, &block)
    def navigationbardestination(**props, &block) = _pending_app.navigationbardestination(**props, &block)
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
    def cupertino_button(**props) = _pending_app.cupertino_button(**props)
    def cupertinobutton(**props) = _pending_app.cupertinobutton(**props)
    def cupertino_filled_button(**props) = _pending_app.cupertino_filled_button(**props)
    def cupertinofilledbutton(**props) = _pending_app.cupertinofilledbutton(**props)
    def cupertino_text_field(**props) = _pending_app.cupertino_text_field(**props)
    def cupertinotextfield(**props) = _pending_app.cupertinotextfield(**props)
    def cupertino_switch(**props) = _pending_app.cupertino_switch(**props)
    def cupertinoswitch(**props) = _pending_app.cupertinoswitch(**props)
    def cupertino_slider(**props) = _pending_app.cupertino_slider(**props)
    def cupertinoslider(**props) = _pending_app.cupertinoslider(**props)
    def cupertino_alert_dialog(**props) = _pending_app.cupertino_alert_dialog(**props)
    def cupertinoalertdialog(**props) = _pending_app.cupertinoalertdialog(**props)
    def cupertino_action_sheet(**props) = _pending_app.cupertino_action_sheet(**props)
    def cupertinoactionsheet(**props) = _pending_app.cupertinoactionsheet(**props)
    def cupertino_dialog_action(**props) = _pending_app.cupertino_dialog_action(**props)
    def cupertinodialogaction(**props) = _pending_app.cupertinodialogaction(**props)
    def cupertino_navigation_bar(**props) = _pending_app.cupertino_navigation_bar(**props)
    def cupertinonavigationbar(**props) = _pending_app.cupertinonavigationbar(**props)
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

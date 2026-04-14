# frozen_string_literal: true

module Ruflet
  module UI
    module MaterialControlMethods
      def view(**props, &block) = build_widget(:view, **props, &block)
      def column(**props, &block) = build_widget(:column, **props, &block)

      def center(**props, &block)
        mapped = props.dup
        defaults = { expand: true, alignment: { x: 0, y: 0 } }

        if block
          nested = WidgetBuilder.new
          block_result = nested.instance_eval(&block)
          child =
            if nested.children.any?
              nested.children.first
            elsif block_result.is_a?(Ruflet::Control)
              block_result
            end
          mapped[:content] = child if child
        end

        build_widget(:container, **normalize_container_props(defaults.merge(mapped)))
      end

      def row(**props, &block) = build_widget(:row, **props, &block)
      def stack(**props, &block) = build_widget(:stack, **props, &block)
      def grid_view(**props, &block) = build_widget(:gridview, **props, &block)
      def gridview(**props, &block) = grid_view(**props, &block)
      def container(**props, &block) = build_widget(:container, **normalize_container_props(props), &block)
      def gesture_detector(**props, &block) = build_widget(:gesturedetector, **props, &block)
      def gesturedetector(**props, &block) = gesture_detector(**props, &block)
      def draggable(**props, &block) = build_widget(:draggable, **props, &block)
      def drag_target(**props, &block) = build_widget(:dragtarget, **props, &block)
      def dragtarget(**props, &block) = drag_target(**props, &block)

      def text(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:text, **mapped)
      end

      def button(**props) = build_widget(:button, **props)
      # Ruflet currently uses a single Material button control schema.
      # Keep elevated_button DSL available by routing to :button.
      def elevated_button(**props) = build_widget(:button, **props)
      def text_button(**props) = build_widget(:textbutton, **props)
      def textbutton(**props) = text_button(**props)
      def filled_button(**props) = build_widget(:filledbutton, **props)
      def filledbutton(**props) = filled_button(**props)

      def icon_button(**props) = build_widget(:iconbutton, **props)
      def iconbutton(**props) = icon_button(**props)
      def text_field(**props) = build_widget(:textfield, **props)
      def textfield(**props) = text_field(**props)
      def checkbox(**props) = build_widget(:checkbox, **props)
      def radio(**props) = build_widget(:radio, **props)
      def radio_group(**props) = build_widget(:radiogroup, **props)
      def radiogroup(**props) = radio_group(**props)
      def alert_dialog(**props) = build_widget(:alertdialog, **props)
      def alertdialog(**props) = alert_dialog(**props)
      def snack_bar(**props) = build_widget(:snackbar, **props)
      def snackbar(**props) = snack_bar(**props)
      def bottom_sheet(**props) = build_widget(:bottomsheet, **props)
      def bottomsheet(**props) = bottom_sheet(**props)

      def markdown(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:markdown, **mapped)
      end

      def icon(**props) = build_widget(:icon, **props)

      def image(src = nil, src_base64: nil, placeholder_src: nil, **props)
        mapped = props.dup
        mapped[:src] = normalize_image_source(src) unless src.nil?
        mapped[:src] = normalize_image_source(src_base64) if mapped[:src].nil? && !src_base64.nil?
        mapped[:placeholder_src] = normalize_image_source(placeholder_src) unless placeholder_src.nil?
        build_widget(:image, **mapped)
      end

      def app_bar(**props) = build_widget(:appbar, **props)
      def appbar(**props) = app_bar(**props)
      def url_launcher(**props) = build_widget(:url_launcher, **props)
      def clipboard(**props) = build_widget(:clipboard, **props)
      def floating_action_button(**props) = build_widget(:floatingactionbutton, **props)
      def floatingactionbutton(**props) = floating_action_button(**props)
      def tabs(**props, &block) = build_widget(:tabs, **props, &block)
      def tab(**props, &block) = build_widget(:tab, **props, &block)
      def tab_bar(**props, &block) = build_widget(:tabbar, **props, &block)
      def tabbar(**props, &block) = tab_bar(**props, &block)
      def tab_bar_view(**props, &block) = build_widget(:tabbarview, **props, &block)
      def tabbarview(**props, &block) = tab_bar_view(**props, &block)
      def navigation_bar(**props, &block) = build_widget(:navigationbar, **props, &block)
      def navigationbar(**props, &block) = navigation_bar(**props, &block)
      def navigation_bar_destination(**props, &block) = build_widget(:navigationbardestination, **props, &block)
      def navigationbardestination(**props, &block) = navigation_bar_destination(**props, &block)
      def bar_chart(**props) = build_widget(:barchart, **props)
      def barchart(**props) = bar_chart(**props)
      def bar_chart_group(**props) = build_widget(:barchartgroup, **props)
      def barchartgroup(**props) = bar_chart_group(**props)
      def bar_chart_rod(**props) = build_widget(:barchartrod, **props)
      def barchartrod(**props) = bar_chart_rod(**props)
      def bar_chart_rod_stack_item(**props) = build_widget(:barchartrodstackitem, **props)
      def barchartrodstackitem(**props) = bar_chart_rod_stack_item(**props)
      def line_chart(**props) = build_widget(:linechart, **props)
      def linechart(**props) = line_chart(**props)
      def line_chart_data(**props) = build_widget(:linechartdata, **props)
      def linechartdata(**props) = line_chart_data(**props)
      def line_chart_data_point(**props) = build_widget(:linechartdatapoint, **props)
      def linechartdatapoint(**props) = line_chart_data_point(**props)
      def pie_chart(**props) = build_widget(:piechart, **props)
      def piechart(**props) = pie_chart(**props)
      def pie_chart_section(**props) = build_widget(:piechartsection, **props)
      def piechartsection(**props) = pie_chart_section(**props)
      def candlestick_chart(**props) = build_widget(:candlestickchart, **props)
      def candlestickchart(**props) = candlestick_chart(**props)
      def candlestick_chart_spot(**props) = build_widget(:candlestickchartspot, **props)
      def candlestickchartspot(**props) = candlestick_chart_spot(**props)
      def radar_chart(**props) = build_widget(:radarchart, **props)
      def radarchart(**props) = radar_chart(**props)
      def radar_chart_title(**props) = build_widget(:radarcharttitle, **props)
      def radarcharttitle(**props) = radar_chart_title(**props)
      def radar_data_set(**props) = build_widget(:radardataset, **props)
      def radardataset(**props) = radar_data_set(**props)
      def radar_data_set_entry(**props) = build_widget(:radardatasetentry, **props)
      def radardatasetentry(**props) = radar_data_set_entry(**props)
      def scatter_chart(**props) = build_widget(:scatterchart, **props)
      def scatterchart(**props) = scatter_chart(**props)
      def scatter_chart_spot(**props) = build_widget(:scatterchartspot, **props)
      def scatterchartspot(**props) = scatter_chart_spot(**props)
      def chart_axis(**props) = build_widget(:chartaxis, **props)
      def chartaxis(**props) = chart_axis(**props)
      def chart_axis_label(**props) = build_widget(:chartaxislabel, **props)
      def chartaxislabel(**props) = chart_axis_label(**props)
      def web_view(**props) = build_widget(:webview, **props)
      def webview(**props) = web_view(**props)

      def fab(content = nil, **props)
        mapped = normalize_fab_props(props.dup, content)
        build_widget(:floatingactionbutton, **mapped)
      end

      private

      def normalize_fab_props(props, content)
        mapped = props.dup

        explicit_icon = mapped[:icon] || mapped["icon"]
        if explicit_icon.is_a?(Ruflet::Control) && content.nil?
          mapped.delete(:icon)
          mapped.delete("icon")
          content = explicit_icon
        elsif !explicit_icon.nil? && !explicit_icon.is_a?(Ruflet::IconData)
          raise ArgumentError, "fab icon must use Ruflet::MaterialIcons (or another Ruflet::IconData) or an icon(...) control"
        end

        unless content.nil?
          mapped[:content] =
            case content
            when Ruflet::Control
              content
            when Ruflet::IconData
              icon(icon: content)
            else
              raise ArgumentError, "fab content must be an icon(...) control or Ruflet::MaterialIcons value"
            end
        end

        mapped
      end

      def normalize_image_source(value)
        return value unless value.is_a?(Array)
        return value.pack("C*") if value.all? { |v| v.is_a?(Integer) }
        value
      end

      # Flet container alignment expects a vector-like object ({x:, y:}),
      # not a plain string. Keep common shorthand compatible.
      def normalize_container_props(props)
        mapped = props.dup
        alignment = mapped[:alignment] || mapped["alignment"]
        if alignment == "center" || alignment == :center
          mapped[:alignment] = { x: 0, y: 0 }
          mapped.delete("alignment")
        end
        mapped
      end

    end
  end
end

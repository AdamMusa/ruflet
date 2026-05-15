# frozen_string_literal: true

module Ruflet
  module UI
    module MaterialControlMethods
      def view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:view, **mapped, &block)
      end
      def column(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:column, **mapped, &block)
      end

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

      def row(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:row, **mapped, &block)
      end
      def stack(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:stack, **mapped, &block)
      end
      def grid_view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:gridview, **mapped, &block)
      end
      def gridview(children = nil, **props, &block) = grid_view(children, **props, &block)
      def container(**props, &block) = build_widget(:container, **normalize_container_props(props), &block)
      def animated_switcher(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:animatedswitcher, **mapped)
      end
      def animatedswitcher(content = nil, **props) = animated_switcher(content, **props)
      def auto_complete(suggestions = nil, **props)
        mapped = props.dup
        mapped[:suggestions] = suggestions unless suggestions.nil?
        build_widget(:autocomplete, **mapped)
      end
      def autocomplete(suggestions = nil, **props) = auto_complete(suggestions, **props)
      def auto_complete_suggestion(key = nil, **props)
        mapped = props.dup
        mapped[:key] = key unless key.nil?
        build_widget(:autocompletesuggestion, **mapped)
      end
      def autocomplete_suggestion(key = nil, **props) = auto_complete_suggestion(key, **props)
      def autocompletesuggestion(key = nil, **props) = auto_complete_suggestion(key, **props)
      def context_menu(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:contextmenu, **mapped)
      end
      def contextmenu(content = nil, **props) = context_menu(content, **props)
      def gesture_detector(**props, &block) = build_widget(:gesturedetector, **props, &block)
      def gesturedetector(**props, &block) = gesture_detector(**props, &block)
      def draggable(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:draggable, **mapped, &block)
      end
      def dismissible(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:dismissible, **mapped)
      end
      def drag_target(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:dragtarget, **mapped, &block)
      end
      def dragtarget(content = nil, **props, &block) = drag_target(content, **props, &block)
      def card(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:card, **mapped)
      end
      def list_tile(**props) = build_widget(:listtile, **props)
      def listtile(**props) = list_tile(**props)
      def list_view(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:listview, **mapped)
      end
      def listview(children = nil, **props) = list_view(children, **props)
      def menu_bar(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:menubar, **mapped)
      end
      def menubar(children = nil, **props) = menu_bar(children, **props)
      def menu_item_button(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:menuitembutton, **mapped)
      end
      def menuitembutton(content = nil, **props) = menu_item_button(content, **props)
      def merge_semantics(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:mergesemantics, **mapped)
      end
      def mergesemantics(content = nil, **props) = merge_semantics(content, **props)
      def submenu_button(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:submenubutton, **mapped)
      end
      def submenubutton(children = nil, **props) = submenu_button(children, **props)
      def divider(**props) = build_widget(:divider, **props)
      def vertical_divider(**props) = build_widget(:verticaldivider, **props)
      def verticaldivider(**props) = vertical_divider(**props)
      def window_drag_area(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:windowdragarea, **mapped)
      end
      def windowdragarea(content = nil, **props) = window_drag_area(content, **props)
      def date_picker(**props) = build_widget(:datepicker, **props)
      def datepicker(**props) = date_picker(**props)
      def date_range_picker(**props) = build_widget(:daterangepicker, **props)
      def daterangepicker(**props) = date_range_picker(**props)
      def data_table(columns = nil, **props)
        mapped = props.dup
        mapped[:columns] = columns unless columns.nil?
        build_widget(:datatable, **mapped)
      end
      def datatable(columns = nil, **props) = data_table(columns, **props)
      def data_column(label = nil, **props)
        mapped = props.dup
        mapped[:label] = label unless label.nil?
        build_widget(:datacolumn, **mapped)
      end
      def datacolumn(label = nil, **props) = data_column(label, **props)
      def data_row(cells = nil, **props)
        mapped = props.dup
        mapped[:cells] = cells unless cells.nil?
        build_widget(:datarow, **mapped)
      end
      def datarow(cells = nil, **props) = data_row(cells, **props)
      def data_cell(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:datacell, **mapped)
      end
      def datacell(content = nil, **props) = data_cell(content, **props)
      def expansion_tile(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:expansiontile, **mapped)
      end
      def expansiontile(children = nil, **props) = expansion_tile(children, **props)
      def expansion_panel(**props) = build_widget(:expansionpanel, **props)
      def expansionpanel(**props) = expansion_panel(**props)
      def expansion_panel_list(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:expansionpanellist, **mapped)
      end
      def expansionpanellist(children = nil, **props) = expansion_panel_list(children, **props)
      def dropdown(options = nil, **props)
        mapped = props.dup
        mapped[:options] = options unless options.nil?
        build_widget(:dropdown, **mapped)
      end
      def dropdown_option(key = nil, **props)
        mapped = props.dup
        mapped[:key] = key unless key.nil?
        build_widget(:dropdownoption, **mapped)
      end
      def dropdownoption(key = nil, **props) = dropdown_option(key, **props)
      def dropdown_m2(options = nil, **props)
        mapped = props.dup
        mapped[:options] = options unless options.nil?
        build_widget(:dropdownm2, **mapped)
      end
      def dropdownm2(options = nil, **props) = dropdown_m2(options, **props)
      def progress_bar(**props) = build_widget(:progressbar, **props)
      def progressbar(**props) = progress_bar(**props)
      def placeholder(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:placeholder, **mapped)
      end
      def page_view(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:pageview, **mapped)
      end
      def pageview(children = nil, **props) = page_view(children, **props)
      def progress_ring(**props) = build_widget(:progressring, **props)
      def progressring(**props) = progress_ring(**props)
      def range_slider(**props) = build_widget(:rangeslider, **props)
      def rangeslider(**props) = range_slider(**props)
      def responsive_row(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:responsiverow, **mapped, &block)
      end
      def responsiverow(children = nil, **props, &block) = responsive_row(children, **props, &block)
      def reorderable_drag_handle(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:reorderabledraghandle, **mapped)
      end
      def reorderabledraghandle(content = nil, **props) = reorderable_drag_handle(content, **props)
      def reorderable_list_view(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:reorderablelistview, **mapped)
      end
      def reorderablelistview(children = nil, **props) = reorderable_list_view(children, **props)
      def safe_area(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:safearea, **mapped)
      end
      def safearea(content = nil, **props) = safe_area(content, **props)
      def segment(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:segment, **mapped)
      end
      def segmented_button(segments = nil, **props)
        mapped = props.dup
        mapped[:segments] = segments unless segments.nil?
        build_widget(:segmentedbutton, **mapped)
      end
      def segmentedbutton(segments = nil, **props) = segmented_button(segments, **props)
      def selection_area(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:selectionarea, **mapped)
      end
      def selectionarea(content = nil, **props) = selection_area(content, **props)
      def search_bar(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:searchbar, **mapped)
      end
      def searchbar(children = nil, **props) = search_bar(children, **props)
      def semantics(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:semantics, **mapped)
      end
      def time_picker(**props) = build_widget(:timepicker, **props)
      def timepicker(**props) = time_picker(**props)
      def badge(label = nil, **props)
        mapped = props.dup
        mapped[:label] = label unless label.nil?
        build_widget(:badge, **mapped)
      end
      def chip(label = nil, **props)
        mapped = props.dup
        mapped[:label] = label unless label.nil?
        build_widget(:chip, **mapped)
      end
      def circle_avatar(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:circleavatar, **mapped)
      end
      def circleavatar(content = nil, **props) = circle_avatar(content, **props)
      def banner(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:banner, **mapped)
      end
      def bottom_app_bar(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:bottomappbar, **mapped)
      end
      def bottomappbar(content = nil, **props) = bottom_app_bar(content, **props)

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

      def icon_button(icon = nil, **props)
        mapped = props.dup
        mapped[:icon] = icon unless icon.nil?
        build_widget(:iconbutton, **mapped)
      end
      def iconbutton(icon = nil, **props) = icon_button(icon, **props)
      def popup_menu_button(items = nil, **props)
        mapped = props.dup
        mapped[:items] = items unless items.nil?
        build_widget(:popupmenubutton, **mapped)
      end
      def popupmenubutton(items = nil, **props) = popup_menu_button(items, **props)
      def popup_menu_item(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:popupmenuitem, **mapped)
      end
      def popupmenuitem(content = nil, **props) = popup_menu_item(content, **props)
      def text_field(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:textfield, **mapped)
      end
      def textfield(**props) = text_field(**props)
      def checkbox(**props) = build_widget(:checkbox, **props)
      def switch(**props) = build_widget(:switch, **props)
      def slider(**props) = build_widget(:slider, **props)
      def transparent_pointer(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:transparentpointer, **mapped)
      end
      def transparentpointer(content = nil, **props) = transparent_pointer(content, **props)
      def radio(**props) = build_widget(:radio, **props)
      def radio_group(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:radiogroup, **mapped)
      end
      def radiogroup(content = nil, **props) = radio_group(content, **props)
      def alert_dialog(**props) = build_widget(:alertdialog, **props)
      def alertdialog(**props) = alert_dialog(**props)
      def snack_bar(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:snackbar, **mapped)
      end
      def snackbar(content = nil, **props) = snack_bar(content, **props)
      def bottom_sheet(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:bottomsheet, **mapped)
      end
      def bottomsheet(content = nil, **props) = bottom_sheet(content, **props)

      def markdown(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:markdown, **mapped)
      end

      def icon(icon = nil, **props)
        mapped = props.dup
        mapped[:icon] = icon unless icon.nil?
        build_widget(:icon, **mapped)
      end

      def image(src = nil, src_base64: nil, placeholder_src: nil, **props)
        mapped = props.dup
        mapped[:src] = normalize_image_source(src) unless src.nil?
        mapped[:src_base64] = normalize_image_source(src_base64) unless src_base64.nil?
        mapped[:placeholder_src] = normalize_image_source(placeholder_src) unless placeholder_src.nil?
        build_widget(:image, **mapped)
      end

      def app_bar(**props) = build_widget(:appbar, **props)
      def appbar(**props) = app_bar(**props)
      def url_launcher(**props) = build_widget(:url_launcher, **props)
      def clipboard(**props) = build_widget(:clipboard, **props)
      def floating_action_button(**props) = build_widget(:floatingactionbutton, **props)
      def floatingactionbutton(**props) = floating_action_button(**props)
      def tabs(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:tabs, **mapped, &block)
      end

      def tab(label = nil, **props, &block)
        mapped = props.dup
        mapped[:label] = label unless label.nil?
        build_widget(:tab, **mapped, &block)
      end

      def tab_bar(tabs = nil, **props, &block)
        mapped = props.dup
        mapped[:tabs] = tabs unless tabs.nil?
        build_widget(:tabbar, **mapped, &block)
      end
      def tabbar(tabs = nil, **props, &block) = tab_bar(tabs, **props, &block)
      def tab_bar_view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:tabbarview, **mapped, &block)
      end
      def tabbarview(children = nil, **props, &block) = tab_bar_view(children, **props, &block)
      def navigation_bar(**props, &block) = build_widget(:navigationbar, **props, &block)
      def navigationbar(**props, &block) = navigation_bar(**props, &block)
      def navigation_bar_destination(**props, &block) = build_widget(:navigationbardestination, **props, &block)
      def navigationbardestination(**props, &block) = navigation_bar_destination(**props, &block)
      def navigation_rail(**props, &block) = build_widget(:navigationrail, **props, &block)
      def navigationrail(**props, &block) = navigation_rail(**props, &block)
      def navigation_rail_destination(**props, &block) = build_widget(:navigationraildestination, **props, &block)
      def navigationraildestination(**props, &block) = navigation_rail_destination(**props, &block)
      def navigation_drawer(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:navigationdrawer, **mapped)
      end
      def navigationdrawer(children = nil, **props) = navigation_drawer(children, **props)
      def navigation_drawer_destination(**props) = build_widget(:navigationdrawerdestination, **props)
      def navigationdrawerdestination(**props) = navigation_drawer_destination(**props)
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
        explicit_content =
          if mapped.key?(:content)
            mapped.delete(:content)
          elsif mapped.key?("content")
            mapped.delete("content")
          end

        content = explicit_content if content.nil?
        content = nil if blank_fab_content?(content) && !explicit_icon.nil?

        unless explicit_icon.nil? || explicit_icon.is_a?(Ruflet::IconData) || explicit_icon.is_a?(String) || explicit_icon.is_a?(Symbol) || explicit_icon.is_a?(Ruflet::Control)
          raise ArgumentError, "fab icon must use an icon name string or an icon(...) control"
        end

        unless content.nil?
          mapped[:content] =
            case content
            when Ruflet::Control
              content
            when Ruflet::IconData
              content.value
            when String, Symbol
              content.to_s
            else
              raise ArgumentError, "fab content must be a string or control"
            end
        end

        if explicit_icon.nil? && blank_fab_content?(content)
          raise ArgumentError, "fab requires icon or non-empty content"
        end

        mapped
      end

      def blank_fab_content?(content)
        content.respond_to?(:empty?) && content.empty?
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

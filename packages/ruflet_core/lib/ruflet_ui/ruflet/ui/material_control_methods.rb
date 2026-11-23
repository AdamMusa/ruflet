# frozen_string_literal: true

require_relative "animation_values"

module Ruflet
  module UI
    module MaterialControlMethods
      # Like MapControl#normalize_coordinates: nil means not given, and
      # coordinates that cannot be read raise ArgumentError (they used to
      # overflow the stack, or raise TypeError).
      def map_coordinates(value)
        case value
        when nil
          return nil
        when Array
          return { "latitude" => value[0], "longitude" => value[1] } if value.length >= 2
        when Hash
          latitude = value["latitude"] || value[:latitude] || value["lat"] || value[:lat]
          longitude = value["longitude"] || value[:longitude] || value["lon"] || value[:lon] || value["lng"] || value[:lng]
          return { "latitude" => latitude, "longitude" => longitude } unless latitude.nil? || longitude.nil?
        else
          return value unless value.respond_to?(:to_h)

          coordinates = value.to_h
          return map_coordinates(coordinates) unless coordinates.nil?
        end
        raise ArgumentError, "map coordinates must be [latitude, longitude] or a Hash with latitude and longitude, got #{value.inspect}"
      end

      # A nil point in a list is a mistake, not an unset value.
      def map_coordinate_list(value)
        Array(value).map do |coordinates|
          if coordinates.nil?
            raise ArgumentError, "map coordinates must be [latitude, longitude] or a Hash with latitude and longitude, got nil"
          end

          map_coordinates(coordinates)
        end
      end

      def base_page(**props, &block) = build_widget(:base_page, **props, &block)
      def basepage(**props, &block) = base_page(**props, &block)
      def dialogs(controls = nil, **props, &block)
        mapped = props.dup
        mapped[:controls] = controls unless controls.nil?
        build_with_block_children(:dialogs, "dialogs", mapped, block)
      end
      def pagelet(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_legacy_block_slot(:pagelet, "pagelet", :content, mapped, block)
      end
      def ruflet_app(**props) = build_widget(:ruflet_app, **props)
      def rufletapp(**props) = ruflet_app(**props)
      def service_registry(services = nil, **props)
        mapped = props.dup
        mapped[:services] = services unless services.nil?
        build_widget(:service_registry, **mapped)
      end
      def serviceregistry(services = nil, **props) = service_registry(services, **props)
      def window(**props) = build_widget(:window, **props)

      def view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:controls] = children unless children.nil?
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
          block_result = Ruflet::UI::BuildScope.within(nested) { nested.instance_eval(&block) }
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
      def indexed_stack(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:indexedstack, **mapped, &block)
      end
      def indexedstack(children = nil, **props, &block) = indexed_stack(children, **props, &block)
      def grid_view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:gridview, **mapped, &block)
      end
      def gridview(children = nil, **props, &block) = grid_view(children, **props, &block)
      def container(**props, &block) = build_with_legacy_block_slot(:container, "container", :content, normalize_container_props(props), block)
      def animated_switcher(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:animatedswitcher, "animated_switcher", :content, mapped, block)
      end
      def animatedswitcher(content = nil, **props, &block) = animated_switcher(content, **props, &block)
      def animation(duration = nil, **props)
        duration = props.delete(:duration) if duration.nil? && props.key?(:duration)
        AnimationValues.animation(duration, **props)
      end
      def animation_style(**props) = AnimationValues.animation_style(**props)
      def accelerometer(**props) = build_service(:accelerometer, **props)
      def audio(**props) = build_service(:audio, **props)
      def audio_recorder(**props) = build_service(:audio_recorder, **props)
      def barometer(**props) = build_service(:barometer, **props)
      def battery(**props) = build_service(:battery, **props)
      def browser_context_menu(**props) = build_service(:browser_context_menu, **props)
      def camera(**props, &block) = build_with_block_slot(:camera, "camera", :content, props.dup, block)
      def connectivity(**props) = build_service(:connectivity, **props)
      def file_picker(**props) = build_service(:file_picker, **props)
      def flashlight(**props) = build_service(:flashlight, **props)
      def geolocator(**props) = build_service(:geolocator, **props)
      def gyroscope(**props) = build_service(:gyroscope, **props)
      def haptic_feedback(**props) = build_service(:haptic_feedback, **props)
      def local_auth(**props) = build_service(:local_authentication, **props)
      def local_authentication(**props) = build_service(:local_authentication, **props)
      def magnetometer(**props) = build_service(:magnetometer, **props)
      def permission_handler(**props) = build_service(:permission_handler, **props)
      def screen_brightness(**props) = build_service(:screen_brightness, **props)
      def secure_storage(**props) = build_service(:secure_storage, **props)
      def semantics_service(**props) = build_service(:semantics_service, **props)
      def shake_detector(**props) = build_service(:shake_detector, **props)
      def share(**props) = build_service(:share, **props)
      def shared_preferences(**props) = build_service(:shared_preferences, **props)
      def storage_paths(**props) = build_service(:storage_paths, **props)
      def url_launcher(**props) = build_service(:url_launcher, **props)
      def user_accelerometer(**props) = build_service(:user_accelerometer, **props)
      def wakelock(**props) = build_service(:wakelock, **props)
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
      def context_menu(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:contextmenu, "context_menu", :content, mapped, block)
      end
      def contextmenu(content = nil, **props, &block) = context_menu(content, **props, &block)
      def autofill_group(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:autofillgroup, "autofill_group", :content, mapped, block)
      end
      def autofillgroup(content = nil, **props, &block) = autofill_group(content, **props, &block)
      def hero(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:hero, "hero", :content, mapped, block)
      end
      def overlay(children = nil, **props, &block)
        mapped = props.dup
        mapped[:controls] = children unless children.nil?
        build_with_block_children(:overlay, "overlay", mapped, block)
      end
      def shader_mask(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:shadermask, "shader_mask", :content, mapped, block)
      end
      def shadermask(content = nil, **props, &block) = shader_mask(content, **props, &block)
      def shimmer(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:shimmer, "shimmer", :content, mapped, block)
      end
      def text_span(text = nil, **props)
        mapped = props.dup
        mapped[:text] = text unless text.nil?
        build_widget(:textspan, **mapped)
      end
      def textspan(text = nil, **props) = text_span(text, **props)
      def keyboard_listener(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:keyboardlistener, "keyboard_listener", :content, mapped, block)
      end
      def keyboardlistener(content = nil, **props, &block) = keyboard_listener(content, **props, &block)
      def form_row(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:formrow, "form_row", :content, mapped, block)
      end
      def formrow(content = nil, **props, &block) = form_row(content, **props, &block)
      def gesture_detector(**props, &block) = build_with_legacy_block_slot(:gesturedetector, "gesture_detector", :content, props.dup, block)
      def gesturedetector(**props, &block) = gesture_detector(**props, &block)
      def canvas(shapes = nil, **props, &block)
        mapped = props.dup
        mapped[:shapes] = shapes unless shapes.nil?
        build_with_block_slot(:canvas, "canvas", :shapes, mapped, block)
      end
      def line(**props) = build_widget(:line, **props)
      def circle(**props) = build_widget(:circle, **props)
      def arc(**props) = build_widget(:arc, **props)
      def color(**props) = build_widget(:color, **props)
      def canvas_color(**props) = color(**props)
      def fill(**props) = build_widget(:fill, **props)
      def oval(**props) = build_widget(:oval, **props)
      def points(**props) = build_widget(:points, **props)
      def rect(**props) = build_widget(:rect, **props)
      def path(**props) = build_widget(:path, **props)
      def shadow(**props) = build_widget(:shadow, **props)
      def paint(**props) = drawing_payload(props)
      def path_move_to(x = nil, y = nil, **props) = path_point_payload("MoveTo", x, y, props)
      def path_line_to(x = nil, y = nil, **props) = path_point_payload("LineTo", x, y, props)
      def path_arc(**props) = drawing_payload(props.merge(_type: "Arc"))
      def path_arc_to(**props) = drawing_payload(props.merge(_type: "ArcTo"))
      def path_oval(**props) = drawing_payload(props.merge(_type: "Oval"))
      def path_rect(**props) = drawing_payload(props.merge(_type: "Rect"))
      def path_quadratic_to(**props) = drawing_payload(props.merge(_type: "QuadraticTo"))
      def path_cubic_to(**props) = drawing_payload(props.merge(_type: "CubicTo"))
      def path_sub_path(**props) = drawing_payload(props.merge(_type: "SubPath"))
      def path_close(**props) = drawing_payload(props.merge(_type: "Close"))
      def draggable(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_legacy_block_slot(:draggable, "draggable", :content, mapped, block)
      end
      def draggable_scrollable_sheet(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:draggablescrollablesheet, **mapped, &block)
      end
      def draggablescrollablesheet(children = nil, **props, &block) = draggable_scrollable_sheet(children, **props, &block)
      def dismissible(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:dismissible, "dismissible", :content, mapped, block)
      end
      def drag_target(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_legacy_block_slot(:dragtarget, "drag_target", :content, mapped, block)
      end
      def dragtarget(content = nil, **props, &block) = drag_target(content, **props, &block)
      def card(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:card, "card", :content, mapped, block)
      end
      def carousel_view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:carouselview, **mapped, &block)
      end
      def carouselview(children = nil, **props, &block) = carousel_view(children, **props, &block)
      def list_section(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:listsection, **mapped, &block)
      end
      def listsection(children = nil, **props, &block) = list_section(children, **props, &block)
      def list_tile(**props) = build_widget(:listtile, **props)
      def listtile(**props) = list_tile(**props)
      def map(layers = nil, **props)
        mapped = props.dup
        mapped[:initial_center] = map_coordinates(mapped[:initial_center]) if mapped.key?(:initial_center)
        mapped[:layers] = layers unless layers.nil?
        build_widget(:map, **mapped)
      end
      def tile_layer(**props) = build_widget(:tilelayer, **props)
      def tilelayer(**props) = tile_layer(**props)
      def marker_layer(markers = nil, **props)
        mapped = props.dup
        mapped[:markers] = markers unless markers.nil?
        build_widget(:markerlayer, **mapped)
      end
      def markerlayer(markers = nil, **props) = marker_layer(markers, **props)
      def marker(content = nil, **props)
        mapped = props.dup
        mapped[:coordinates] = map_coordinates(mapped[:coordinates]) if mapped.key?(:coordinates)
        mapped[:content] = content unless content.nil?
        build_widget(:marker, **mapped)
      end
      def circle_layer(circles = nil, **props)
        mapped = props.dup
        mapped[:circles] = circles unless circles.nil?
        build_widget(:circlelayer, **mapped)
      end
      def circlelayer(circles = nil, **props) = circle_layer(circles, **props)
      def circle_marker(**props)
        mapped = props.dup
        mapped[:coordinates] = map_coordinates(mapped[:coordinates]) if mapped.key?(:coordinates)
        build_widget(:circlemarker, **mapped)
      end
      def circlemarker(**props) = circle_marker(**props)
      def polyline_layer(polylines = nil, **props)
        mapped = props.dup
        mapped[:polylines] = polylines unless polylines.nil?
        build_widget(:polylinelayer, **mapped)
      end
      def polylinelayer(polylines = nil, **props) = polyline_layer(polylines, **props)
      def polyline_marker(**props)
        mapped = props.dup
        mapped[:coordinates] = map_coordinate_list(mapped[:coordinates]) if mapped.key?(:coordinates)
        build_widget(:polylinemarker, **mapped)
      end
      def polylinemarker(**props) = polyline_marker(**props)
      def polygon_layer(polygons = nil, **props)
        mapped = props.dup
        mapped[:polygons] = polygons unless polygons.nil?
        build_widget(:polygonlayer, **mapped)
      end
      def polygonlayer(polygons = nil, **props) = polygon_layer(polygons, **props)
      def polygon_marker(**props)
        mapped = props.dup
        mapped[:coordinates] = map_coordinate_list(mapped[:coordinates]) if mapped.key?(:coordinates)
        build_widget(:polygonmarker, **mapped)
      end
      def polygonmarker(**props) = polygon_marker(**props)
      def simple_attribution(**props) = build_widget(:simpleattribution, **props)
      def simpleattribution(**props) = simple_attribution(**props)
      def map_layer(**props) = build_widget(:maplayer, **props)
      def maplayer(**props) = map_layer(**props)
      def rich_attribution(attributions = nil, **props)
        mapped = props.dup
        mapped[:attributions] = attributions unless attributions.nil?
        build_widget(:richattribution, **mapped)
      end
      def richattribution(attributions = nil, **props) = rich_attribution(attributions, **props)
      def image_source_attribution(image = nil, **props)
        mapped = props.dup
        mapped[:image] = image unless image.nil?
        build_widget(:imagesourceattribution, **mapped)
      end
      def imagesourceattribution(image = nil, **props) = image_source_attribution(image, **props)
      def text_source_attribution(text = nil, **props)
        mapped = props.dup
        mapped[:text] = text unless text.nil?
        build_widget(:textsourceattribution, **mapped)
      end
      def textsourceattribution(text = nil, **props) = text_source_attribution(text, **props)
      def list_view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:listview, "list_view", mapped, block)
      end
      def listview(children = nil, **props, &block) = list_view(children, **props, &block)
      def custom_scroll_view(slivers = nil, **props, &block)
        mapped = props.dup
        mapped[:slivers] = slivers unless slivers.nil?
        build_widget(:customscrollview, **mapped, &block)
      end
      def customscrollview(slivers = nil, **props, &block) = custom_scroll_view(slivers, **props, &block)
      def sliver_list(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:sliverlist, **mapped, &block)
      end
      def sliverlist(children = nil, **props, &block) = sliver_list(children, **props, &block)
      def sliver_grid(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:slivergrid, **mapped, &block)
      end
      def slivergrid(children = nil, **props, &block) = sliver_grid(children, **props, &block)
      def sliver_to_box_adapter(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:slivertoboxadapter, "sliver_to_box_adapter", :content, mapped, block)
      end
      def slivertoboxadapter(content = nil, **props, &block) = sliver_to_box_adapter(content, **props, &block)
      def sliver_fill_remaining(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:sliverfillremaining, "sliver_fill_remaining", :content, mapped, block)
      end
      def sliverfillremaining(content = nil, **props, &block) = sliver_fill_remaining(content, **props, &block)
      def sliver_app_bar(**props, &block) = build_with_block_slot(:sliverappbar, "sliver_app_bar", :actions, props.dup, block)
      def sliverappbar(**props, &block) = sliver_app_bar(**props, &block)
      def menu_bar(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:menubar, "menu_bar", mapped, block)
      end
      def menubar(children = nil, **props, &block) = menu_bar(children, **props, &block)
      def menu_item_button(content = nil, **props, &block)
        ignore_block("menu_item_button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:menuitembutton, **mapped)
      end
      def menuitembutton(content = nil, **props, &block) = menu_item_button(content, **props, &block)
      def merge_semantics(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:mergesemantics, "merge_semantics", :content, mapped, block)
      end
      def mergesemantics(content = nil, **props, &block) = merge_semantics(content, **props, &block)
      def submenu_button(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:submenubutton, "submenu_button", mapped, block)
      end
      def submenubutton(children = nil, **props, &block) = submenu_button(children, **props, &block)
      def divider(**props) = build_widget(:divider, **props)
      def vertical_divider(**props) = build_widget(:verticaldivider, **props)
      def verticaldivider(**props) = vertical_divider(**props)
      def window_drag_area(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:windowdragarea, "window_drag_area", :content, mapped, block)
      end
      def windowdragarea(content = nil, **props, &block) = window_drag_area(content, **props, &block)
      def date_picker(**props) = build_widget(:datepicker, **props)
      def datepicker(**props) = date_picker(**props)
      def date_range_picker(**props) = build_widget(:daterangepicker, **props)
      def daterangepicker(**props) = date_range_picker(**props)
      def data_table(columns = nil, **props, &block)
        mapped = props.dup
        mapped[:columns] = columns unless columns.nil?
        build_with_block_slot(:datatable, "data_table", :rows, mapped, block)
      end
      def datatable(columns = nil, **props, &block) = data_table(columns, **props, &block)
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
      def data_cell(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:datacell, "data_cell", :content, mapped, block)
      end
      def datacell(content = nil, **props, &block) = data_cell(content, **props, &block)
      def table(rows = nil, **props, &block)
        mapped = props.dup
        mapped[:rows] = rows unless rows.nil?
        build_widget(:table, **mapped, &block)
      end
      def table_row(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:tablerow, **mapped, &block)
      end
      def tablerow(children = nil, **props, &block) = table_row(children, **props, &block)
      def option(key = nil, **props, &block)
        ignore_block("option", block)
        mapped = props.dup
        mapped[:key] = key unless key.nil?
        build_widget(:option, **mapped)
      end
      def data_table2(columns = nil, **props)
        mapped = props.dup
        mapped[:columns] = columns unless columns.nil?
        build_widget(:data_table2, **mapped)
      end
      def datatable2(columns = nil, **props) = data_table2(columns, **props)
      def data_column2(label = nil, **props)
        mapped = props.dup
        mapped[:label] = label unless label.nil?
        build_widget(:data_column2, **mapped)
      end
      def datacolumn2(label = nil, **props) = data_column2(label, **props)
      def data_row2(cells = nil, **props)
        mapped = props.dup
        mapped[:cells] = cells unless cells.nil?
        build_widget(:data_row2, **mapped)
      end
      def datarow2(cells = nil, **props) = data_row2(cells, **props)
      def expansion_tile(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:expansiontile, "expansion_tile", mapped, block)
      end
      def expansiontile(children = nil, **props, &block) = expansion_tile(children, **props, &block)
      def expansion_panel(**props, &block) = build_with_block_slot(:expansionpanel, "expansion_panel", :content, props.dup, block)
      def expansionpanel(**props, &block) = expansion_panel(**props, &block)
      def expansion_panel_list(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:expansionpanellist, "expansion_panel_list", mapped, block)
      end
      def expansionpanellist(children = nil, **props, &block) = expansion_panel_list(children, **props, &block)
      def dropdown(options = nil, **props, &block)
        mapped = props.dup
        mapped[:options] = options unless options.nil?
        build_with_block_slot(:dropdown, "dropdown", :options, mapped, block)
      end
      def dropdown_option(key = nil, **props, &block)
        mapped = props.dup
        mapped[:key] = key unless key.nil?
        build_with_block_slot(:dropdownoption, "dropdown_option", :content, mapped, block)
      end
      def dropdownoption(key = nil, **props, &block) = dropdown_option(key, **props, &block)
      def dropdown_m2(options = nil, **props, &block)
        dropdown(options, **props, &block)
      end
      def dropdownm2(options = nil, **props, &block) = dropdown_m2(options, **props, &block)
      def progress_bar(**props) = build_widget(:progressbar, **props)
      def progressbar(**props) = progress_bar(**props)
      def placeholder(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:placeholder, "placeholder", :content, mapped, block)
      end
      def page_view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:pageview, "page_view", mapped, block)
      end
      def pageview(children = nil, **props, &block) = page_view(children, **props, &block)
      def progress_ring(**props) = build_widget(:progressring, **props)
      def progressring(**props) = progress_ring(**props)
      SPINKIT_VARIANTS = [:rotating_circle, :rotating_plain, :double_bounce, :wave, :wandering_cubes, :fading_four, :fading_cube, :pulse, :chasing_dots, :three_bounce, :circle, :cube_grid, :fading_circle, :folding_cube, :pumping_heart, :hour_glass, :pouring_hour_glass, :pouring_hour_glass_refined, :fading_grid, :ring, :ripple, :dual_ring, :spinning_circle, :spinning_lines, :square_circle, :three_in_out, :dancing_square, :piano_wave, :pulsing_grid, :wave_spinner].freeze

      def spinkit(**variants)
        selected = variants.select { |name, _value| SPINKIT_VARIANTS.include?(name) }
        raise ArgumentError, "spinkit requires exactly one variant" unless selected.length == 1 && selected.length == variants.length

        variant, options = selected.first
        raise ArgumentError, "spinkit variant options must be a Hash" unless options.is_a?(Hash)

        build_widget(:spinkit, variant: variant.to_s, **options)
      end
      def range_slider(**props) = build_widget(:rangeslider, **props)
      def rangeslider(**props) = range_slider(**props)
      def responsive_row(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:responsiverow, **mapped, &block)
      end
      def responsiverow(children = nil, **props, &block) = responsive_row(children, **props, &block)
      def reorderable_drag_handle(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:reorderabledraghandle, "reorderable_drag_handle", :content, mapped, block)
      end
      def reorderabledraghandle(content = nil, **props, &block) = reorderable_drag_handle(content, **props, &block)
      def reorderable_list_view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:reorderablelistview, "reorderable_list_view", mapped, block)
      end
      def reorderablelistview(children = nil, **props, &block) = reorderable_list_view(children, **props, &block)
      def safe_area(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:safearea, "safe_area", :content, mapped, block)
      end
      def safearea(content = nil, **props, &block) = safe_area(content, **props, &block)
      def segment(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:segment, **mapped)
      end
      def segmented_button(segments = nil, **props, &block)
        mapped = props.dup
        mapped[:segments] = segments unless segments.nil?
        build_with_block_children(:segmentedbutton, "segmented_button", mapped, block, also: :segments)
      end
      def segmentedbutton(segments = nil, **props, &block) = segmented_button(segments, **props, &block)
      def stepper(steps = nil, **props, &block)
        mapped = props.dup
        mapped[:steps] = steps unless steps.nil?
        build_widget(:stepper, **mapped, &block)
      end
      # Deliberately no bare `step` helper or registry key: these methods are
      # forwarded into Kernel and every registry key becomes a Rails view
      # helper, so a `step` name would shadow user code (SPEC D-6).
      def stepper_step(**props, &block) = build_with_block_slot(:stepper_step, "stepper_step", :content, props.dup, block)
      def stepperstep(**props, &block) = stepper_step(**props, &block)
      def selection_area(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:selectionarea, "selection_area", :content, mapped, block)
      end
      def selectionarea(content = nil, **props, &block) = selection_area(content, **props, &block)
      def search_bar(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:searchbar, "search_bar", mapped, block)
      end
      def searchbar(children = nil, **props, &block) = search_bar(children, **props, &block)
      def semantics(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:semantics, "semantics", :content, mapped, block)
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
      def circle_avatar(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:circleavatar, "circle_avatar", :content, mapped, block)
      end
      def circleavatar(content = nil, **props, &block) = circle_avatar(content, **props, &block)
      def banner(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:banner, "banner", :content, mapped, block)
      end
      def bottom_app_bar(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:bottomappbar, "bottom_app_bar", :content, mapped, block)
      end
      def bottomappbar(content = nil, **props, &block) = bottom_app_bar(content, **props, &block)

      def text(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:text, **mapped)
      end

      def button(content = nil, **props, &block)
        ignore_block("button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:button, **mapped)
      end
      # Ruflet currently uses a single Material button control schema.
      # Keep elevated_button DSL available by routing to :button.
      def elevated_button(content = nil, **props, &block)
        ignore_block("elevated_button", block)
        button(content, **props)
      end
      def text_button(content = nil, **props, &block)
        ignore_block("text_button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:textbutton, **mapped)
      end
      def textbutton(content = nil, **props, &block) = text_button(content, **props, &block)
      def filled_button(content = nil, **props, &block)
        ignore_block("filled_button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:filledbutton, **mapped)
      end
      def filledbutton(content = nil, **props, &block) = filled_button(content, **props, &block)
      def filled_icon_button(icon = nil, **props)
        mapped = props.dup
        mapped[:icon] = icon unless icon.nil?
        build_widget(:fillediconbutton, **mapped)
      end
      def fillediconbutton(icon = nil, **props) = filled_icon_button(icon, **props)
      def filled_tonal_button(content = nil, **props, &block)
        ignore_block("filled_tonal_button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:filledtonalbutton, **mapped)
      end
      def filledtonalbutton(content = nil, **props, &block) = filled_tonal_button(content, **props, &block)
      def filled_tonal_icon_button(icon = nil, **props)
        mapped = props.dup
        mapped[:icon] = icon unless icon.nil?
        build_widget(:filledtonaliconbutton, **mapped)
      end
      def filledtonaliconbutton(icon = nil, **props) = filled_tonal_icon_button(icon, **props)
      def outlined_button(content = nil, **props, &block)
        ignore_block("outlined_button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:outlinedbutton, **mapped)
      end
      def outlinedbutton(content = nil, **props, &block) = outlined_button(content, **props, &block)
      def outlined_icon_button(icon = nil, **props)
        mapped = props.dup
        mapped[:icon] = icon unless icon.nil?
        build_widget(:outlinediconbutton, **mapped)
      end
      def outlinediconbutton(icon = nil, **props) = outlined_icon_button(icon, **props)

      def icon_button(icon = nil, **props)
        mapped = props.dup
        mapped[:icon] = icon unless icon.nil?
        build_widget(:iconbutton, **mapped)
      end
      def iconbutton(icon = nil, **props) = icon_button(icon, **props)
      def interactive_viewer(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:interactiveviewer, "interactive_viewer", :content, mapped, block)
      end
      def interactiveviewer(content = nil, **props, &block) = interactive_viewer(content, **props, &block)
      def popup_menu_button(items = nil, **props, &block)
        mapped = props.dup
        mapped[:items] = items unless items.nil?
        build_with_block_slot(:popupmenubutton, "popup_menu_button", :items, mapped, block)
      end
      def popupmenubutton(items = nil, **props, &block) = popup_menu_button(items, **props, &block)
      def popup_menu_item(content = nil, **props, &block)
        ignore_block("popup_menu_item", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:popupmenuitem, **mapped)
      end
      def popupmenuitem(content = nil, **props, &block) = popup_menu_item(content, **props, &block)
      def text_field(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:textfield, **mapped)
      end
      def textfield(value = nil, **props) = text_field(value, **props)
      def checkbox(**props) = build_widget(:checkbox, **props)
      def switch(**props) = build_widget(:switch, **props)
      def slider(**props) = build_widget(:slider, **props)
      def transparent_pointer(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:transparentpointer, "transparent_pointer", :content, mapped, block)
      end
      def transparentpointer(content = nil, **props, &block) = transparent_pointer(content, **props, &block)
      def rotated_box(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:rotatedbox, "rotated_box", :content, mapped, block)
      end
      def rotatedbox(content = nil, **props, &block) = rotated_box(content, **props, &block)
      def absorb_pointer(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:absorbpointer, "absorb_pointer", :content, mapped, block)
      end
      def absorbpointer(content = nil, **props, &block) = absorb_pointer(content, **props, &block)
      def fractionally_sized_box(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:fractionallysizedbox, "fractionally_sized_box", :content, mapped, block)
      end
      def fractionallysizedbox(content = nil, **props, &block) = fractionally_sized_box(content, **props, &block)
      def ignore_pointer(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:ignorepointer, "ignore_pointer", :content, mapped, block)
      end
      def ignorepointer(content = nil, **props, &block) = ignore_pointer(content, **props, &block)
      def intrinsic_height(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:intrinsicheight, "intrinsic_height", :content, mapped, block)
      end
      def intrinsicheight(content = nil, **props, &block) = intrinsic_height(content, **props, &block)
      def intrinsic_width(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:intrinsicwidth, "intrinsic_width", :content, mapped, block)
      end
      def intrinsicwidth(content = nil, **props, &block) = intrinsic_width(content, **props, &block)
      def sliver_padding(slivers = nil, **props, &block)
        mapped = props.dup
        mapped[:slivers] = slivers unless slivers.nil?
        build_widget(:sliverpadding, **mapped, &block)
      end
      def sliverpadding(slivers = nil, **props, &block) = sliver_padding(slivers, **props, &block)
      def clip_oval(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:clipoval, "clip_oval", :content, mapped, block)
      end
      def clipoval(content = nil, **props, &block) = clip_oval(content, **props, &block)
      def clip_rsuperellipse(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:cliprsuperellipse, "clip_rsuperellipse", :content, mapped, block)
      end
      def cliprsuperellipse(content = nil, **props, &block) = clip_rsuperellipse(content, **props, &block)
      def fade_transition(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:fadetransition, "fade_transition", :content, mapped, block)
      end
      def fadetransition(content = nil, **props, &block) = fade_transition(content, **props, &block)
      def rotation_transition(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:rotationtransition, "rotation_transition", :content, mapped, block)
      end
      def rotationtransition(content = nil, **props, &block) = rotation_transition(content, **props, &block)
      def scale_transition(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:scaletransition, "scale_transition", :content, mapped, block)
      end
      def scaletransition(content = nil, **props, &block) = scale_transition(content, **props, &block)
      def size_transition(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:sizetransition, "size_transition", :content, mapped, block)
      end
      def sizetransition(content = nil, **props, &block) = size_transition(content, **props, &block)
      def slide_transition(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:slidetransition, "slide_transition", :content, mapped, block)
      end
      def slidetransition(content = nil, **props, &block) = slide_transition(content, **props, &block)
      # A group of fields validated, reset and saved together (Flutter's
      # Form), laid out like a column: form([fields], on_submit: ...) or
      # form(...) { text_field(validator: ...) }.
      def form(controls = nil, **props, &block)
        mapped = props.dup
        mapped[:controls] = controls unless controls.nil?
        build_widget(:form, **mapped, &block)
      end
      def nested_scroll_view(header_slivers = nil, **props, &block)
        mapped = props.dup
        mapped[:header_slivers] = header_slivers unless header_slivers.nil?
        build_widget(:nestedscrollview, **mapped, &block)
      end
      def nestedscrollview(header_slivers = nil, **props, &block) = nested_scroll_view(header_slivers, **props, &block)
      def fitted_box(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:fittedbox, "fitted_box", :content, mapped, block)
      end
      def fittedbox(content = nil, **props, &block) = fitted_box(content, **props, &block)
      def screenshot(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:screenshot, "screenshot", :content, mapped, block)
      end
      def radio(**props) = build_widget(:radio, **props)
      def radio_group(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:radiogroup, "radio_group", :content, mapped, block)
      end
      def radiogroup(content = nil, **props, &block) = radio_group(content, **props, &block)
      def about_dialog(**props, &block) = build_with_block_children(:aboutdialog, "about_dialog", props.dup, block)
      def aboutdialog(**props, &block) = about_dialog(**props, &block)
      def alert_dialog(**props, &block) = build_with_block_slot(:alertdialog, "alert_dialog", :content, props.dup, block)
      def alertdialog(**props, &block) = alert_dialog(**props, &block)
      def snack_bar(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:snackbar, "snack_bar", :content, mapped, block)
      end
      def snackbar(content = nil, **props, &block) = snack_bar(content, **props, &block)
      def snack_bar_action(label = nil, **props)
        mapped = props.dup
        mapped[:label] = label unless label.nil?
        build_widget(:snackbaraction, **mapped)
      end
      def snackbaraction(label = nil, **props) = snack_bar_action(label, **props)
      def bottom_sheet(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:bottomsheet, "bottom_sheet", :content, mapped, block)
      end
      def bottomsheet(content = nil, **props, &block) = bottom_sheet(content, **props, &block)

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

      def app_bar(**props, &block) = build_with_block_slot(:appbar, "app_bar", :actions, props.dup, block)
      def appbar(**props, &block) = app_bar(**props, &block)
      def clipboard(**props) = build_service(:clipboard, **props)
      # Takes its content positionally like the other buttons (and Flet's
      # FloatingActionButton("Add")); floating_action_button(content: ...) is
      # the same call.
      def floating_action_button(content = nil, **props, &block)
        ignore_block("floating_action_button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:floatingactionbutton, **mapped)
      end
      def floatingactionbutton(content = nil, **props, &block) = floating_action_button(content, **props, &block)
      def tabs(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_legacy_block_slot(:tabs, "tabs", :content, mapped, block)
      end

      def tab(label = nil, **props, &block)
        mapped = props.dup
        mapped[:label] = label unless label.nil?
        build_widget(:tab, **mapped, &block)
      end

      def tab_bar(tabs = nil, **props, &block)
        mapped = props.dup
        mapped[:tabs] = tabs unless tabs.nil?
        build_with_legacy_block_slot(:tabbar, "tab_bar", :tabs, mapped, block)
      end
      def tabbar(tabs = nil, **props, &block) = tab_bar(tabs, **props, &block)
      def tab_bar_view(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:tabbarview, **mapped, &block)
      end
      def tabbarview(children = nil, **props, &block) = tab_bar_view(children, **props, &block)
      def navigation_bar(**props, &block) = build_with_legacy_block_slot(:navigationbar, "navigation_bar", :destinations, props.dup, block)
      def navigationbar(**props, &block) = navigation_bar(**props, &block)
      def navigation_bar_destination(**props, &block) = build_widget(:navigationbardestination, **props, &block)
      def navigationbardestination(**props, &block) = navigation_bar_destination(**props, &block)
      def navigation_rail(**props, &block) = build_with_legacy_block_slot(:navigationrail, "navigation_rail", :destinations, props.dup, block)
      def navigationrail(**props, &block) = navigation_rail(**props, &block)
      def navigation_rail_destination(**props, &block) = build_widget(:navigationraildestination, **props, &block)
      def navigationraildestination(**props, &block) = navigation_rail_destination(**props, &block)
      def navigation_drawer(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:navigationdrawer, "navigation_drawer", mapped, block)
      end
      def navigationdrawer(children = nil, **props, &block) = navigation_drawer(children, **props, &block)
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
      def video(**props) = build_widget(:video, **props)
      def block_picker(**props) = build_widget(:block_picker, **props)
      def blockpicker(**props) = block_picker(**props)
      def color_picker(**props) = build_widget(:color_picker, **props)
      def colorpicker(**props) = color_picker(**props)
      def hue_ring_picker(**props) = build_widget(:hue_ring_picker, **props)
      def hueringpicker(**props) = hue_ring_picker(**props)
      def material_picker(**props) = build_widget(:material_picker, **props)
      def materialpicker(**props) = material_picker(**props)
      def multiple_choice_block_picker(**props) = build_widget(:multiple_choice_block_picker, **props)
      def multiplechoiceblockpicker(**props) = multiple_choice_block_picker(**props)
      def slide_picker(**props) = build_widget(:slide_picker, **props)
      def slidepicker(**props) = slide_picker(**props)
      def banner_ad(**props) = build_widget(:banner_ad, **props)
      def bannerad(**props) = banner_ad(**props)
      def interstitial_ad(**props) = build_widget(:interstitial_ad, **props)
      def interstitialad(**props) = interstitial_ad(**props)
      def native_ad(**props) = build_widget(:native_ad, **props)
      def nativead(**props) = native_ad(**props)
      def code_editor(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:codeeditor, **mapped)
      end
      def codeeditor(value = nil, **props) = code_editor(value, **props)
      def lottie(src = nil, **props)
        mapped = props.dup
        mapped[:src] = src unless src.nil?
        build_widget(:lottie, **mapped)
      end
      def rive(src = nil, **props)
        mapped = props.dup
        mapped[:src] = src unless src.nil?
        build_widget(:rive, **mapped)
      end

      def fab(content = nil, **props, &block)
        ignore_block("fab", block)
        mapped = normalize_fab_props(props.dup, content)
        build_widget(:floatingactionbutton, **mapped)
      end

      private

      def drawing_payload(props)
        props.each_with_object({}) do |(key, value), output|
          output[key] = value unless value.nil?
        end
      end

      def path_point_payload(type, x, y, props)
        mapped = props.dup
        mapped[:x] = x unless x.nil?
        mapped[:y] = y unless y.nil?
        drawing_payload(mapped.merge(_type: type))
      end

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

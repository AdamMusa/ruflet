# frozen_string_literal: true

require_relative "animatedswitcher_control"
require_relative "arc_control"
require_relative "autofillgroup_control"
require_relative "basepage_control"
require_relative "browsercontextmenu_control"
require_relative "canvas_control"
require_relative "circle_control"
require_relative "color_control"
require_relative "column_control"
require_relative "dialogs_control"
require_relative "dismissible_control"
require_relative "draggable_control"
require_relative "dragtarget_control"
require_relative "fill_control"
require_relative "fletapp_control"
require_relative "gesturedetector_control"
require_relative "gridview_control"
require_relative "hero_control"
require_relative "icon_control"
require_relative "image_control"
require_relative "interactiveviewer_control"
require_relative "keyboardlistener_control"
require_relative "line_control"
require_relative "listview_control"
require_relative "markdown_control"
require_relative "mergesemantics_control"
require_relative "oval_control"
require_relative "overlay_control"
require_relative "page_control"
require_relative "pagelet_control"
require_relative "pageview_control"
require_relative "path_control"
require_relative "placeholder_control"
require_relative "points_control"
require_relative "rect_control"
require_relative "reorderabledraghandle_control"
require_relative "responsiverow_control"
require_relative "row_control"
require_relative "safearea_control"
require_relative "semantics_control"
require_relative "serviceregistry_control"
require_relative "shadermask_control"
require_relative "shadow_control"
require_relative "shimmer_control"
require_relative "stack_control"
require_relative "text_control"
require_relative "textspan_control"
require_relative "transparentpointer_control"
require_relative "view_control"
require_relative "window_control"
require_relative "windowdragarea_control"

module Ruflet
  module UI
    module Controls
      module Shared
        module RufletControls
          module_function

          CLASS_MAP = {
            "animated_switcher" => RufletComponents::AnimatedSwitcherControl,
            "animatedswitcher" => RufletComponents::AnimatedSwitcherControl,
            "arc" => RufletComponents::ArcControl,
            "autofill_group" => RufletComponents::AutofillGroupControl,
            "autofillgroup" => RufletComponents::AutofillGroupControl,
            "base_page" => RufletComponents::BasePageControl,
            "basepage" => RufletComponents::BasePageControl,
            "browser_context_menu" => RufletComponents::BrowserContextMenuControl,
            "browsercontextmenu" => RufletComponents::BrowserContextMenuControl,
            "canvas" => RufletComponents::CanvasControl,
            "circle" => RufletComponents::CircleControl,
            "color" => RufletComponents::ColorControl,
            "column" => RufletComponents::ColumnControl,
            "dialogs" => RufletComponents::DialogsControl,
            "dismissible" => RufletComponents::DismissibleControl,
            "drag_target" => RufletComponents::DragTargetControl,
            "draggable" => RufletComponents::DraggableControl,
            "dragtarget" => RufletComponents::DragTargetControl,
            "fill" => RufletComponents::FillControl,
            "flet_app" => RufletComponents::FletAppControl,
            "fletapp" => RufletComponents::FletAppControl,
            "gesture_detector" => RufletComponents::GestureDetectorControl,
            "gesturedetector" => RufletComponents::GestureDetectorControl,
            "grid_view" => RufletComponents::GridViewControl,
            "gridview" => RufletComponents::GridViewControl,
            "hero" => RufletComponents::HeroControl,
            "icon" => RufletComponents::IconControl,
            "image" => RufletComponents::ImageControl,
            "interactive_viewer" => RufletComponents::InteractiveViewerControl,
            "interactiveviewer" => RufletComponents::InteractiveViewerControl,
            "keyboard_listener" => RufletComponents::KeyboardListenerControl,
            "keyboardlistener" => RufletComponents::KeyboardListenerControl,
            "line" => RufletComponents::LineControl,
            "list_view" => RufletComponents::ListViewControl,
            "listview" => RufletComponents::ListViewControl,
            "markdown" => RufletComponents::MarkdownControl,
            "merge_semantics" => RufletComponents::MergeSemanticsControl,
            "mergesemantics" => RufletComponents::MergeSemanticsControl,
            "oval" => RufletComponents::OvalControl,
            "overlay" => RufletComponents::OverlayControl,
            "page" => RufletComponents::PageControl,
            "page_view" => RufletComponents::PageViewControl,
            "pagelet" => RufletComponents::PageletControl,
            "pageview" => RufletComponents::PageViewControl,
            "path" => RufletComponents::PathControl,
            "placeholder" => RufletComponents::PlaceholderControl,
            "points" => RufletComponents::PointsControl,
            "rect" => RufletComponents::RectControl,
            "reorderable_drag_handle" => RufletComponents::ReorderableDragHandleControl,
            "reorderabledraghandle" => RufletComponents::ReorderableDragHandleControl,
            "responsive_row" => RufletComponents::ResponsiveRowControl,
            "responsiverow" => RufletComponents::ResponsiveRowControl,
            "row" => RufletComponents::RowControl,
            "safe_area" => RufletComponents::SafeAreaControl,
            "safearea" => RufletComponents::SafeAreaControl,
            "semantics" => RufletComponents::SemanticsControl,
            "service_registry" => RufletComponents::ServiceRegistryControl,
            "serviceregistry" => RufletComponents::ServiceRegistryControl,
            "shader_mask" => RufletComponents::ShaderMaskControl,
            "shadermask" => RufletComponents::ShaderMaskControl,
            "shadow" => RufletComponents::ShadowControl,
            "shimmer" => RufletComponents::ShimmerControl,
            "stack" => RufletComponents::StackControl,
            "text" => RufletComponents::TextControl,
            "text_span" => RufletComponents::TextSpanControl,
            "textspan" => RufletComponents::TextSpanControl,
            "transparent_pointer" => RufletComponents::TransparentPointerControl,
            "transparentpointer" => RufletComponents::TransparentPointerControl,
            "view" => RufletComponents::ViewControl,
            "window" => RufletComponents::WindowControl,
            "window_drag_area" => RufletComponents::WindowDragAreaControl,
            "windowdragarea" => RufletComponents::WindowDragAreaControl,
          }.freeze
        end
      end
    end
  end
end

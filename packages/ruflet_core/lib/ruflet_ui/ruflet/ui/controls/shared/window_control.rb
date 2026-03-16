# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class WindowControl < Ruflet::Control
          TYPE = "window".freeze
          WIRE = "Window".freeze

          def initialize(id: nil, alignment: nil, always_on_bottom: nil, always_on_top: nil, aspect_ratio: nil, badge_label: nil, bgcolor: nil, brightness: nil, data: nil, focused: nil, frameless: nil, full_screen: nil, height: nil, icon: nil, ignore_mouse_events: nil, key: nil, left: nil, max_height: nil, max_width: nil, maximizable: nil, maximized: nil, min_height: nil, min_width: nil, minimizable: nil, minimized: nil, movable: nil, opacity: nil, prevent_close: nil, progress_bar: nil, resizable: nil, shadow: nil, skip_task_bar: nil, title_bar_buttons_hidden: nil, title_bar_hidden: nil, top: nil, visible: nil, width: nil, on_event: nil)
            props = {}
            props[:alignment] = alignment unless alignment.nil?
            props[:always_on_bottom] = always_on_bottom unless always_on_bottom.nil?
            props[:always_on_top] = always_on_top unless always_on_top.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:badge_label] = badge_label unless badge_label.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:brightness] = brightness unless brightness.nil?
            props[:data] = data unless data.nil?
            props[:focused] = focused unless focused.nil?
            props[:frameless] = frameless unless frameless.nil?
            props[:full_screen] = full_screen unless full_screen.nil?
            props[:height] = height unless height.nil?
            props[:icon] = icon unless icon.nil?
            props[:ignore_mouse_events] = ignore_mouse_events unless ignore_mouse_events.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:max_height] = max_height unless max_height.nil?
            props[:max_width] = max_width unless max_width.nil?
            props[:maximizable] = maximizable unless maximizable.nil?
            props[:maximized] = maximized unless maximized.nil?
            props[:min_height] = min_height unless min_height.nil?
            props[:min_width] = min_width unless min_width.nil?
            props[:minimizable] = minimizable unless minimizable.nil?
            props[:minimized] = minimized unless minimized.nil?
            props[:movable] = movable unless movable.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:prevent_close] = prevent_close unless prevent_close.nil?
            props[:progress_bar] = progress_bar unless progress_bar.nil?
            props[:resizable] = resizable unless resizable.nil?
            props[:shadow] = shadow unless shadow.nil?
            props[:skip_task_bar] = skip_task_bar unless skip_task_bar.nil?
            props[:title_bar_buttons_hidden] = title_bar_buttons_hidden unless title_bar_buttons_hidden.nil?
            props[:title_bar_hidden] = title_bar_hidden unless title_bar_hidden.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_event] = on_event unless on_event.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end

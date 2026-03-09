# gesturedetector

- Python classes: `['GestureDetector']`
- Source files: `['gesture_detector.py']`
- Isolated/service-like: `false`

## Widget/Control Type
- Protocol control type (`_get_control_name`): `gesturedetector`

## Protocol Shape
```json
{
  "_c": "gesturedetector",
  "attrs": [
    "dragInterval",
    "hoverInterval",
    "mouseCursor",
    "multiTapTouches",
    "onDoubleTap",
    "onDoubleTapDown",
    "onEnter",
    "onExit",
    "onHorizontalDragEnd",
    "onHorizontalDragStart",
    "onHorizontalDragUpdate",
    "onHover",
    "onLongPressEnd",
    "onLongPressStart",
    "onMultiLongPress",
    "onMultiTap",
    "onPanEnd",
    "onPanStart",
    "onPanUpdate",
    "onScaleEnd",
    "onScaleStart",
    "onScaleUpdate",
    "onScroll",
    "onSecondaryLongPressEnd",
    "onSecondaryLongPressStart",
    "onSecondaryTap",
    "onSecondaryTapDown",
    "onSecondaryTapUp",
    "onTap",
    "onTapDown",
    "onTapUp",
    "onVerticalDragEnd",
    "onVerticalDragStart",
    "onVerticalDragUpdate"
  ],
  "events": {
    "api": [
      "on_animation_end",
      "on_double_tap",
      "on_double_tap_down",
      "on_enter",
      "on_exit",
      "on_horizontal_drag_end",
      "on_horizontal_drag_start",
      "on_horizontal_drag_update",
      "on_hover",
      "on_long_press_end",
      "on_long_press_start",
      "on_multi_long_press",
      "on_multi_tap",
      "on_pan_end",
      "on_pan_start",
      "on_pan_update",
      "on_scale_end",
      "on_scale_start",
      "on_scale_update",
      "on_scroll",
      "on_secondary_long_press_end",
      "on_secondary_long_press_start",
      "on_secondary_tap",
      "on_secondary_tap_down",
      "on_secondary_tap_up",
      "on_tap",
      "on_tap_down",
      "on_tap_up",
      "on_vertical_drag_end",
      "on_vertical_drag_start",
      "on_vertical_drag_update"
    ],
    "runtime": [
      "double_tap",
      "double_tap_down",
      "enter",
      "exit",
      "horizontal_drag_end",
      "horizontal_drag_start",
      "horizontal_drag_update",
      "hover",
      "long_press_end",
      "long_press_start",
      "multi_long_press",
      "multi_tap",
      "pan_end",
      "pan_start",
      "pan_update",
      "scale_end",
      "scale_start",
      "scale_update",
      "scroll",
      "secondary_long_press_end",
      "secondary_long_press_start",
      "secondary_tap",
      "secondary_tap_down",
      "secondary_tap_up",
      "tap",
      "tap_down",
      "tap_up",
      "vertical_drag_end",
      "vertical_drag_start",
      "vertical_drag_update"
    ]
  },
  "invokes": []
}
```

## Serialized Attribute Keys
- `dragInterval`
- `hoverInterval`
- `mouseCursor`
- `multiTapTouches`
- `onDoubleTap`
- `onDoubleTapDown`
- `onEnter`
- `onExit`
- `onHorizontalDragEnd`
- `onHorizontalDragStart`
- `onHorizontalDragUpdate`
- `onHover`
- `onLongPressEnd`
- `onLongPressStart`
- `onMultiLongPress`
- `onMultiTap`
- `onPanEnd`
- `onPanStart`
- `onPanUpdate`
- `onScaleEnd`
- `onScaleStart`
- `onScaleUpdate`
- `onScroll`
- `onSecondaryLongPressEnd`
- `onSecondaryLongPressStart`
- `onSecondaryTap`
- `onSecondaryTapDown`
- `onSecondaryTapUp`
- `onTap`
- `onTapDown`
- `onTapUp`
- `onVerticalDragEnd`
- `onVerticalDragStart`
- `onVerticalDragUpdate`

## Event Handlers (Python API fields)
- `on_animation_end`
- `on_double_tap`
- `on_double_tap_down`
- `on_enter`
- `on_exit`
- `on_horizontal_drag_end`
- `on_horizontal_drag_start`
- `on_horizontal_drag_update`
- `on_hover`
- `on_long_press_end`
- `on_long_press_start`
- `on_multi_long_press`
- `on_multi_tap`
- `on_pan_end`
- `on_pan_start`
- `on_pan_update`
- `on_scale_end`
- `on_scale_start`
- `on_scale_update`
- `on_scroll`
- `on_secondary_long_press_end`
- `on_secondary_long_press_start`
- `on_secondary_tap`
- `on_secondary_tap_down`
- `on_secondary_tap_up`
- `on_tap`
- `on_tap_down`
- `on_tap_up`
- `on_vertical_drag_end`
- `on_vertical_drag_start`
- `on_vertical_drag_update`

## Runtime Event Names (wire event names)
- `double_tap`
- `double_tap_down`
- `enter`
- `exit`
- `horizontal_drag_end`
- `horizontal_drag_start`
- `horizontal_drag_update`
- `hover`
- `long_press_end`
- `long_press_start`
- `multi_long_press`
- `multi_tap`
- `pan_end`
- `pan_start`
- `pan_update`
- `scale_end`
- `scale_start`
- `scale_update`
- `scroll`
- `secondary_long_press_end`
- `secondary_long_press_start`
- `secondary_tap`
- `secondary_tap_down`
- `secondary_tap_up`
- `tap`
- `tap_down`
- `tap_up`
- `vertical_drag_end`
- `vertical_drag_start`
- `vertical_drag_update`

## Public API Methods
- `content()`
- `content(value: Optional[Control])`
- `drag_interval()`
- `drag_interval(value: Optional[int])`
- `hover_interval()`
- `hover_interval(value: Optional[int])`
- `mouse_cursor()`
- `mouse_cursor(value: Optional[MouseCursor])`
- `multi_tap_touches()`
- `multi_tap_touches(value: Optional[int])`
- `on_double_tap()`
- `on_double_tap(handler)`
- `on_double_tap_down()`
- `on_double_tap_down(handler)`
- `on_enter()`
- `on_enter(handler)`
- `on_exit()`
- `on_exit(handler)`
- `on_horizontal_drag_end()`
- `on_horizontal_drag_end(handler)`
- `on_horizontal_drag_start()`
- `on_horizontal_drag_start(handler)`
- `on_horizontal_drag_update()`
- `on_horizontal_drag_update(handler)`
- `on_hover()`
- `on_hover(handler)`
- `on_long_press_end()`
- `on_long_press_end(handler)`
- `on_long_press_start()`
- `on_long_press_start(handler)`
- `on_multi_long_press()`
- `on_multi_long_press(handler)`
- `on_multi_tap()`
- `on_multi_tap(handler)`
- `on_pan_end()`
- `on_pan_end(handler)`
- `on_pan_start()`
- `on_pan_start(handler)`
- `on_pan_update()`
- `on_pan_update(handler)`
- `on_scale_end()`
- `on_scale_end(handler)`
- `on_scale_start()`
- `on_scale_start(handler)`
- `on_scale_update()`
- `on_scale_update(handler)`
- `on_scroll()`
- `on_scroll(handler)`
- `on_secondary_long_press_end()`
- `on_secondary_long_press_end(handler)`
- `on_secondary_long_press_start()`
- `on_secondary_long_press_start(handler)`
- `on_secondary_tap()`
- `on_secondary_tap(handler)`
- `on_secondary_tap_down()`
- `on_secondary_tap_down(handler)`
- `on_secondary_tap_up()`
- `on_secondary_tap_up(handler)`
- `on_tap()`
- `on_tap(handler)`
- `on_tap_down()`
- `on_tap_down(handler)`
- `on_tap_up()`
- `on_tap_up(handler)`
- `on_vertical_drag_end()`
- `on_vertical_drag_end(handler)`
- `on_vertical_drag_start()`
- `on_vertical_drag_start(handler)`
- `on_vertical_drag_update()`
- `on_vertical_drag_update(handler)`

## Invoke-Method Protocol Calls
- _No explicit `invoke_method` calls detected in this component._

## Event Payload Shapes (ControlEvent models)
- `DragEndEvent` fields: `['pv', 'vx', 'vy']` (defined in `gesture_detector.py`)
- `DragStartEvent` fields: `['gx', 'gy', 'kind', 'lx', 'ly', 'ts']` (defined in `gesture_detector.py`)
- `DragUpdateEvent` fields: `['dx', 'dy', 'gx', 'gy', 'lx', 'ly', 'pd', 'ts']` (defined in `gesture_detector.py`)
- `HoverEvent` fields: `['dx', 'dy', 'gx', 'gy', 'kind', 'lx', 'ly', 'ts']` (defined in `gesture_detector.py`)
- `LongPressEndEvent` fields: `['gx', 'gy', 'lx', 'ly', 'vx', 'vy']` (defined in `gesture_detector.py`)
- `LongPressStartEvent` fields: `['gx', 'gy', 'lx', 'ly']` (defined in `gesture_detector.py`)
- `MultiTapEvent` fields: `['correct_touches']` (defined in `gesture_detector.py`)
- `ScaleEndEvent` fields: `['pc', 'vx', 'vy']` (defined in `gesture_detector.py`)
- `ScaleStartEvent` fields: `['fpx', 'fpy', 'lfpx', 'lfpy', 'pc']` (defined in `gesture_detector.py`)
- `ScaleUpdateEvent` fields: `['fpdx', 'fpdy', 'fpx', 'fpy', 'hs', 'lfpx', 'lfpy', 'pc', 'r', 's', 'vs']` (defined in `gesture_detector.py`)
- `ScrollEvent` fields: `['dx', 'dy', 'gx', 'gy', 'lx', 'ly']` (defined in `gesture_detector.py`)
- `TapEvent` fields: `['gx', 'gy', 'kind', 'lx', 'ly']` (defined in `gesture_detector.py`)

## Notes
- Generated by static AST analysis of Flet Python source.
- Attribute and event lists are code-derived; runtime dynamic behavior may add additional values.

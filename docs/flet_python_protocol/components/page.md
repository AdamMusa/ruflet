# page

- Python classes: `['Page']`
- Source files: `['page.py']`
- Isolated/service-like: `false`

## Widget/Control Type
- Protocol control type (`_get_control_name`): `page`

## Protocol Shape
```json
{
  "_c": "page",
  "attrs": [
    "clientIP",
    "clientUserAgent",
    "darkTheme",
    "debug",
    "design",
    "fonts",
    "height",
    "onKeyboardEvent",
    "platform",
    "platformBrightness",
    "pwa",
    "route",
    "rtl",
    "showSemanticsDebugger",
    "theme",
    "themeMode",
    "title",
    "web",
    "width",
    "windowAlwaysOnTop",
    "windowBgcolor",
    "windowCenter",
    "windowClose",
    "windowDestroy",
    "windowFocused",
    "windowFrameless",
    "windowFullScreen",
    "windowHeight",
    "windowLeft",
    "windowMaxHeight",
    "windowMaxWidth",
    "windowMaximizable",
    "windowMaximized",
    "windowMinHeight",
    "windowMinWidth",
    "windowMinimizable",
    "windowMinimized",
    "windowMovable",
    "windowOpacity",
    "windowPreventClose",
    "windowProgressBar",
    "windowResizable",
    "windowSkipTaskBar",
    "windowTitleBarButtonsHidden",
    "windowTitleBarHidden",
    "windowTop",
    "windowVisible",
    "windowWidth"
  ],
  "events": {
    "api": [],
    "runtime": [
      "authorize",
      "close",
      "connect",
      "disconnect",
      "error",
      "invoke_method_result",
      "keyboard_event",
      "platformBrightnessChange",
      "resize",
      "route_change",
      "view_pop",
      "window_event"
    ]
  },
  "invokes": [
    {
      "wrapper": "can_launch_url",
      "name": "canLaunchUrl",
      "args": [],
      "wait_for_result": true,
      "async_call": false
    },
    {
      "wrapper": "close_in_app_web_view",
      "name": "closeInAppWebView",
      "args": [],
      "wait_for_result": false,
      "async_call": false
    },
    {
      "wrapper": "launch_url",
      "name": "launchUrl",
      "args": [],
      "wait_for_result": false,
      "async_call": false
    },
    {
      "wrapper": "window_to_front",
      "name": "windowToFront",
      "args": [],
      "wait_for_result": false,
      "async_call": false
    }
  ]
}
```

## Serialized Attribute Keys
- `clientIP`
- `clientUserAgent`
- `darkTheme`
- `debug`
- `design`
- `fonts`
- `height`
- `onKeyboardEvent`
- `platform`
- `platformBrightness`
- `pwa`
- `route`
- `rtl`
- `showSemanticsDebugger`
- `theme`
- `themeMode`
- `title`
- `web`
- `width`
- `windowAlwaysOnTop`
- `windowBgcolor`
- `windowCenter`
- `windowClose`
- `windowDestroy`
- `windowFocused`
- `windowFrameless`
- `windowFullScreen`
- `windowHeight`
- `windowLeft`
- `windowMaxHeight`
- `windowMaxWidth`
- `windowMaximizable`
- `windowMaximized`
- `windowMinHeight`
- `windowMinWidth`
- `windowMinimizable`
- `windowMinimized`
- `windowMovable`
- `windowOpacity`
- `windowPreventClose`
- `windowProgressBar`
- `windowResizable`
- `windowSkipTaskBar`
- `windowTitleBarButtonsHidden`
- `windowTitleBarHidden`
- `windowTop`
- `windowVisible`
- `windowWidth`

## Event Handlers (Python API fields)
- _None detected._

## Runtime Event Names (wire event names)
- `authorize`
- `close`
- `connect`
- `disconnect`
- `error`
- `invoke_method_result`
- `keyboard_event`
- `platformBrightnessChange`
- `resize`
- `route_change`
- `view_pop`
- `window_event`

## Public API Methods
- `add(*controls)`
- `appbar()`
- `appbar(value: Optional[AppBar])`
- `auth()`
- `auto_scroll()`
- `auto_scroll(value: Optional[bool])`
- `banner()`
- `banner(value: Optional[Banner])`
- `bgcolor()`
- `bgcolor(value)`
- `bottom_sheet()`
- `bottom_sheet(value: Optional[BottomSheet])`
- `can_launch_url(url: str)`
- `clean()`
- `client_ip()`
- `client_storage()`
- `client_user_agent()`
- `close_banner()`
- `close_bottom_sheet()`
- `close_dialog()`
- `close_in_app_web_view()`
- `connection()`
- `controls()`
- `controls(value: Optional[List[Control]])`
- `dark_theme()`
- `dark_theme(value: Optional[Theme])`
- `debug()`
- `design()`
- `design(value: Optional[PageDesignLanguage])`
- `dialog()`
- `dialog(value: Optional[Control])`
- `error(message = '')`
- `expires_at()`
- `fetch_page_details()`
- `floating_action_button()`
- `floating_action_button(value: Optional[FloatingActionButton])`
- `fonts()`
- `fonts(value: Optional[Dict[str, str]])`
- `get_clipboard()`
- `get_control(id)`
- `get_next_control_id()`
- `get_upload_url(file_name: str, expires: int)`
- `go(route, **kwargs)`
- `height()`
- `horizontal_alignment()`
- `horizontal_alignment(value: CrossAxisAlignment)`
- `index()`
- `insert(at, *controls)`
- `invoke_method(method_name: str, arguments: Optional[Dict[str, str]] = None, control_id: Optional[str] = '', wait_for_result: bool = False, wait_timeout: Optional[float] = 5)`
- `launch_url(url: str, web_window_name: Optional[str] = None, web_popup_window: bool = False, window_width: Optional[int] = None, window_height: Optional[int] = None)`
- `login(provider: OAuthProvider, fetch_user = True, fetch_groups = False, scope: Optional[List[str]] = None, saved_token: Optional[str] = None, on_open_authorization_url = None, complete_page_html: Optional[str] = None, redirect_to_page = False, authorization = Authorization)`
- `logout()`
- `name()`
- `navigation_bar()`
- `navigation_bar(value: Optional[NavigationBar])`
- `on_close()`
- `on_close(handler)`
- `on_connect()`
- `on_connect(handler)`
- `on_disconnect()`
- `on_disconnect(handler)`
- `on_error()`
- `on_error(handler)`
- `on_event(e: Event)`
- `on_keyboard_event()`
- `on_keyboard_event(handler)`
- `on_login()`
- `on_login(handler)`
- `on_logout()`
- `on_logout(handler)`
- `on_platform_brightness_change()`
- `on_platform_brightness_change(handler)`
- `on_resize()`
- `on_resize(handler)`
- `on_route_change()`
- `on_route_change(handler)`
- `on_scroll()`
- `on_scroll(handler)`
- `on_scroll_interval()`
- `on_scroll_interval(value: OptionalNumber)`
- `on_view_pop()`
- `on_view_pop(handler)`
- `on_window_event()`
- `on_window_event(handler)`
- `overlay()`
- `padding()`
- `padding(value: PaddingValue)`
- `platform()`
- `platform_brightness()`
- `pubsub()`
- `pwa()`
- `query()`
- `remove(*controls)`
- `remove_at(index)`
- `route()`
- `route(value)`
- `rtl()`
- `rtl(value: Optional[bool])`
- `scroll()`
- `scroll(value: Optional[ScrollMode])`
- `scroll_to(offset: Optional[float] = None, delta: Optional[float] = None, key: Optional[str] = None, duration: Optional[int] = None, curve: Optional[AnimationCurve] = None)`
- `session()`
- `session_id()`
- `set_clipboard(value: str)`
- `show_banner(banner: Banner)`
- `show_bottom_sheet(bottom_sheet: BottomSheet)`
- `show_dialog(dialog: AlertDialog)`
- `show_semantics_debugger()`
- `show_semantics_debugger(value: Optional[bool])`
- `show_snack_bar(snack_bar: SnackBar)`
- `snack_bar()`
- `snack_bar(value: Optional[SnackBar])`
- `snapshot()`
- `spacing()`
- `spacing(value: OptionalNumber)`
- `splash()`
- `splash(value: Optional[Control])`
- `theme()`
- `theme(value: Optional[Theme])`
- `theme_mode()`
- `theme_mode(value: Optional[ThemeMode])`
- `title()`
- `title(value)`
- `update(*controls)`
- `url()`
- `vertical_alignment()`
- `vertical_alignment(value: MainAxisAlignment)`
- `views()`
- `web()`
- `width()`
- `window_always_on_top()`
- `window_always_on_top(value: Optional[bool])`
- `window_bgcolor()`
- `window_bgcolor(value)`
- `window_center()`
- `window_close()`
- `window_destroy()`
- `window_focused()`
- `window_focused(value: Optional[bool])`
- `window_frameless()`
- `window_frameless(value: Optional[bool])`
- `window_full_screen()`
- `window_full_screen(value: Optional[bool])`
- `window_height()`
- `window_height(value: OptionalNumber)`
- `window_left()`
- `window_left(value: OptionalNumber)`
- `window_max_height()`
- `window_max_height(value: OptionalNumber)`
- `window_max_width()`
- `window_max_width(value: OptionalNumber)`
- `window_maximizable()`
- `window_maximizable(value: Optional[bool])`
- `window_maximized()`
- `window_maximized(value: Optional[bool])`
- `window_min_height()`
- `window_min_height(value: OptionalNumber)`
- `window_min_width()`
- `window_min_width(value: OptionalNumber)`
- `window_minimizable()`
- `window_minimizable(value: Optional[bool])`
- `window_minimized()`
- `window_minimized(value: Optional[bool])`
- `window_movable()`
- `window_movable(value: Optional[bool])`
- `window_opacity()`
- `window_opacity(value: OptionalNumber)`
- `window_prevent_close()`
- `window_prevent_close(value: Optional[bool])`
- `window_progress_bar()`
- `window_progress_bar(value: OptionalNumber)`
- `window_resizable()`
- `window_resizable(value: Optional[bool])`
- `window_skip_task_bar()`
- `window_skip_task_bar(value: Optional[bool])`
- `window_title_bar_buttons_hidden()`
- `window_title_bar_buttons_hidden(value: Optional[bool])`
- `window_title_bar_hidden()`
- `window_title_bar_hidden(value: Optional[bool])`
- `window_to_front()`
- `window_top()`
- `window_top(value: OptionalNumber)`
- `window_visible()`
- `window_visible(value: Optional[bool])`
- `window_width()`
- `window_width(value: OptionalNumber)`

## Invoke-Method Protocol Calls
- Wrapper: `can_launch_url` -> invoke name: `canLaunchUrl` | args keys: `[]` | wait_for_result: `true` | async_call: `false`
- Wrapper: `close_in_app_web_view` -> invoke name: `closeInAppWebView` | args keys: `[]` | wait_for_result: `false` | async_call: `false`
- Wrapper: `launch_url` -> invoke name: `launchUrl` | args keys: `[]` | wait_for_result: `false` | async_call: `false`
- Wrapper: `window_to_front` -> invoke name: `windowToFront` | args keys: `[]` | wait_for_result: `false` | async_call: `false`

## Event Payload Shapes (ControlEvent models)
- `KeyboardEvent` fields: `['alt', 'ctrl', 'key', 'meta', 'shift']` (defined in `page.py`)
- `RouteChangeEvent` fields: `['route']` (defined in `page.py`)
- `ViewPopEvent` fields: `['view']` (defined in `page.py`)

## Notes
- Generated by static AST analysis of Flet Python source.
- Attribute and event lists are code-derived; runtime dynamic behavior may add additional values.
